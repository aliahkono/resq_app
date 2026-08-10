import 'package:flutter/material.dart';
import 'package:resq/utils/constants/theme_constants.dart';
import 'package:resq/views/auth/auth_landing_view.dart';

class TermsAndConditionsView extends StatefulWidget {
  const TermsAndConditionsView({super.key});

  @override
  State<TermsAndConditionsView> createState() => _TermsAndConditionsViewState();
}

class _TermsAndConditionsViewState extends State<TermsAndConditionsView> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isAgreed = false;

  final List<Map<String, String>> _termsSections = [
    {
      'section': 'SECTION I',
      'title': 'BINDING AGREEMENT & MISSION ALIGNMENT',
      'content':
      'By registering with the RESQ Mobile App, the user (hereinafter "the Donor") formally acknowledges and agrees to adhere to these Terms and Conditions. These protocols are designed to uphold the standards of Voluntary Non-Remunerated Blood Donation (VNRBD) and ensure the integrity of the emergency blood supply chain. Use of this platform constitutes a legally binding commitment between the Donor and RESQ to maintain the highest ethical standards in blood services.',
      'icon': 'verified_user',
    },
    {
      'section': 'SECTION II (2.1)',
      'title': 'PRELIMINARY ELIGIBILITY VALIDATION',
      'content':
      'Donor eligibility is preliminarily screened through a rule-based validation framework. This assessment utilizes medically recognized parameters including age, weight, blood type compatibility, and historical donation intervals. The Donor is ethically obligated to provide accurate and truthful information, as data integrity is critical to the clinical safety of blood recipients.',
      'icon': 'fact_check',
    },
    {
      'section': 'SECTION II (2.2 & 2.3)',
      'title': 'DEFERRAL PERIODS & HEALTH ASSESSMENT',
      'content':
      'Pursuant to DOH and NVBSP guidelines, whole blood donors are subject to a minimum 90-day eligibility interval between donations to support iron recovery and donor wellness.\n\nDigital validation on RESQ is supportive and does not constitute final medical clearance. On-site healthcare professionals at the Philippine Red Cross or affiliate blood centers retain absolute discretion to defer any donor based on immediate clinical evaluation.',
      'icon': 'health_and_safety',
    },
    {
      'section': 'SECTION III (3.1 & 3.2)',
      'title': 'DATA PRIVACY & INSTITUTIONAL USE',
      'content':
      'In compliance with the Data Privacy Act of 2012, RESQ processes sensitive personal health information including blood group, baseline medical indicators, and contact demographics with strict confidentiality.\n\nData is utilized exclusively for donor-recipient matching, geographic demand analysis, and medical record-keeping accessible to authorized hospital administrators via the secure RESQ dashboard.',
      'icon': 'privacy_tip',
    },
    {
      'section': 'SECTION III (3.3)',
      'title': 'EXPLICIT CONSENT & PROTECTION',
      'content':
      'Registration signifies the Donor’s explicit consent for health data processing. RESQ operates under data minimization principles; only operationally vital information is maintained. No integration with the Philippine Red Cross or national medical repositories occurs without specific institutional authorization.',
      'icon': 'gavel',
    },
    {
      'section': 'SECTION IV',
      'title': 'EMERGENCY NOTIFICATION & SCHEDULING',
      'content':
      'Urgency-Based Prioritization: Donation slots are allocated via a priority queuing algorithm favoring "Code Red" hospital requests, dispatched via Push & SMS channels.\n\nQuota Management: Notification broadcasts halt automatically when required clinical units are matched. Donors maintain complete autonomy over alert settings and kilometer radius limits in their settings profile.',
      'icon': 'notifications_active',
    },
    {
      'section': 'SECTION V',
      'title': 'LIABILITY & INSTITUTIONAL DISCLAIMER',
      'content':
      'Scope of Facilitation: RESQ serves strictly as an administrative and logistics facilitator between donors and medical institutions. RESQ does not engage in clinical procedures, testing, or cold chain maintenance.\n\nInstitutional Disclaimer: RESQ assumes no liability for telecommunication delays or post-donation clinical outcomes. RESQ supports, but does not replace, existing systems like BBIS/PBIS.',
      'icon': 'shield',
    },
    {
      'section': 'SECTION VI',
      'title': 'ACCOUNT SECURITY & TERMINATION',
      'content':
      'Donors are responsible for maintaining credential security, supported by in-app biometric authentication tools.\n\nProfile Lifecycle: Donors retain the Right to Erasure under the Data Privacy Act. Account termination programmatically purges personal indicators and transaction records from the platform database.',
      'icon': 'lock',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'verified_user': return Icons.verified_user_rounded;
      case 'fact_check': return Icons.fact_check_rounded;
      case 'health_and_safety': return Icons.health_and_safety_rounded;
      case 'privacy_tip': return Icons.privacy_tip_rounded;
      case 'gavel': return Icons.gavel_rounded;
      case 'notifications_active': return Icons.notifications_active_rounded;
      case 'shield': return Icons.shield_rounded;
      case 'lock': return Icons.lock_rounded;
      default: return Icons.description_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSteps = _termsSections.length;
    final progress = (_currentStep + 1) / totalSteps;

    return Scaffold(
      backgroundColor: ResQTheme.bgOffWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: _currentStep > 0
            ? IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: ResQTheme.textDark, size: 18),
          onPressed: () {
            _pageController.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
        )
            : IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: ResQTheme.textDark, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Terms & Conditions',
          style: ResQTheme.heading2.copyWith(
            fontSize: 18,
            color: ResQTheme.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Protocol Review',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ResQTheme.textMuted,
                        ),
                      ),
                      Text(
                        '${_currentStep + 1} of $totalSteps',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: ResQTheme.primaryCrimson,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: ResQTheme.lightBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(ResQTheme.primaryCrimson),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Card Deck View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: totalSteps,
                onPageChanged: (index) {
                  setState(() => _currentStep = index);
                },
                itemBuilder: (context, index) {
                  final section = _termsSections[index];
                  final isLastStep = index == totalSteps - 1;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section Icon Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: ResQTheme.primaryCrimson.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getIcon(section['icon']!),
                                color: ResQTheme.primaryCrimson,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              section['section']!,
                              style: const TextStyle(
                                color: ResQTheme.primaryCrimson,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Section Title
                        Text(
                          section['title']!,
                          style: ResQTheme.heading2.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ResQTheme.textDark,
                          ),
                        ),

                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),

                        // Section Body
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Text(
                              section['content']!,
                              style: ResQTheme.bodyText.copyWith(
                                fontSize: 13.5,
                                color: ResQTheme.textMuted,
                                height: 1.55,
                              ),
                            ),
                          ),
                        ),

                        // Final Agreement Checkbox
                        if (isLastStep) ...[
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () {
                              setState(() => _isAgreed = !_isAgreed);
                            },
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _isAgreed,
                                  activeColor: ResQTheme.primaryCrimson,
                                  onChanged: (val) {
                                    setState(() => _isAgreed = val ?? false);
                                  },
                                ),
                                const Expanded(
                                  child: Text(
                                    'I have read and agree to all RESQ Terms & Conditions and Privacy Protocols.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                children: [
                  if (_currentStep < totalSteps - 1) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _pageController.jumpToPage(totalSteps - 1);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: ResQTheme.lightBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'SKIP TO END',
                          style: TextStyle(
                            color: ResQTheme.textMuted,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_currentStep == totalSteps - 1 && !_isAgreed)
                          ? null
                          : () {
                        if (_currentStep < totalSteps - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          // Navigate to Landing View
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const AuthLandingView(),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ResQTheme.primaryCrimson,
                        disabledBackgroundColor: Colors.grey.shade300,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _currentStep == totalSteps - 1 ? 'ACCEPT & CONTINUE' : 'NEXT STEP',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}