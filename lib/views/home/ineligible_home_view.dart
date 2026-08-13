import 'package:flutter/material.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/utils/constants/theme_constants.dart';
import 'package:resq/utils/helpers/eligibility_rules.dart';

class IneligibleHomeView extends StatelessWidget {
  final ClassificationResult? classificationResult;
  final int daysRemaining;
  final bool isFirstTimeDonor;

  const IneligibleHomeView({
    super.key,
    this.classificationResult,
    this.daysRemaining = 45,
    this.isFirstTimeDonor = false,
  });

  @override
  Widget build(BuildContext context) {
    // Determine effective status and days remaining from classification result
    final status = classificationResult?.status ?? EligibleStats.deferredWeight;
    final effectiveDays = classificationResult?.daysRemaining ?? daysRemaining;

    final String reasonTitle = EligibilityRules.getStatsTitle(status);
    final String reasonDesc = classificationResult != null
        ? EligibilityRules.getStatsDesc(classificationResult!)
        : EligibilityRules.getStatsDesc(
      ClassificationResult(status: status, daysRemaining: effectiveDays),
    );

    return Scaffold(
      backgroundColor: ResQTheme.bgOffWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Navigation / Greeting Header
              _buildHeader(),

              const SizedBox(height: 20),

              // Dynamic Deferral Banner (Figma #1249-1725 & #720-1366)
              _buildDeferralBanner(reasonTitle, reasonDesc),

              const SizedBox(height: 20),

              // Countdown / Goal Progress Card
              _buildCountdownOrGoalCard(status, effectiveDays),

              const SizedBox(height: 24),

              // "What To Do Next" Health Guidance Box
              _buildActionableGuidanceCard(status),

              const SizedBox(height: 24),

              // Recovery & Re-Screening Roadmap
              Text(
                isFirstTimeDonor ? 'Pre-Screening Roadmap' : 'Recovery & Iron Restoration',
                style: ResQTheme.heading2.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ResQTheme.textDark,
                ),
              ),
              const SizedBox(height: 12),

              _buildRoadmapCard(status, isFirstTimeDonor),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.orange.shade100,
              child: const Icon(Icons.schedule_rounded, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, Donor!',
                  style: ResQTheme.heading2.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ResQTheme.textDark,
                  ),
                ),
                Text(
                  isFirstTimeDonor ? 'First-Time Assessment' : 'Recovery Phase',
                  style: TextStyle(fontSize: 12, color: ResQTheme.textMuted),
                ),
              ],
            ),
          ],
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded, size: 26),
        ),
      ],
    );
  }

  Widget _buildDeferralBanner(String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFE65100),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFFF57C00),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownOrGoalCard(EligibleStats status, int days) {
    // Custom handling if deferral is weight-related (< 50kg)
    if (status == EligibleStats.deferredWeight) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              'Weight Requirement Target',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ResQTheme.textDark),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '50.0',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: ResQTheme.primaryCrimson,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'KG MINIMUM',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ResQTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'A minimum body mass of 50 kg is required by DOH safety standards to prevent donor fainting or sudden hypotension.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: ResQTheme.textMuted, height: 1.35),
            ),
          ],
        ),
      );
    }

    // Standard Countdown Timer for Days Remaining
    double progress = ((90 - days) / 90.0).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Days Remaining Until Eligible',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: ResQTheme.textDark),
          ),
          const SizedBox(height: 10),
          Text(
            '$days',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: ResQTheme.primaryCrimson,
            ),
          ),
          const Text(
            'DAYS RESTING',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: ResQTheme.lightBorder,
            valueColor: AlwaysStoppedAnimation<Color>(ResQTheme.primaryCrimson),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildActionableGuidanceCard(EligibleStats status) {
    String heading;
    List<String> actionTips;

    switch (status) {
      case EligibleStats.deferredWeight:
        heading = 'Steps to Reach 50 kg Target';
        actionTips = [
          'Increase nutrient-dense calorie intake (nuts, avocados, whole grains).',
          'Include protein-rich foods (chicken, eggs, legumes) to build lean mass.',
          'Hydrate well and track body mass weekly before re-screening.',
        ];
        break;
      case EligibleStats.deferredTattsPierce:
        heading = 'Tattoo & Piercing Safety Window';
        actionTips = [
          'Wait out the mandatory 6-month (180 days) clinical observation window.',
          'Keep the tattooed or pierced area clean and free from infection.',
          'Schedule an in-app re-screening reminder for your clearance date.',
        ];
        break;
      case EligibleStats.deferredAlcohol:
        heading = '24-Hour Sobriety & Recovery';
        actionTips = [
          'Drink 2 to 3 liters of water to restore optimal plasma hydration.',
          'Avoid further alcohol intake for at least 24 hours.',
          'Re-take the quick screening form tomorrow morning.',
        ];
        break;
      default:
        heading = 'Recommended Health Action Plan';
        actionTips = [
          'Consume iron-rich foods (spinach, liver, red meat, beans).',
          'Get 7 to 8 hours of restful sleep every night.',
          'Stay hydrated with plenty of water and fruit fluids daily.',
        ];
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ResQTheme.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety_rounded, color: ResQTheme.primaryCrimson, size: 22),
              const SizedBox(width: 8),
              Text(
                heading,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...actionTips.map(
                (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 16, color: ResQTheme.primaryCrimson),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(fontSize: 12, color: ResQTheme.textDark, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoadmapCard(EligibleStats status, bool isFirstTime) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          _buildRoadmapStep(
            '1',
            isFirstTime ? 'Follow Health Plan' : 'Restoration & Diet',
            status == EligibleStats.deferredWeight
                ? 'Reach minimum 50 kg body weight target'
                : 'Maintain iron-rich nutrition and hydration',
            true,
          ),
          const Divider(height: 24),
          _buildRoadmapStep(
            '2',
            'In-App Re-Screening',
            'Retake the digital screening form when rest period finishes',
            false,
          ),
          const Divider(height: 24),
          _buildRoadmapStep(
            '3',
            'Unlock Emergency Alerts',
            'Receive urgent blood recruitment broadcasts near you',
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildRoadmapStep(String stepNum, String title, String subtitle, bool isCurrent) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: isCurrent ? ResQTheme.primaryCrimson : Colors.grey.shade300,
          child: Text(
            stepNum,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              Text(subtitle, style: TextStyle(color: ResQTheme.textMuted, fontSize: 11.5)),
            ],
          ),
        ),
      ],
    );
  }
}