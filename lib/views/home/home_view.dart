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
  bool _isLoading = true;
  ClassificationResult? _effectiveResult;
  ScreenNPTModel? _currentScreeningModel;
  bool _isFirstTime = true;

  ClinicalVitalsRecord? _clinicalVitalsRecord;
  ConfirmedAppointmentData? _confirmedAppointment;
  final List<EmergencyBloodRequest> _activeRequests = [];

  @override
  void initState() {
    super.initState();
    _currentScreeningModel = widget.screeningModel;
    _evaluateEligibility();
  }

  Future<void> _evaluateEligibility() async {
    ClassificationResult result;
    bool firstTime;

    if (widget.classificationResult != null) {
      result = widget.classificationResult!;
      firstTime = widget.isFirstTimeDonor;
    } else if (_currentScreeningModel != null) {
      result = _currentScreeningModel!.evaluateEligibility();
      firstTime = _currentScreeningModel!.screensNPT.isFirstTimeDonor;
    } else {
      await Future.delayed(const Duration(milliseconds: 300));
      result = ClassificationResult(status: EligibleStats.eligible);
      firstTime = widget.isFirstTimeDonor;
    }

    if (mounted) {
      setState(() {
        _effectiveResult = result;
        _isFirstTime = firstTime;
        _isLoading = false;
      });
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
                backgroundColor:
                result.isEligible ? Colors.green : Colors.orange,
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
          padding:
          const EdgeInsets.only(top: 14, bottom: 14, left: 18, right: 18),
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
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(width: 1.5, height: 22, color: Colors.white60),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Row(
                children: [
                  if (_currentTabIndex == 2)
                    IconButton(
                      icon: const Icon(Icons.settings_rounded,
                          color: Colors.white, size: 22),
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
                    isEligible: _effectiveResult?.isEligible ?? true,
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final String activeDonorName =
    widget.donorName.isNotEmpty ? widget.donorName : 'John Doe';

    final String activeBloodType =
    widget.bloodType.isNotEmpty ? widget.bloodType : 'A+';

    final String activeDonorId =
    widget.donorId.isNotEmpty ? widget.donorId : 'BD-10942';

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
        return (_effectiveResult?.isEligible ?? true)
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
                queueNumber:
                'QUEUE-${DateTime.now().millisecondsSinceEpoch % 1000}',
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
      case 1:
        if (_effectiveResult?.isEligible ?? true) {
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
                            queueNumber:
                            'QUEUE-${DateTime.now().millisecondsSinceEpoch % 1000}',
                          );
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                            Text('Appointment slot confirmed successfully!'),
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
            daysRemaining: _effectiveResult?.daysRemaining ?? 0,
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
}