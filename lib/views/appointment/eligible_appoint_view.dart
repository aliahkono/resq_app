import 'package:flutter/material.dart';
import 'package:resq/services/api_service.dart';
import 'package:resq/views/profile/get_ver_view.dart';
import 'package:resq/widgets/app_notif_bell.dart';
import 'package:resq/widgets/resq_ui.dart';

/// Parsed from GET /api/donor/hospitals — real hospitals from the admin
/// dashboard's database, not a hardcoded list. No distance/rating fields:
/// the backend doesn't compute those for this endpoint (only
/// listOpenRequestsForDonor does, using the donor's GPS position), so
/// showing them here would just be more fabricated data.
class _Hospital {
  final String id;
  final String name;
  final String address;
  final String city;

  _Hospital({required this.id, required this.name, required this.address, required this.city});

  factory _Hospital.fromJson(Map<String, dynamic> json) {
    return _Hospital(
      id: json['id'] as String,
      name: json['name'] as String,
      address: (json['address'] as String?) ?? '',
      city: (json['city'] as String?) ?? '',
    );
  }
}

class EligibleAppointView extends StatefulWidget {
  final bool isFirstTimeDonor;
  final String token;
  // Called with the real backend response (id, hospitalId, scheduledAt,
  // status) merged with the selected hospital's name/address, once
  // POST /api/donor/appointments actually succeeds — not just whenever the
  // donor taps a button.
  final void Function(Map<String, dynamic> appointment) onBookingCompleted;
  // Set when arriving here from a specific broadcast/priority request (the
  // notification bell's "accept slot", the Home tab's Priority Request Feed
  // "Reserve Slot", or the Appointment tab's "Schedule New Appointment").
  // When set, the picker is skipped entirely — the donor is responding to
  // one specific hospital's active request, not free-browsing every
  // partner hospital, so letting them tap a different card here would let
  // them silently book against a hospital with no open request at all.
  final String? preselectedHospitalId;
  // Gate added so every entry point that can reach this screen (Home tab's
  // Priority Request Feed, Appointment tab's own CTA, the notification
  // bell's "accept slot") is protected in one place, instead of needing
  // the same check duplicated at each call site.
  final bool isVerified;

  const EligibleAppointView({
    super.key,
    required this.isFirstTimeDonor,
    required this.token,
    required this.onBookingCompleted,
    this.preselectedHospitalId,
    this.isVerified = false,
  });

  @override
  State<EligibleAppointView> createState() => _EligibleAppointViewState();
}

class _EligibleAppointViewState extends State<EligibleAppointView> {
  List<_Hospital> _hospitals = [];
  bool _loadingHospitals = true;
  String? _loadError;

  String? _selectedHospitalId;
  DateTime? _selectedDate;
  String? _selectedTime;

  bool _booking = false;
  String? _bookingError;

  // The backend has no slot-discovery endpoint — appointment capacity is
  // just "how many rows already exist for this exact hospital+timestamp"
  // (see bookAppointment, appointments.service.js) — so a fixed hourly
  // slot list picked here is the simplest honest way to offer choices
  // without pretending to know real per-slot availability ahead of time.
  // Fully-booked slots are only discovered when you actually try to book
  // (409 response), same as walk-in booking at the front desk.
  final List<String> _timeSlots = [
    '08:00 AM - 09:00 AM',
    '09:00 AM - 10:00 AM',
    '10:00 AM - 11:00 AM',
    '01:00 PM - 02:00 PM',
    '02:00 PM - 03:00 PM',
    '03:00 PM - 04:00 PM',
  ];

