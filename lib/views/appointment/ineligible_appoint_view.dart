import 'package:flutter/material.dart';
import 'package:resq/utils/constants/theme_constants.dart';

class IneligibleAppointView extends StatelessWidget {
  final bool isFirstTimeDonor;
  final int daysRemaining;
  final VoidCallback onRefreshScreening;

  const IneligibleAppointView({
    super.key,
    this.isFirstTimeDonor = false,
    this.daysRemaining = 45,
    required this.onRefreshScreening,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ResQTheme.bgOffWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Donation Schedule',
                style: ResQTheme.heading1.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: ResQTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isFirstTimeDonor ? 'Pre-screening deferral status' : 'Active recovery period restrictions',
                style: TextStyle(fontSize: 13, color: ResQTheme.textMuted),
              ),
              const SizedBox(height: 28),

              // Deferral Warning Banner
              Container(
                padding: const EdgeInsets.all(18),
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
                            isFirstTimeDonor ? 'Initial Screening Deferral' : 'Mandatory Recovery Period',
                            style: const TextStyle(
                              color: Color(0xFFE65100),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isFirstTimeDonor
                                ? 'Appointment bookings are temporarily locked until baseline physical or health screening criteria are met.'
                                : 'Bookings are disabled during your NVBSP recovery window to protect your iron stores and plasma balance.',
                            style: const TextStyle(color: Color(0xFFF57C00), fontSize: 12, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Countdown / Clearance Indicator
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
                  ],
                ),
                child: Column(
                  children: [
                    const Text('Estimated Clearance Countdown', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text(
                      '$daysRemaining',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: ResQTheme.primaryCrimson,
                      ),
                    ),
                    const Text('DAYS REMAINING', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: ((90 - daysRemaining) / 90.0).clamp(0.0, 1.0),
                      backgroundColor: ResQTheme.lightBorder,
                      valueColor: AlwaysStoppedAnimation<Color>(ResQTheme.primaryCrimson),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Actionable Re-assessment Trigger
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: onRefreshScreening,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: ResQTheme.primaryCrimson,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: ResQTheme.primaryCrimson, width: 1.5),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text(
                    'RETAKE ELIGIBILITY ASSESSMENT',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}