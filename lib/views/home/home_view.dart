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
import 'package:resq/widgets/custom_bot_nav_bar.dart';

class HomeView extends StatefulWidget {
  final String donorName;
  final String bloodType;
  final String donorId;
  final ScreenNPTModel? screeningModel;
  final ClassificationResult? classificationResult;
  final bool isFirstTimeDonor;

  const HomeView({
    super.key,
    this.donorName = '',
    this.bloodType = '',
    this.donorId = '',
    this.screeningModel,
    this.classificationResult,
    this.isFirstTimeDonor = true,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _currentTabIndex = 0;
  bool _isLoading = true;
  late ClassificationResult _effectiveResult;
  late ScreenNPTModel? _currentScreeningModel;
  late bool _isFirstTime;

  // Hospital clinical records (null until MedTech/Nurse records them via Dashboard)
  ClinicalVitalsRecord? _clinicalVitalsRecord;

  // Active confirmed appointment state
  ConfirmedAppointmentData? _confirmedAppointment;

  // Dynamic emergency blood requests stream / list from hospital-web-dashboard
  final List<EmergencyBloodRequest> _activeRequests = [];

  @override
  void initState() {
    super.initState();
    _currentScreeningModel = widget.screeningModel;
    _evaluateEligibility();
  }

  Future<void> _evaluateEligibility() async {
    if (widget.classificationResult != null) {
      _effectiveResult = widget.classificationResult!;
      _isFirstTime = widget.isFirstTimeDonor;
    } else if (_currentScreeningModel != null) {
      _effectiveResult = _currentScreeningModel!.evaluateEligibility();
      _isFirstTime = _currentScreeningModel!.screensNPT.isFirstTimeDonor;
    } else {
      await Future.delayed(const Duration(milliseconds: 300));
      _effectiveResult = ClassificationResult(status: EligibleStats.eligible);
      _isFirstTime = widget.isFirstTimeDonor;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Opens the unified registration wizard in Retake Mode, skipping account creation
  void _openRetakeScreening() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RegistrationWizView(
          isRetake: true,
          initialScreening: _currentScreeningModel,
          donorName: widget.donorName,
          bloodType: widget.bloodType,
          donorId: widget.donorId,
          onRetakeCompleted: (updatedModel, result) {
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
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
    final String activeDonorName = widget.donorName.isNotEmpty
        ? widget.donorName
        : 'John Doe';

    final String activeBloodType = widget.bloodType.isNotEmpty
        ? widget.bloodType
        : 'A+';

    final String activeDonorId = widget.donorId.isNotEmpty
        ? widget.donorId
        : 'BD-10942';

    switch (_currentTabIndex) {
    // =======================================================================
    // TAB 0: HOME DASHBOARD
    // =======================================================================
      case 0:
        return _effectiveResult.isEligible
            ? EligibleHomeView(
          isFirstTimeDonor: _isFirstTime,
          donorName: activeDonorName,
          bloodType: activeBloodType,
          activeRequests: _activeRequests,
          onAcceptRequest: (request) {
            setState(() {
              _confirmedAppointment = ConfirmedAppointmentData(
                facility: request.hospital,
                date: DateTime.now().add(const Duration(days: 1)),
                timeSlot: '09:00 AM - 10:00 AM',
                queueNumber: 'QUEUE-${DateTime.now().millisecondsSinceEpoch % 1000}',
              );
              _currentTabIndex = 1;
            });
          },
        )
            : IneligibleHomeView(
          classificationResult: _effectiveResult,
          isFirstTimeDonor: _isFirstTime,
          donorName: activeDonorName,
          bloodType: activeBloodType,
          donorId: activeDonorId,
        );

    // =======================================================================
    // TAB 1: SCHEDULE / APPOINTMENTS
    // =======================================================================
      case 1:
        if (_effectiveResult.isEligible) {
          if (_confirmedAppointment != null) {
            return ActiveSchedView(
              appointment: _confirmedAppointment!,
              onCancelAppointment: () {
                setState(() {
                  _confirmedAppointment = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Appointment cancelled successfully.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            );
          } else {
            return NoActiveSchedView(
              isFirstTimeDonor: _isFirstTime,
              onBookAppointment: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EligibleAppointView(
                      isFirstTimeDonor: _isFirstTime,
                      onBookingCompleted: () {
                        Navigator.pop(context);
                        setState(() {
                          _confirmedAppointment = ConfirmedAppointmentData(
                            facility: 'Philippine Red Cross - Quezon Chapter',
                            date: DateTime.now().add(const Duration(days: 2)),
                            timeSlot: '09:00 AM - 10:00 AM',
                            queueNumber: 'QUEUE-${DateTime.now().millisecondsSinceEpoch % 1000}',
                          );
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Appointment slot confirmed successfully!'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
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

    // =======================================================================
    // TAB 2: PROFILE & SETTINGS
    // =======================================================================
      case 2:
        return DonorProfileView(
          screeningModel: _currentScreeningModel,
          classificationResult: _effectiveResult,
          isFirstTimeDonor: _isFirstTime,
          donorName: activeDonorName,
          bloodType: activeBloodType,
          donorId: activeDonorId,
          onProfileUpdated: (updatedModel, result) {
            setState(() {
              _currentScreeningModel = updatedModel;
              _effectiveResult = result;
              _isFirstTime = updatedModel.screensNPT.isFirstTimeDonor;
            });
          },
          clinicalVitals: _clinicalVitalsRecord,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: _buildBody(),
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
}