  late final List<DateTime> _dateOptions;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    // Starts tomorrow, not today — avoids the edge case of picking a time
    // slot that's already passed later today with no time-of-day
    // awareness in the picker.
    _dateOptions = List.generate(
      7,
      (i) => DateTime(today.year, today.month, today.day).add(Duration(days: i + 1)),
    );
    _selectedDate = _dateOptions.first;
    _loadHospitals();
  }

  Future<void> _loadHospitals() async {
    setState(() {
      _loadingHospitals = true;
      _loadError = null;
    });
    try {
      final raw = await ApiService.listHospitals(widget.token);
      if (!mounted) return;
      setState(() {
        _hospitals = raw.map((h) => _Hospital.fromJson(h as Map<String, dynamic>)).toList();
        _loadingHospitals = false;
        if (widget.preselectedHospitalId != null &&
            _hospitals.any((h) => h.id == widget.preselectedHospitalId)) {
          _selectedHospitalId = widget.preselectedHospitalId;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loadingHospitals = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not reach the ResQ server.';
        _loadingHospitals = false;
      });
    }
  }

  /// Parses a slot label's start time, e.g. "08:00 AM - 09:00 AM" -> (8, 0).
  /// Hand-rolled instead of pulling in intl for one fixed string format.
  (int, int) _parseSlotStart(String slot) {
    final startPart = slot.split(' - ').first.trim(); // "08:00 AM"
    final meridiem = startPart.substring(startPart.length - 2).toUpperCase();
    final timePart = startPart.substring(0, startPart.length - 2).trim();
    final parts = timePart.split(':');
    int hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    if (meridiem == 'PM' && hour != 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;
    return (hour, minute);
  }

  Future<void> _confirmBooking() async {
    final hospitalId = _selectedHospitalId;
    final date = _selectedDate;
    final time = _selectedTime;
    if (hospitalId == null || date == null || time == null || _booking) return;

    final (hour, minute) = _parseSlotStart(time);
    final scheduledAt = DateTime(date.year, date.month, date.day, hour, minute);

    setState(() {
      _booking = true;
      _bookingError = null;
    });

    try {
      final result = await ApiService.bookAppointment(
        widget.token,
        hospitalId: hospitalId,
        scheduledAt: scheduledAt,
      );
      final hospital = _hospitals.firstWhere((h) => h.id == hospitalId);
      if (!mounted) return;
      widget.onBookingCompleted({
        ...result,
        'hospitalName': hospital.name,
        'hospitalAddress': hospital.address,
      });
    } on ApiException catch (e) {
      // e.message is the backend's own text — e.g. "This time slot is
      // fully booked (5 donors max). Please choose a different time."
      // (bookAppointment, appointments.service.js) — safe to show as-is.
      if (!mounted) return;
      setState(() {
        _booking = false;
        _bookingError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _booking = false;
        _bookingError = 'Could not reach the ResQ server.';
      });
    }
  }

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  _Hospital? get _selectedHospital {
    for (final h in _hospitals) {
      if (h.id == _selectedHospitalId) return h;
    }
    return null;
  }

  /// 1 = choose center, 2 = choose date/time, 3 = ready to confirm.
  int get _currentStep {
    if (_selectedHospitalId == null) return 1;
    if (_selectedTime == null) return 2;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVerified) return _buildVerificationGate(context);

    final showSchedule = _selectedHospitalId != null;

    return Scaffold(
      backgroundColor: RQColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeroBand(),
                    const SizedBox(height: 16),
                    if (widget.isFirstTimeDonor) ...[
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildFirstTimeBadge()),
                      const SizedBox(height: 16),
                    ],
                    // STEP 1 — donation center
                    _buildStepCard(
                      step: 1,
                      title: widget.preselectedHospitalId != null ? 'Booking with' : 'Choose a donation center',
                      subtitle: widget.preselectedHospitalId != null
                          ? 'This hospital requested your blood type'
                          : 'Pick where you want to donate',
                      child: _buildHospitalSection(),
                    ),
                    if (showSchedule) ...[
                      const SizedBox(height: 14),
                      // STEP 2 — date
                      _buildStepCard(
                        step: 2,
                        title: 'Pick a date',
                        subtitle: 'Available for the next 7 days',
                        padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
                        child: SizedBox(
                          height: 86,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: _dateOptions.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (context, i) => _buildDateChip(_dateOptions[i]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // STEP 3 — time
                      _buildStepCard(
                        step: 3,
                        title: 'Pick a time',
                        subtitle: 'Each slot takes up to 5 donors',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSlotGroup('Morning', Icons.wb_sunny_outlined,
                                _timeSlots.where((s) => s.trim().split(' - ').first.endsWith('AM')).toList()),
                            const SizedBox(height: 14),
                            _buildSlotGroup('Afternoon', Icons.brightness_5_outlined,
                                _timeSlots.where((s) => s.trim().split(' - ').first.endsWith('PM')).toList()),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildReminderCard(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (showSchedule) _buildSummaryFooter(context),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Verification gate (unverified donors can't book yet)
  // ---------------------------------------------------------------------------

  Widget _buildVerificationGate(BuildContext context) {
    return Scaffold(
      backgroundColor: RQColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(color: RQColors.bloodTint, shape: BoxShape.circle),
                child: const Icon(Icons.verified_user_outlined, size: 44, color: RQColors.blood),
              ),
              const SizedBox(height: 20),
              const Text(
                'Verification required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: RQColors.ink),
              ),
              const SizedBox(height: 8),
              const Text(
                'To keep both donors and recipients safe, you need to complete ID and photo verification before booking a donation appointment.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: RQColors.muted, height: 1.5),
              ),
              const SizedBox(height: 24),
              RQButton(
                label: 'Get verified',
                icon: Icons.badge_outlined,
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => GetVerifiedView(token: widget.token)),
                  );
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Not now', style: TextStyle(color: RQColors.muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Building blocks
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
      color: RQColors.blood,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Book Appointment',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          AppNotificationBell(isEligible: true, donorBloodType: '', token: widget.token, isVerified: widget.isVerified),
        ],
      ),
    );
  }

  /// Red band continuing the app bar, with a white progress card over it.
  Widget _buildHeroBand() {
    final step = _currentStep;
    return Stack(
      children: [
        Container(height: 56, color: RQColors.blood),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: RQColors.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const RQIconBox(icon: Icons.event_available_rounded, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Reserve your donation slot',
                            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: RQColors.ink)),
                        Text(
                          step == 3 ? 'All set — review and confirm below' : 'Step $step of 3',
                          style: const TextStyle(fontSize: 12, color: RQColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _progressSegment('Center', done: step > 1, active: step == 1),
                  const SizedBox(width: 6),
                  _progressSegment('Date & time', done: step > 2, active: step == 2),
                  const SizedBox(width: 6),
                  _progressSegment('Confirm', done: false, active: step == 3),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _progressSegment(String label, {required bool done, required bool active}) {
    final Color bar = done || active ? RQColors.blood : RQColors.hairline;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 5,
            decoration: BoxDecoration(
              color: active && !done ? bar.withValues(alpha: 0.55) : bar,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (done) ...[
                const Icon(Icons.check_circle_rounded, size: 12, color: RQColors.success),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active || done ? FontWeight.w600 : FontWeight.w500,
                    color: active || done ? RQColors.ink : RQColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required int step,
    required String title,
    String? subtitle,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: RQColors.card, borderRadius: BorderRadius.circular(20)),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: padding.horizontal == 0 ? const EdgeInsets.symmetric(horizontal: 16) : EdgeInsets.zero,
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: RQColors.blood, shape: BoxShape.circle),
                  child: Text('$step',
                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: RQColors.ink)),
                      if (subtitle != null)
                        Text(subtitle, style: const TextStyle(fontSize: 12, color: RQColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildHospitalSection() {
    if (_loadingHospitals) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: RQColors.blood)),
      );
    }
    if (_loadError != null) return _buildLoadErrorCard();
    if (_hospitals.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No partner hospitals are on file yet. Check back later.',
          style: TextStyle(fontSize: 13, color: RQColors.muted),
        ),
      );
    }
    if (widget.preselectedHospitalId != null) {
      // Locked to whichever hospital's active request the donor is
      // responding to — no picker, so there's no way to accidentally book
      // against a different hospital that has no open request at all.
      return _buildClinicCard(
        _hospitals.firstWhere(
          (h) => h.id == widget.preselectedHospitalId,
          orElse: () => _hospitals.first,
        ),
        locked: true,
      );
    }
    return Column(children: _hospitals.map((h) => _buildClinicCard(h)).toList());
  }

  Widget _buildLoadErrorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RQColors.warningTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: RQColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(_loadError!, style: const TextStyle(fontSize: 12.5, color: RQColors.warning))),
          TextButton(
            onPressed: _loadHospitals,
            child: const Text('Retry', style: TextStyle(color: RQColors.blood, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstTimeBadge() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RQColors.warningTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          RQIconBox(icon: Icons.stars_rounded, size: 36, background: Colors.white, color: RQColors.warning),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('First-time donor priority',
                    style: TextStyle(color: RQColors.warning, fontSize: 13, fontWeight: FontWeight.w700)),
                Text('Your first donation gets priority in the queue.',
                    style: TextStyle(color: RQColors.body, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicCard(_Hospital hospital, {bool locked = false}) {
    final isSelected = locked || _selectedHospitalId == hospital.id;
    final address = [hospital.address, hospital.city].where((s) => s.isNotEmpty).join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isSelected ? const Color(0xFFFDF5F5) : RQColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isSelected ? RQColors.blood : RQColors.hairline, width: isSelected ? 2 : 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: locked
              ? null
              : () => setState(() {
                    _selectedHospitalId = hospital.id;
                    _selectedTime = null;
                    _bookingError = null;
                  }),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const RQIconBox(icon: Icons.local_hospital_rounded, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hospital.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: RQColors.ink, height: 1.3)),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(Icons.place_outlined, size: 13, color: RQColors.muted),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(address, style: const TextStyle(fontSize: 12, color: RQColors.muted, height: 1.35)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                locked
                    ? const Icon(Icons.lock_outline_rounded, size: 18, color: RQColors.blood)
                    : AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? RQColors.blood : Colors.transparent,
                          border: Border.all(color: isSelected ? RQColors.blood : RQColors.fieldBorder, width: 2),
                        ),
                        child: isSelected ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateChip(DateTime date) {
    final isSelected = _selectedDate != null && _sameDay(_selectedDate!, date);
    final tomorrow = _dateOptions.first;
    final topLabel = _sameDay(date, tomorrow) ? 'Tmrw' : _weekdays[date.weekday - 1];
    final isWeekend = date.weekday >= 6;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedDate = date;
        _selectedTime = null;
        _bookingError = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 62,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? RQColors.blood : RQColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? RQColors.blood : Colors.transparent, width: 1.5),
          boxShadow: isSelected
              ? [BoxShadow(color: RQColors.blood.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))]
              : null,
        ),
        // FittedBox so a large system font size can never overflow the chip.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                topLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white70 : (isWeekend ? RQColors.bloodText : RQColors.muted),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : RQColors.ink,
                ),
              ),
              Text(
                _months[date.month - 1],
                style: TextStyle(fontSize: 10.5, color: isSelected ? Colors.white70 : RQColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotGroup(String label, IconData icon, List<String> slots) {
    if (slots.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: RQColors.muted),
            const SizedBox(width: 6),
            Text(label.toUpperCase(),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.7, color: RQColors.muted)),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 8.0;
            final w = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: slots.map((slot) => SizedBox(width: w, child: _buildTimeSlot(slot))).toList(),
            );
          },
        ),
      ],
    );
  }

  /// "08:00 AM - 09:00 AM" → "8:00 – 9:00 AM" (shorter, fits two per row).
  String _slotLabel(String slot) {
    final parts = slot.split(' - ');
    if (parts.length != 2) return slot;
    String trim(String t) => t.trim().replaceFirst(RegExp(r'^0'), '');
    final start = trim(parts[0]);
    final end = trim(parts[1]);
    final startMer = start.substring(start.length - 2);
    final endMer = end.substring(end.length - 2);
    final startTime = start.substring(0, start.length - 2).trim();
    return startMer == endMer ? '$startTime – $end' : '$start – $end';
  }

  Widget _buildTimeSlot(String slot) {
    final isSelected = _selectedTime == slot;
    return Material(
      color: isSelected ? RQColors.blood : RQColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? RQColors.blood : RQColors.hairline, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
          _selectedTime = slot;
          _bookingError = null;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.schedule_rounded, size: 15, color: isSelected ? Colors.white : RQColors.muted),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _slotLabel(slot),
                    maxLines: 1,
                    style: TextStyle(
                      color: isSelected ? Colors.white : RQColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReminderCard() {
    Widget tip(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: RQColors.navy),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, color: RQColors.body))),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: RQColors.navyTint, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Before you go',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: RQColors.navy)),
          tip(Icons.bedtime_outlined, 'Get 6–8 hours of sleep the night before.'),
          tip(Icons.water_drop_outlined, 'Drink 500 mL of water 30 minutes before.'),
          tip(Icons.no_food_outlined, 'Skip fatty food and alcohol beforehand.'),
          tip(Icons.badge_outlined, 'Bring a valid ID.'),
        ],
      ),
    );
  }

  /// Sticky bottom summary: what's selected so far + the confirm button.
  Widget _buildSummaryFooter(BuildContext context) {
    final hospital = _selectedHospital;
    final date = _selectedDate;
    final dateText = date == null ? '—' : '${_weekdays[date.weekday - 1]}, ${_months[date.month - 1]} ${date.day}';
    final timeText = _selectedTime == null ? 'Pick a time' : _slotLabel(_selectedTime!);

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: RQColors.card,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const RQIconBox(icon: Icons.calendar_month_rounded, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$dateText · $timeText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _selectedTime == null ? RQColors.muted : RQColors.ink,
                      ),
                    ),
                    if (hospital != null)
                      Text(
                        hospital.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: RQColors.muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (_bookingError != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFB91C1C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_bookingError!,
                        style: const TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFFB91C1C))),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          RQButton(
            label: 'Confirm booking',
            icon: Icons.check_circle_outline_rounded,
            loading: _booking,
            onPressed: (_selectedTime != null && !_booking) ? _confirmBooking : null,
          ),
        ],
      ),
    );
  }
}