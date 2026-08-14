import 'package:flutter/material.dart';
import 'package:resq/utils/constants/theme_constants.dart';

class EmergencyBloodRequest {
  final String id;
  final String hospital;
  final String bloodType;
  final String urgency;
  final String distance;
  final int unitsNeeded;
  final String timeAgo;

  EmergencyBloodRequest({
    required this.id,
    required this.hospital,
    required this.bloodType,
    required this.urgency,
    required this.distance,
    required this.unitsNeeded,
    required this.timeAgo,
  });
}

class EligibleHomeView extends StatelessWidget {
  final bool isFirstTimeDonor;
  final String donorName;
  final List<EmergencyBloodRequest> activeRequests;
  final Function(EmergencyBloodRequest)? onAcceptRequest;

  const EligibleHomeView({
    super.key,
    this.isFirstTimeDonor = false,
    this.donorName = 'Donor',
    this.activeRequests = const [],
    this.onAcceptRequest,
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

              // Requests Header
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
                  if (activeRequests.isNotEmpty)
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        'View All (${activeRequests.length})',
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

              // Dynamic Content: Empty State vs Live Broadcast Requests
              if (activeRequests.isEmpty)
                _buildNoRequestsEmptyState()
              else
                ...activeRequests.map(
                      (request) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildRequestCard(request),
                  ),
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
              backgroundColor: ResQTheme.primaryCrimson.withValues(alpha: 0.1),
              child: Text(
                donorName.isNotEmpty ? donorName[0].toUpperCase() : 'D',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ResQTheme.primaryCrimson,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $donorName!',
                  style: ResQTheme.heading2.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ResQTheme.textDark,
                  ),
                ),
                Text(
                  isFirstTimeDonor ? 'First-Time Hero' : 'Life Saver • Verified Donor',
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
                  'Active on standby for emergency hospital broadcasts',
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
            'Ready for Your 1st Contribution!',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'You are registered and fully eligible. When local hospitals broadcast urgent blood needs matching your blood type, you will be notified immediately.',
            style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Donor Status & Readiness',
            style: ResQTheme.heading3.copyWith(fontSize: 15, fontWeight: FontWeight.bold, color: ResQTheme.textDark),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetric('Readiness', 'Active', Icons.bolt_rounded),
              _buildMetric('Queue Priority', 'High', Icons.priority_high_rounded),
              _buildMetric('Status', 'Verified', Icons.verified_rounded),
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
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: ResQTheme.textMuted, fontSize: 11)),
      ],
    );
  }

  // Empty State when no hospital admin has broadcasted a blood request
  Widget _buildNoRequestsEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ResQTheme.lightBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ResQTheme.primaryCrimson.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              size: 36,
              color: ResQTheme.primaryCrimson,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Active Blood Requests',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: ResQTheme.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nearby hospitals currently have adequate supplies. You will receive an instant push notification when an emergency request is pinged.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: ResQTheme.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // Dynamic Emergency Request Card
  Widget _buildRequestCard(EmergencyBloodRequest request) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
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
                  color: ResQTheme.primaryCrimson.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  request.urgency,
                  style: TextStyle(color: ResQTheme.primaryCrimson, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              Text(request.timeAgo, style: TextStyle(color: ResQTheme.textMuted, fontSize: 11)),
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
                    request.bloodType,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.hospital, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('${request.distance} • ${request.unitsNeeded} Units Needed', style: TextStyle(color: ResQTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAcceptRequest != null ? () => onAcceptRequest!(request) : () {},
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