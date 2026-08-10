import 'package:flutter/material.dart';
import 'package:resq/utils/constants/theme_constants.dart';

class IneligibleHomeView extends StatelessWidget {
  final int daysRemaining;
  final bool isFirstTimeDonor;

  const IneligibleHomeView({
    super.key,
    this.daysRemaining = 45,
    this.isFirstTimeDonor = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ResQTheme.bgOffWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header
              _buildHeader(),

              const SizedBox(height: 20),

              // Status Deferral Banner
              _buildDeferralBanner(),

              const SizedBox(height: 20),

              // Recovery Countdown Widget
              _buildCountdownCard(),

              const SizedBox(height: 24),

              // Recovery & Pre-Screening Roadmap
              Text(
                isFirstTimeDonor ? 'Pre-Screening Roadmap' : 'Recovery & Iron Restoration',
                style: ResQTheme.heading2.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ResQTheme.textDark,
                ),
              ),
              const SizedBox(height: 12),

              _buildRoadmapCard(),

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
              child: const Icon(Icons.schedule, color: Colors.orange),
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
                  isFirstTimeDonor ? 'Initial Deferral' : 'Recovery Phase',
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

  Widget _buildDeferralBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFirstTimeDonor
                      ? 'Temporary Screening Deferral'
                      : 'Mandatory 90-Day Recovery Period',
                  style: const TextStyle(
                    color: Color(0xFFE65100),
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isFirstTimeDonor
                      ? 'Health indicators require adjustment prior to 1st donation.'
                      : 'Active recruitment alerts suspended until recovery completion.',
                  style: const TextStyle(color: Color(0xFFF57C00), fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownCard() {
    double progress = (90 - daysRemaining) / 90.0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          const Text('Days Remaining Until Eligible', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            '$daysRemaining',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: ResQTheme.primaryCrimson,
            ),
          ),
          const Text('DAYS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 18),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: ResQTheme.lightBorder,
            valueColor: AlwaysStoppedAnimation<Color>(ResQTheme.primaryCrimson),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildRoadmapCard() {
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
          _buildRoadmapStep('1', 'Maintain Iron & Hydration', 'Consume iron-rich foods & hydrate daily', true),
          const Divider(height: 24),
          _buildRoadmapStep('2', 'Re-Screening Check', 'In-app pre-eligibility screening unlocks', false),
          const Divider(height: 24),
          _buildRoadmapStep('3', 'Ready for Matching', 'Receive Code Red emergency notifications again', false),
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
          child: Text(stepNum, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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