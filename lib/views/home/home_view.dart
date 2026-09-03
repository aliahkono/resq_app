import 'package:flutter/material.dart';
import 'package:resq/model/screening_input_model.dart';
import 'package:resq/model/clinical_rec_model.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/views/appointment/active_sched_view.dart';
import 'package:resq/views/appointment/eligible_appoint_view.dart';
import 'package:resq/views/appointment/ineligible_appoint_view.dart';
import 'package:resq/views/appointment/no_active_sched_view.dart';
import 'package:resq/views/auth/registration_wiz_view.dart';
import 'package:resq/views/home/eligible_home_view.dart';
import 'package:resq/views/home/ineligible_home_view.dart';
import 'package:resq/views/profile/donor_profile_view.dart';
import 'package:resq/views/settings/settings_view.dart';
import 'package:resq/widgets/custom_bot_nav_bar.dart';
import 'package:resq/widgets/app_notif_bell.dart';
import 'package:resq/services/api_service.dart';
import 'package:resq/services/notif_service.dart';

class HomeView extends StatefulWidget {
  final String donorName;
  final String bloodType;
  final String donorId;
  final String phoneNum;
  final String donorEmail;
  final ScreenNPTModel? screeningModel;
  final ClassificationResult? classificationResult;
  final bool isFirstTimeDonor;
  // Session token from login/OTP verification (see AuthService.token /
  // otp_ver_view.dart's _sessionToken) — threaded through so Settings can
  // call the real donor-portal endpoints (PATCH /api/donor/me, POST
  // /donor-auth/logout) instead of just editing local UI state.
  final String token;

