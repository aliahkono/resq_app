import 'package:flutter/material.dart';
import 'package:resq/utils/constants/theme_constants.dart';
import 'package:resq/views/appointment/eligible_appoint_view.dart';
import 'package:resq/widgets/app_notif_bell.dart';

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
  final String bloodType;
  final List<EmergencyBloodRequest> activeRequests;
  final Function(EmergencyBloodRequest)? onAcceptRequest;

  const EligibleHomeView({
    super.key,
    this.isFirstTimeDonor = false,
    this.donorName = '',
    this.bloodType = '',
    this.activeRequests = const [],
    this.onAcceptRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBEBEB),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                child: isFirstTimeDonor
                    ? _buildFirstTimeDonorView(context)
                    : _buildActiveDonorView(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 14, bottom: 14, left: 16, right: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF7D1B22),
      ),
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
              const Text(
                'Dashboard',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          AppNotificationBell(
            isEligible: true,
            donorBloodType: bloodType,
          ),
        ],
      ),
    );
  }

  Widget _buildFirstTimeDonorView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            color: const Color(0xFF8A1E26),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7D1B22).withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: const [
                  Expanded(child: Divider(color: Colors.white38, thickness: 1)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'FIRST-TIME DONOR PRIORITY',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.white38, thickness: 1)),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'READY FOR YOUR\nFIRST SAVING\nMOMENT?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'You are eligible to donate! Step up as a first-time hero and help local patients in need.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => EligibleAppointView(
                          isFirstTimeDonor: true,
                          onBookingCompleted: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Donation slot booked successfully!'),
                                backgroundColor: Color(0xFF2E7D32),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE9E5E2),
                    foregroundColor: const Color(0xFF7D1B22),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Book Your 1st Donation Slot',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: const [
            Icon(Icons.map_outlined, color: Color(0xFF7D1B22), size: 18),
            SizedBox(width: 8),
            Text(
              "Your Hero's Path",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'STEP 1 OF 3: ACCOUNT CREATED',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4B5563)),
                  ),
                  Text(
                    '33%',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7D1B22)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  value: 0.33,
                  backgroundColor: Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8A1E26)),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildHeroTimelineItem(
          icon: Icons.check,
          title: 'Account Created',
          subtitle: 'Welcome to the squad!',
          isDone: true,
          showConnectingLine: true,
        ),
        _buildHeroTimelineItem(
          icon: Icons.verified_user_rounded,
          title: 'Profile Verified',
          subtitle: 'Medical check complete',
          isDone: true,
          showConnectingLine: true,
        ),
        _buildHeroTimelineItem(
          icon: Icons.calendar_month_outlined,
          title: 'First Appointment',
          subtitle: 'Upcoming Quest',
          isDone: false,
          showConnectingLine: false,
        ),
        const SizedBox(height: 22),
        const Text(
          'Urgent Blood Needs Near You',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF8A1E26),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'NEW QUEST',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Quest: Find a Clinic',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Discover nearby sanctuary centers where you can fulfill your heroic duty.',
                style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.35),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  SizedBox(
                    width: 76,
                    height: 28,
                    child: Stack(
                      children: [
                        const Positioned(
                          left: 0,
                          child: CircleAvatar(
                            radius: 14,
                            backgroundImage: AssetImage('assets/images/donor_sample.jpg'),
                            child: Icon(Icons.person, size: 16, color: Colors.grey),
                          ),
                        ),
                        const Positioned(
                          left: 20,
                          child: CircleAvatar(
                            radius: 14,
                            backgroundImage: AssetImage('assets/images/donor_sample.jpg'),
                            child: Icon(Icons.person, size: 16, color: Colors.grey),
                          ),
                        ),
                        Positioned(
                          left: 40,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Color(0xFF531116),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              '+42',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Donors active nearby',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => EligibleAppointView(
                          isFirstTimeDonor: true,
                          onBookingCompleted: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Quest appointment slot confirmed!'),
                                backgroundColor: Color(0xFF2E7D32),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.explore_outlined, size: 18, color: Color(0xFF1E1E1E)),
                  label: const Text(
                    'Start Quest',
                    style: TextStyle(color: Color(0xFF1E1E1E), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
            children: [
              TextSpan(text: 'First-Time Donor Guide '),
              TextSpan(text: '| ', style: TextStyle(color: Color(0xFF7D1B22))),
              TextSpan(text: 'What to Expect'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildGuideStepCard(
          icon: Icons.timer_outlined,
          title: 'Whole process takes under 45 minutes',
          subtitle: 'Includes registration and mini-physical.',
        ),
        const SizedBox(height: 10),
        _buildGuideStepCard(
          icon: Icons.water_drop_outlined,
          title: 'Actual blood extraction only takes 8-10 mins',
          subtitle: "Just a quick pinch, then you're saving lives.",
        ),
        const SizedBox(height: 10),
        _buildGuideStepCard(
          icon: Icons.cookie_outlined,
          title: 'Free snacks & refreshments afterward',
          subtitle: 'Enjoy some treats in our relaxation lounge.',
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: () => _showWalkthroughModal(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7D1B22),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Read Step-by-Step Walkthrough',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildActiveDonorView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFEBF3FE),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: const [
              Icon(Icons.celebration_outlined, color: Color(0xFF1D4ED8), size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Good News: You are eligible to donate!',
                  style: TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text(
                'Status: Eligible',
                style: TextStyle(color: Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "You're ready to save lives again!",
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E1E1E),
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF4B5563), height: 1.4),
            children: [
              const TextSpan(text: 'Your blood type ('),
              TextSpan(text: bloodType, style: const TextStyle(color: Color(0xFF8A1E26), fontWeight: FontWeight.bold)),
              const TextSpan(text: ') is in high demand near you. Hospitals are currently facing a shortage.'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Container(width: 3.5, height: 16, decoration: BoxDecoration(color: const Color(0xFF7D1B22), borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Urgent Blood Requests', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF7D1B22))),
                Text('Nearby clinics in critical need', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (activeRequests.isEmpty)
          _buildDefaultRequestCard(context)
        else
          ...activeRequests.map((req) => _buildDynamicRequestCard(context, req)),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF8A1E26),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7D1B22).withOpacity(0.2),
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
                children: const [
                  Text(
                    'Community Impact',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Icon(Icons.military_tech_outlined, color: Colors.white, size: 22),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Units Donated', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                          SizedBox(height: 4),
                          Text('4', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Lives Saved', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                          SizedBox(height: 4),
                          Text('12', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Community Blood Drives',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
        ),
        const SizedBox(height: 12),
        _buildBloodDriveCard(
          month: 'JUL',
          day: '25',
          title: 'Central Plaza Community Hall',
          time: '09:00 AM – 04:00 PM',
          attendeesCount: '14 local donors attending',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Registered interest for Central Plaza Community Drive!')),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildBloodDriveCard(
          month: 'AUG',
          day: '02',
          title: 'Tech Park Wellness Center',
          time: '10:00 AM – 05:00 PM',
          attendeesCount: '8 local donors attending',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Registered interest for Tech Park Wellness Drive!')),
            );
          },
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: const DecorationImage(
              image: AssetImage('assets/images/donor_sample.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.15),
                  Colors.black.withOpacity(0.85),
                ],
              ),
            ),
            padding: const EdgeInsets.all(16),
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'What happens to your blood?',
                  style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                Text(
                  'Learn how your single donation can save up to three separate lives.',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildHeroTimelineItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDone,
    required bool showConnectingLine,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDone ? const Color(0xFF8A1E26) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF8A1E26), width: 1.8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isDone ? Colors.white : const Color(0xFF8A1E26),
              ),
            ),
            if (showConnectingLine)
              Container(
                width: 2,
                height: 24,
                color: const Color(0xFF8A1E26),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuideStepCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF7D1B22), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: const Color(0xFF1E1E1E)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultRequestCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'CRITICAL',
                  style: TextStyle(color: Color(0xFFC62828), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const Text(
                '1.8 km',
                style: TextStyle(color: Color(0xFF4B5563), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "St. Mary's General Hospital",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildBloodPill('O+'),
              const SizedBox(width: 6),
              _buildBloodPill('A+'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: () {
                if (onAcceptRequest != null) {
                  onAcceptRequest!(
                    EmergencyBloodRequest(
                      id: 'REQ-9901',
                      hospital: "St. Mary's General Hospital",
                      bloodType: 'O+',
                      urgency: 'CRITICAL',
                      distance: '1.8 km',
                      unitsNeeded: 3,
                      timeAgo: 'Just now',
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8A1E26),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text(
                'Reserve Slot',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicRequestCard(BuildContext context, EmergencyBloodRequest req) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  req.urgency,
                  style: const TextStyle(color: Color(0xFFC62828), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                req.distance,
                style: const TextStyle(color: Color(0xFF4B5563), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            req.hospital,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildBloodPill(req.bloodType),
              const SizedBox(width: 8),
              Text('${req.unitsNeeded} Units Needed', style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280))),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: onAcceptRequest != null ? () => onAcceptRequest!(req) : () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8A1E26),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text(
                'Reserve Slot',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBloodPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF3FE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFF1E3A8A), fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBloodDriveCard({
    required String month,
    required String day,
    required String title,
    required String time,
    required String attendeesCount,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFFDE8E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF7D1B22), width: 1.2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    month,
                    style: const TextStyle(color: Color(0xFF7D1B22), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    day,
                    style: const TextStyle(color: Color(0xFF1E1E1E), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF8A1E26)),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF6B7280)),
                      const SizedBox(width: 4),
                      Text(time, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(attendeesCount, style: const TextStyle(fontSize: 10.5, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF8A1E26)),
          ],
        ),
      ),
    );
  }

  void _showWalkthroughModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Step-by-Step Donation Walkthrough',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF7D1B22)),
            ),
            const SizedBox(height: 12),
            const Text(
              '1. Registration: Quick ID verification and intake assessment.\n2. Mini-Physical: Checking blood pressure, pulse, and hemoglobin drop.\n3. The Donation: 8-10 mins resting comfortably while drawing 1 unit.\n4. Recovery Lounge: Free refreshments, juice, and relaxation before heading home.',
              style: TextStyle(fontSize: 12.5, height: 1.45, color: Color(0xFF2C2C2C)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7D1B22)),
                child: const Text('GOT IT', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}