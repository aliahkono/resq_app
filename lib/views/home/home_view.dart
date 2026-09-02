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

class HomeView extends StatefulWidget {
  final String donorName;
  final String bloodType;
  final String donorId;
  final String phoneNum;
  final String donorEmail;
  final ScreenNPTModel? screeningModel;
  final ClassificationResult? classificationResult;
  final bool isFirstTimeDonor;

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
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _currentTabIndex = 0;
  ClassificationResult _effectiveResult = ClassificationResult(status: EligibleStats.deferredWeight);
  ScreenNPTModel? _currentScreeningModel;
  bool _isFirstTime = true;

  ClinicalVitalsRecord? _clinicalVitalsRecord;
  ConfirmedAppointmentData? _confirmedAppointment;
  final List<EmergencyBloodRequest> _activeRequests = [];

  @override
  void initState() {
    super.initState();
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

  Widget _buildTopHeader() {
    String title = 'Dashboard';
    if (_currentTabIndex == 1) title = 'Appointment';
    if (_currentTabIndex == 2) title = 'Profile & Records';

    return Container(
      color: const Color(0xFF7D1B22),
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
                            ),
                          ),
                        );
                      },
                    ),
                  AppNotificationBell(
                    isEligible: _effectiveResult.isEligible,
                    donorBloodType: widget.bloodType,
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
            : _buildIneligibleHomeSafe(
          activeDonorName: activeDonorName,
          activeBloodType: activeBloodType,
          activeDonorId: activeDonorId,
        );
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

  Widget _buildIneligibleHomeSafe({
    required String activeDonorName,
    required String activeBloodType,
    required String activeDonorId,
  }) {
    try {
      return IneligibleHomeView(
        key: ValueKey(
          'ineligible_${_effectiveResult.status.name}_${_effectiveResult.daysRemaining}_${_isFirstTime ? 'first' : 'repeat'}',
        ),
        classificationResult: _effectiveResult,
        isFirstTimeDonor: _isFirstTime,
        donorName: activeDonorName,
        bloodType: activeBloodType,
        donorId: activeDonorId,
      );
    } catch (e) {
      debugPrint('HomeView: ineligible tab fallback due to build error: $e');
      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: const Text(
              'Temporary deferral details could not be rendered. Please tap Update Health Assessment to continue.',
              style: TextStyle(
                color: Color(0xFF7D1B22),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _openRetakeScreening,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7D1B22),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text(
                'Update Health Assessment',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      );
    }
  }
}