  const HomeView({
    super.key,
    this.donorName = '',
    this.bloodType = '',
    this.donorId = '',
    this.phoneNum = '',
    this.donorEmail = '',
    this.screeningModel,
    this.classificationResult,
    this.isFirstTimeDonor = true,
    this.token = '',
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with WidgetsBindingObserver {
  int _currentTabIndex = 0;
  ClassificationResult _effectiveResult = ClassificationResult(status: EligibleStats.deferredWeight);
  ScreenNPTModel? _currentScreeningModel;
  bool _isFirstTime = true;

  ClinicalVitalsRecord? _clinicalVitalsRecord;
  ConfirmedAppointmentData? _confirmedAppointment;
  List<EmergencyBloodRequest> _activeRequests = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentScreeningModel = widget.screeningModel;

    try {
      if (widget.classificationResult != null) {
        _effectiveResult = widget.classificationResult!;
        _isFirstTime = widget.isFirstTimeDonor;
      } else if (_currentScreeningModel != null) {
        _effectiveResult = _currentScreeningModel!.evaluateEligibility();
        _isFirstTime = _currentScreeningModel!.screensNPT.isFirstTimeDonor;
      } else {
        _effectiveResult = ClassificationResult(status: EligibleStats.eligible);
        _isFirstTime = widget.isFirstTimeDonor;
      }
    } catch (e, st) {
      debugPrint('HomeView: eligibility evaluation failed: $e\n$st');
      // Fail safe instead of crashing the whole dashboard
      _effectiveResult = ClassificationResult(status: EligibleStats.deferredWeight);
      _isFirstTime = widget.isFirstTimeDonor;
    }

    _loadCurrentAppointment();
    _loadOpenRequests();
    NotificationService().refresh(widget.token);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The app has no push/WebSocket channel of its own (see
  // COORDINATING_HOSPITAL_NAME's donor-side counterpart, the realtime hub,
  // which only pushes to the *admin* dashboard) — so a check-in a hospital
  // staffer records by scanning this donor's QR pass (donors.controller.js's
  // completeAppointment) has no way to reach this screen instantly. Instead,
  // re-checking whenever the app comes back to the foreground means the
  // donor's own screen "closes" that appointment on its own the next time
  // they glance at their phone, without needing a manual pull-to-refresh.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadCurrentAppointment();
      _loadOpenRequests();
    }
  }

  /// GET /api/donor/appointments — populates _confirmedAppointment from
  /// whatever the donor actually has booked server-side, instead of always
  /// starting this screen with "no appointment" until the app fabricates
  /// one locally. Silent on failure: this is a background enrichment on
  /// open, not something the donor triggered, so a network hiccup here
  /// shouldn't block the rest of the home screen from rendering.
  Future<void> _loadCurrentAppointment() async {
    if (widget.token.isEmpty) return;
    try {
      final raw = await ApiService.listMyAppointments(widget.token);
      // Already ordered scheduled_at DESC by the backend (listMyAppointments,
      // donorPortal.controller.js) — the first pending/confirmed row is the
      // most relevant "active" appointment if a donor somehow has more than
      // one. completed/cancelled rows don't count as "active".
      final active = raw.cast<Map<String, dynamic>>().firstWhere(
            (a) => a['status'] == 'pending' || a['status'] == 'confirmed',
            orElse: () => const {},
          );
      if (!mounted) return;
      // Explicitly cleared (not just left alone) when nothing active comes
      // back — otherwise an appointment that just got checked in/completed
      // server-side would keep showing as "confirmed" on this screen
      // forever, since this used to only ever set _confirmedAppointment,
      // never unset it.
      setState(() => _confirmedAppointment = active.isEmpty ? null : _toConfirmedAppointment(active));
    } catch (_) {
      // See method comment — intentionally silent.
    }
  }

  /// Shared by both real appointment sources: the fetch-on-open above, and
  /// EligibleAppointView's onBookingCompleted after a real booking succeeds.
  ConfirmedAppointmentData _toConfirmedAppointment(Map<String, dynamic> appointment) {
    final scheduledAt = DateTime.parse(appointment['scheduledAt'] as String).toLocal();
    final id = appointment['id'] as String;
    return ConfirmedAppointmentData(
      id: id,
      facility: (appointment['hospitalName'] as String?) ?? 'ResQ Partner Facility',
      date: scheduledAt,
      timeSlot: _formatTimeSlot(scheduledAt),
      // The backend has no "queue number" concept (see bookAppointment,
      // appointments.service.js) — this is just a short, stable reference
      // to the real appointment id, not a fabricated random number like
      // before.
      queueNumber: 'APPT-${(id.length >= 8 ? id.substring(0, 8) : id).toUpperCase()}',
    );
  }

  /// GET /api/donor/requests — the real "Priority Request Feed" shown on
  /// the eligible Home tab (EligibleHomeView's "Urgent Blood Requests"
  /// section). Previously this list was hardcoded permanently empty with a
  /// comment saying nothing populated it. No donor GPS is collected yet (no
  /// location package wired into this app), so results come back ordered
  /// by urgency-then-recency rather than by distance — same fallback the
  /// backend itself uses when lat/lng aren't supplied. Silent on failure
  /// for the same reason as _loadCurrentAppointment: background enrichment
  /// on open, not a donor-triggered action.
  Future<void> _loadOpenRequests() async {
    if (widget.token.isEmpty) {
      debugPrint('HomeView._loadOpenRequests: skipped — no session token.');
      return;
    }
    try {
      final raw = await ApiService.listOpenRequests(widget.token);
      debugPrint('HomeView._loadOpenRequests: got ${raw.length} row(s): $raw');
      if (!mounted) return;
      setState(() {
        _activeRequests = raw
            .cast<Map<String, dynamic>>()
            .map(_toEmergencyBloodRequest)
            .toList();
      });
    } catch (e, st) {
      // Was silent before — logged now (debugPrint is a no-op cost-wise,
      // stays out of the user's way, but makes failures visible while
      // debugging instead of just always showing "no broadcasts").
      debugPrint('HomeView._loadOpenRequests failed: $e\n$st');
    }
  }

  EmergencyBloodRequest _toEmergencyBloodRequest(Map<String, dynamic> r) {
    final unitsNeeded = (r['unitsNeeded'] as num?)?.toInt() ?? 0;
    final unitsFulfilled = (r['unitsFulfilled'] as num?)?.toInt() ?? 0;
    // distanceKm comes from a `round(...::numeric, 1)` SQL expression — like
    // any other Postgres NUMERIC, the pg driver hands this back as a string
    // (e.g. "5.3"), not a number (same gotcha already hit once with
    // weight_kg — see eligibility_service.dart). Only present at all when
    // the app sends lat/lng, which it doesn't yet, but parsed defensively
    // for whenever that's added.
    final distanceKmRaw = r['distanceKm'];
    final distanceKm = distanceKmRaw is num
        ? distanceKmRaw
        : (distanceKmRaw is String ? num.tryParse(distanceKmRaw) : null);
    final secondsOpen = (r['secondsOpen'] as num?)?.toInt() ?? 0;
    return EmergencyBloodRequest(
      id: (r['requestCode'] as String?) ?? '',
      hospital: (r['hospitalName'] as String?) ?? 'Partner Hospital',
      hospitalId: (r['hospitalId'] as String?) ?? '',
      bloodType: (r['bloodType'] as String?) ?? widget.bloodType,
      urgency: (r['priority'] as String?) ?? 'NORMAL',
      // No donor GPS collected yet — see method comment above — so this is
      // honestly "unknown" rather than a fabricated number.
      distance: distanceKm != null ? '${distanceKm.toStringAsFixed(1)} km' : '—',
      unitsNeeded: (unitsNeeded - unitsFulfilled).clamp(0, unitsNeeded).toInt(),
      timeAgo: _formatSecondsAgo(secondsOpen),
    );
  }

  /// Pull-to-refresh on the eligible Home tab (see EligibleHomeView's
  /// onRefresh) — re-fetches everything that only ever loaded once on
  /// initState, so a broadcast created on the admin dashboard *while* the
  /// donor already has the app open actually shows up without them having
  /// to fully restart the app.
  Future<void> _refreshBroadcastData() async {
    await Future.wait([
      _loadOpenRequests(),
      NotificationService().refresh(widget.token),
      _loadCurrentAppointment(),
    ]);
  }

  String _formatSecondsAgo(int seconds) {
    if (seconds < 60) return 'Just now';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m ago';
    final hours = minutes ~/ 60;
    if (hours < 24) return '${hours}h ago';
    final days = hours ~/ 24;
    return '${days}d ago';
  }

  String _formatClockTime(DateTime dt) {
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final meridiem = dt.hour < 12 ? 'AM' : 'PM';
    return '${hour12.toString().padLeft(2, '0')}:$minute $meridiem';
  }

  String _formatTimeSlot(DateTime start) {
    final end = start.add(const Duration(hours: 1));
    return '${_formatClockTime(start)} - ${_formatClockTime(end)}';
  }

  /// Shared success handler for every "book an appointment" entry point in
  /// the app (EligibleHomeView's two CTAs, and the Appointment tab's own
  /// NoActiveSchedView flow) — one place that updates the real
  /// _confirmedAppointment state and jumps to the Appointment tab, so a
  /// booking made from the Home tab actually shows up there instead of
  /// just flashing a snackbar and being forgotten.
  void _handleBookingCompleted(Map<String, dynamic> appointment) {
    setState(() {
      _confirmedAppointment = _toConfirmedAppointment(appointment);
      _currentTabIndex = 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Appointment slot confirmed successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// PATCH /api/donor/appointments/:id/cancel — only clears the local
  /// _confirmedAppointment once the backend actually confirms the
  /// cancellation, so a failed request (network drop, already-cancelled
  /// elsewhere) doesn't leave the app showing "no appointment" for a slot
  /// that's still booked server-side.
  Future<void> _cancelCurrentAppointment() async {
    final appointment = _confirmedAppointment;
    if (appointment == null) return;
    try {
      await ApiService.cancelAppointment(widget.token, appointment.id);
      if (!mounted) return;
      setState(() => _confirmedAppointment = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment cancelled successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700, behavior: SnackBarBehavior.floating),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not reach the ResQ server.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openRetakeScreening() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RegistrationWizView(
          isRetake: true,
          initialScreening: _currentScreeningModel,
          donorName: widget.donorName,
          bloodType: widget.bloodType,
          donorId: widget.donorId,
          token: widget.token,
          onRetakeCompleted: _handleRetakeCompleted,
        ),
      ),
    );
  }

  /// Shared by every retake entry point (this method's own trigger, plus
  /// DonorProfileView's and IneligibleHomeView's own retake buttons, and
  /// Settings' Edit Personal Details modal) — RegistrationWizView has
  /// already saved the new answers to the backend by the time this runs
  /// (see registration_wiz_view.dart's _finishAssessment), so this is just
  /// refreshing this screen's in-memory copy to match what's now actually
  /// persisted, plus telling the donor what changed.
  void _handleRetakeCompleted(ScreenNPTModel updatedModel, ClassificationResult result) {
    setState(() {
      _currentScreeningModel = updatedModel;
      _effectiveResult = result;
      _isFirstTime = updatedModel.screensNPT.isFirstTimeDonor;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isEligible
              ? 'Assessment updated: You are now verified eligible to donate!'
              : 'Assessment updated: Temporarily deferred (${result.status.name})',
        ),
        backgroundColor: result.isEligible ? Colors.green : Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildTopHeader() {
    String title = 'Dashboard';
    if (_currentTabIndex == 1) title = 'Appointment';
    if (_currentTabIndex == 2) title = 'Profile & Records';

    return Container(
      color: const Color(0xFF9B1B20),
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 14, bottom: 14, left: 18, right: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/images/rq_logo_white.png',
                    height: 30,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Text(
                      'RQ',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(width: 1.5, height: 22, color: Colors.white60),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Row(
                children: [
                  if (_currentTabIndex == 2)
                    IconButton(
                      icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 22),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => SettingsView(
                              userName: widget.donorName,
                              userPhone: widget.phoneNum,
                              userEmail: widget.donorEmail,
                              token: widget.token,
                              // Needed for the retake-screening button
                              // inside Edit Personal Details — without
                              // these, that flow used to open the wizard
                              // completely blank and its result went
                              // nowhere (onRetakeCompleted was never
                              // supplied here before).
                              screeningModel: _currentScreeningModel,
                              donorName: widget.donorName,
                              bloodType: widget.bloodType,
                              donorId: widget.donorId,
                              onRetakeCompleted: _handleRetakeCompleted,
                            ),
                          ),
                        );
                      },
                    ),
                  AppNotificationBell(
                    isEligible: _effectiveResult.isEligible,
                    donorBloodType: widget.bloodType,
                    token: widget.token,
                    onBookingCompleted: _handleBookingCompleted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String activeDonorName = widget.donorName.isNotEmpty ? widget.donorName : 'John Doe';
    final String activeBloodType = widget.bloodType.isNotEmpty ? widget.bloodType : 'A+';
    final String activeDonorId = widget.donorId.isNotEmpty ? widget.donorId : 'BD-10942';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F5),
      body: Column(
        children: [
          _buildTopHeader(),
          Expanded(
            child: _buildCurrentTab(
              activeDonorName,
              activeBloodType,
              activeDonorId,
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildCurrentTab(
      String activeDonorName,
      String activeBloodType,
      String activeDonorId,
      ) {
    switch (_currentTabIndex) {
      case 0:
        return _effectiveResult.isEligible
            ? EligibleHomeView(
          isFirstTimeDonor: _isFirstTime,
          donorName: activeDonorName,
          bloodType: activeBloodType,
          token: widget.token,
          onBookingCompleted: _handleBookingCompleted,
          onRefresh: _refreshBroadcastData,
          activeRequests: _activeRequests,
          // Real GET /api/donor/requests data now (see _loadOpenRequests
          // above) — "Reserve Slot" opens a real booking flow for that
          // hospital instead of fabricating a fake confirmed appointment
          // with a blank id (which used to make cancellation silently a
          // no-op, since there was no real appointment behind it).
          onAcceptRequest: (request) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => EligibleAppointView(
                  isFirstTimeDonor: _isFirstTime,
                  token: widget.token,
                  preselectedHospitalId: request.hospitalId.isNotEmpty ? request.hospitalId : null,
                  onBookingCompleted: (appointment) {
                    Navigator.pop(context);
                    _handleBookingCompleted(appointment);
                  },
                ),
              ),
            );
          },
        )
            : IneligibleHomeView(
          classificationResult: _effectiveResult,
          isFirstTimeDonor: _isFirstTime,
          donorName: activeDonorName,
          bloodType: activeBloodType,
          donorId: activeDonorId,
          screeningModel: _currentScreeningModel,
          token: widget.token,
          onRetakeCompleted: _handleRetakeCompleted,
        );
      case 1:
        if (_effectiveResult.isEligible) {
          if (_confirmedAppointment != null) {
            return ActiveSchedView(
              appointment: _confirmedAppointment!,
              onCancelAppointment: _cancelCurrentAppointment,
            );
          } else {
            return NoActiveSchedView(
              isFirstTimeDonor: _isFirstTime,
              // Backend already scopes GET /api/donor/requests to PRC-Quezon
              // Chapter only (see COORDINATING_HOSPITAL_NAME), so the first
              // entry in _activeRequests — if any — is the one and only
              // bookable request. No client-side name filtering needed.
              activeRequest: _activeRequests.isNotEmpty ? _activeRequests.first : null,
              onBookAppointment: (hospitalId) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EligibleAppointView(
                      isFirstTimeDonor: _isFirstTime,
                      token: widget.token,
                      preselectedHospitalId: hospitalId,
                      onBookingCompleted: (appointment) {
                        Navigator.pop(context);
                        _handleBookingCompleted(appointment);
                      },
                    ),
                  ),
                );
              },
            );
          }
        } else {
          return IneligibleAppointView(
            isFirstTimeDonor: _isFirstTime,
            daysRemaining: _effectiveResult.daysRemaining,
            onRefreshScreening: _openRetakeScreening,
          );
        }
      case 2:
        return DonorProfileView(
          screeningModel: _currentScreeningModel,
          classificationResult: _effectiveResult,
          isFirstTimeDonor: _isFirstTime,
          donorName: activeDonorName,
          bloodType: activeBloodType,
          donorId: activeDonorId,
          token: widget.token,
          onProfileUpdated: _handleRetakeCompleted,
          clinicalVitals: _clinicalVitalsRecord,
        );
      default:
        return const SizedBox.shrink();
    }
  }

}