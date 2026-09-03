import 'package:flutter/material.dart';
import 'package:resq/views/home/eligible_home_view.dart' show EmergencyBloodRequest;

class NoActiveSchedView extends StatelessWidget {
  final bool isFirstTimeDonor;
  // The donor's only bookable appointment source: an active broadcast from
  // the Philippine Red Cross - Quezon Chapter (see COORDINATING_HOSPITAL_NAME,
  // donorPortal.controller.js — the backend already only ever returns PRC
  // requests here). Null means PRC has no open request right now, so there
  // is nothing to book against yet.
  final EmergencyBloodRequest? activeRequest;
  final void Function(String hospitalId) onBookAppointment;

  const NoActiveSchedView({
    super.key,
    required this.isFirstTimeDonor,
    required this.activeRequest,
    required this.onBookAppointment,
  });

  @override
  Widget build(BuildContext context) {
    final request = activeRequest;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F5),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFF9B1B20).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                request == null ? Icons.event_busy_rounded : Icons.event_available_rounded,
                size: 48,
                color: const Color(0xFF9B1B20),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              request == null
                  ? 'No request from Hospitals yet.'
                  : (isFirstTimeDonor ? 'Ready for Your 1st Session?' : 'A Blood Drive Is Open'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              request == null
                  ? 'The Philippine Red Cross - Quezon Chapter hasn\'t posted a blood request yet. This screen updates automatically as soon as one goes out — check back later.'
                  : 'Philippine Red Cross - Quezon Chapter is requesting ${request.bloodType} donors right now. Reserve a time slot below.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            if (request != null)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => onBookAppointment(request.hospitalId),
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: Text(
                    isFirstTimeDonor
                        ? 'Book 1st Donation Appointment'
                        : 'Schedule New Appointment',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9B1B20),
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
                  const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Color(0xFF9B1B20), size: 18),
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