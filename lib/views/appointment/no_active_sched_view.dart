import 'package:flutter/material.dart';
import 'package:resq/utils/constants/theme_constants.dart';
import 'package:resq/widgets/app_notif_bell.dart';

class NoActiveSchedView extends StatelessWidget {
  final bool isFirstTimeDonor;
  final VoidCallback onBookAppointment;

  const NoActiveSchedView({
    super.key,
    required this.isFirstTimeDonor,
    required this.onBookAppointment,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBEBEB),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppointmentHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7D1B22).withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.event_available_rounded,
                        size: 48,
                        color: Color(0xFF7D1B22),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isFirstTimeDonor
                          ? 'Ready for Your 1st Session?'
                          : 'No Active Appointment',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isFirstTimeDonor
                          ? 'You are verified and eligible to donate blood. Pick a convenient time slot at your nearest hospital or Red Cross chapter.'
                          : 'You currently do not have any pending or confirmed blood donation bookings. Reserve a time slot anytime.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: onBookAppointment,
                        icon: const Icon(Icons.calendar_month_rounded, size: 18),
                        label: Text(
                          isFirstTimeDonor
                              ? 'Book 1st Donation Appointment'
                              : 'Schedule New Appointment',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7D1B22),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.info_outline_rounded, color: Color(0xFF7D1B22), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'What to remember before booking',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E1E1E)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildTipItem('Have at least 6–8 hours of restful sleep.'),
                          _buildTipItem('Drink 500 mL of water 30 minutes before donating.'),
                          _buildTipItem('Avoid fatty foods and alcohol prior to your session.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentHeader(BuildContext context) {
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
                'Appointment',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const AppNotificationBell(
            isEligible: true,
            donorBloodType: 'O+',
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
          ),
        ],
      ),
    );
  }
}