import 'package:flutter/material.dart';
import 'package:resq/utils/constants/theme_constants.dart';
import 'package:resq/widgets/app_notif_bell.dart';

class IneligibleAppointView extends StatelessWidget {
  final bool isFirstTimeDonor;
  final int daysRemaining;
  final VoidCallback onRefreshScreening;

  const IneligibleAppointView({
    super.key,
    required this.isFirstTimeDonor,
    required this.daysRemaining,
    required this.onRefreshScreening,
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
                        color: const Color(0xFFFFF3E0),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFCC80), width: 1.5),
                      ),
                      child: const Icon(
                        Icons.hourglass_bottom_rounded,
                        size: 48,
                        color: Color(0xFFE65100),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Booking Currently Locked',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isFirstTimeDonor
                          ? 'Your health screening parameters require a temporary deferral before appointment booking can be unlocked.'
                          : 'You are currently in your recovery observation period ($daysRemaining days remaining). Appointments will unlock once your clearance date is reached.',
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
                        onPressed: onRefreshScreening,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text(
                          'Update & Retake Screening',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7D1B22),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            isEligible: false,
            donorBloodType: '',
          ),
        ],
      ),
    );
  }
}