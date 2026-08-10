import 'package:flutter/material.dart';
import 'package:resq/utils/constants/theme_constants.dart';

class EligibleHomeView extends StatelessWidget {
  final bool isFirstTimeDonor;

  const EligibleHomeView({
    super.key,
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
              // Top Header Bar
              _buildHeader(context),

              const SizedBox(height: 20),

              // Status Banner (Eligible)
              _buildEligibilityBadge(),

              const SizedBox(height: 20),

              // Dynamic Onboarding Card (First-Time vs Recurring)
              if (isFirstTimeDonor)
                _buildFirstTimeBanner(context)
              else
                _buildActiveDonorImpactCard(),

              const SizedBox(height: 24),

              // Urgent Emergency Broadcast Request Feed
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Urgent Requests Near You',
                    style: ResQTheme.heading2.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ResQTheme.textDark,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'View All',
                      style: TextStyle(
                        color: ResQTheme.primaryCrimson,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Emergency Feed Cards
              _buildRequestCard(
                hospital: 'St. Jude Medical Center',
                bloodType: 'O-',
                urgency: 'CODE RED EMERGENCY',
                distance: '1.2 km away',
                unitsNeeded: 3,
                timeAgo: '12m ago',
              ),
              const SizedBox(height: 12),
              _buildRequestCard(
                hospital: 'Quezon Medical Center',
                bloodType: 'A+',
                urgency: 'URGENT REQUIREMENT',
                distance: '3.5 km away',
                unitsNeeded: 2,
                timeAgo: '28m ago',
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: ResQTheme.primaryCrimson.withOpacity(0.1),
              child: Icon(Icons.person, color: ResQTheme.primaryCrimson),
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
                  isFirstTimeDonor ? 'First-Time Hero' : 'Life Saver • 4 Donations',
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

  Widget _buildEligibilityBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'You Are Eligible to Donate!',
                  style: TextStyle(
                    color: Color(0xFF1B5E20),
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  'Ready for immediate slot reservation',
                  style: TextStyle(color: Color(0xFF388E3C), fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstTimeBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ResQTheme.primaryCrimson, const Color(0xFF7D2229)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to Your 1st Donation!',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete your donor profile and complete quick physical screening at the hospital to save up to 3 lives today.',
            style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: ResQTheme.primaryCrimson,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('VIEW DONOR CHECKLIST', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDonorImpactCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Lifetime Impact',
            style: ResQTheme.heading3.copyWith(fontSize: 15, fontWeight: FontWeight.bold, color: ResQTheme.textDark),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetric('Donations', '4x', Icons.water_drop_rounded),
              _buildMetric('Lives Saved', '12', Icons.favorite_rounded),
              _buildMetric('Rank', 'Hero', Icons.verified_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: ResQTheme.primaryCrimson, size: 24),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: TextStyle(color: ResQTheme.textMuted, fontSize: 11)),
      ],
    );
  }

  Widget _buildRequestCard({
    required String hospital,
    required String bloodType,
    required String urgency,
    required String distance,
    required int unitsNeeded,
    required String timeAgo,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ResQTheme.primaryCrimson.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  urgency,
                  style: TextStyle(color: ResQTheme.primaryCrimson, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              Text(timeAgo, style: TextStyle(color: ResQTheme.textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: ResQTheme.primaryCrimson,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    bloodType,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hospital, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('$distance • $unitsNeeded Units Needed', style: TextStyle(color: ResQTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: ResQTheme.primaryCrimson,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('RESPOND & ACCEPT QUEUE SLOT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}