import 'package:flutter/material.dart';
import 'package:resq/services/api_service.dart';
import 'package:resq/widgets/app_notif_bell.dart';

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

  const EligibleAppointView({
    super.key,
    required this.isFirstTimeDonor,
    required this.token,
    required this.onBookingCompleted,
    this.preselectedHospitalId,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBEBEB),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.isFirstTimeDonor) _buildFirstTimeBadge(),
                    const SizedBox(height: 16),
                    Text(
                      widget.preselectedHospitalId != null ? 'Booking With' : 'Choose a Donation Center',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                    ),
                    const SizedBox(height: 12),
                    if (_loadingHospitals)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator(color: Color(0xFF9B1B20))),
                      )
                    else if (_loadError != null)
                      _buildLoadErrorCard()
                    else if (_hospitals.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No partner hospitals are on file yet. Check back later.',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                        ),
                      )
                    else if (widget.preselectedHospitalId != null)
                      // Locked to whichever hospital's active request the
                      // donor is responding to — no picker, so there's no
                      // way to accidentally book against a different
                      // hospital that has no open request at all.
                      _buildClinicCard(
                        _hospitals.firstWhere(
                          (h) => h.id == widget.preselectedHospitalId,
                          orElse: () => _hospitals.first,
                        ),
                        locked: true,
                      )
                    else
                      ..._hospitals.map((h) => _buildClinicCard(h)),
                    if (_selectedHospitalId != null) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Choose a Date',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 68,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _dateOptions.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, i) => _buildDateChip(_dateOptions[i]),
                        ),
                      ),
                    ],
                    if (_selectedHospitalId != null && _selectedDate != null) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Available Time Slots',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _timeSlots.map((slot) => _buildTimeSlot(slot)).toList(),
                      ),
                      if (_bookingError != null) ...[
                        const SizedBox(height: 16),
                        Text(_bookingError!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
                      ],
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: (_selectedTime != null && !_booking) ? _confirmBooking : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9B1B20),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: _booking
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                                )
                              : const Text('Confirm Booking', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_loadError!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFBF360C))),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _loadHospitals,
            child: const Text('RETRY', style: TextStyle(color: Color(0xFF9B1B20), fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(color: Color(0xFF9B1B20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              const Text(
                'Book Appointment',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          AppNotificationBell(isEligible: true, donorBloodType: '', token: widget.token),
        ],
      ),
    );
  }

  Widget _buildFirstTimeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: const Row(
        children: [
          Icon(Icons.stars_rounded, color: Color(0xFFE65100), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'First-Time Donor Priority: Slots are prioritized for your first quest!',
              style: TextStyle(color: Color(0xFFBF360C), fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicCard(_Hospital hospital, {bool locked = false}) {
    bool isSelected = locked || _selectedHospitalId == hospital.id;
    return GestureDetector(
      onTap: locked
          ? null
          : () => setState(() {
                _selectedHospitalId = hospital.id;
                _selectedTime = null;
                _bookingError = null;
              }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF9B1B20) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    hospital.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E1E1E)),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF9B1B20), size: 20),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [hospital.address, hospital.city].where((s) => s.isNotEmpty).join(', '),
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateChip(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final isSelected = _selectedDate != null &&
        _selectedDate!.year == date.year &&
        _selectedDate!.month == date.month &&
        _selectedDate!.day == date.day;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedDate = date;
        _selectedTime = null;
        _bookingError = null;
      }),
      child: Container(
        width: 56,
        // Was vertical: 8 — with three lines of text (weekday/day/month)
        // stacked inside, that left the Column about 2px too tall for
        // whatever fixed height its parent (the horizontal date-chip strip)
        // gives this chip, overflowing on every render. 6 gives just enough
        // slack without visibly changing the chip's proportions.
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF9B1B20) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF9B1B20) : const Color(0xFFD1D5DB)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weekdays[date.weekday - 1],
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white70 : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF1E1E1E),
              ),
            ),
            Text(
              months[date.month - 1],
              style: TextStyle(
                fontSize: 9.5,
                color: isSelected ? Colors.white70 : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlot(String slot) {
    bool isSelected = _selectedTime == slot;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedTime = slot;
        _bookingError = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF9B1B20) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF9B1B20) : const Color(0xFFD1D5DB),
          ),
        ),
        child: Text(
          slot,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF4B5563),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
