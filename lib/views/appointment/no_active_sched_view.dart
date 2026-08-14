import 'package:flutter/material.dart';
import 'package:resq/utils/constants/theme_constants.dart';

class NoActiveSchedView extends StatelessWidget {
  final bool isFirstTimeDonor;
  final VoidCallback onBookAppointment;

  const NoActiveSchedView({
    super.key,
    this.isFirstTimeDonor = false,
    required this.onBookAppointment,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ResQTheme.bgOffWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
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
                isFirstTimeDonor
                    ? 'Your path to your first life-saving contribution'
                    : 'Manage your donation cycles and active bookings',
                style: TextStyle(fontSize: 13, color: ResQTheme.textMuted),
              ),
              const SizedBox(height: 32),

              // Empty State Banner / Card
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: ResQTheme.primaryCrimson.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.calendar_today_rounded,
                          size: 56,
                          color: ResQTheme.primaryCrimson,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No Active Schedule',
                        style: ResQTheme.heading2.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ResQTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Text(
                          isFirstTimeDonor
                              ? 'You have no upcoming appointments booked for your first donation. Secure a slot to get started!'
                              : 'You are currently eligible, but have no appointments scheduled for your next donation cycle.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: ResQTheme.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: onBookAppointment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ResQTheme.primaryCrimson,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                          label: const Text(
                            'BOOK APPOINTMENT SLOT',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
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