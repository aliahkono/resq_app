import 'package:flutter/material.dart';
import 'package:resq/views/home/eligible_home_view.dart' show EmergencyBloodRequest;

class NoActiveSchedView extends StatelessWidget {
  final bool isFirstTimeDonor;
  // Open hospital requests the donor can book against — the same merged
  // list the Dashboard's "Urgent requests near you" shows (GET
  // /api/donor/requests plus the hospital broadcasts sent to this donor,
  // see HomeView._rebuildActiveRequests). Empty means no hospital has an
  // open request right now, so there is nothing to book against yet.
  final List<EmergencyBloodRequest> requests;
  final void Function(String hospitalId) onBookAppointment;

  const NoActiveSchedView({
    super.key,
    required this.isFirstTimeDonor,
    this.requests = const [],
    required this.onBookAppointment,
  });

  @override
  Widget build(BuildContext context) {
    final hasRequests = requests.isNotEmpty;
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
                hasRequests ? Icons.event_available_rounded : Icons.event_busy_rounded,
                size: 48,
                color: const Color(0xFF9B1B20),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              !hasRequests
                  ? 'No request from Hospitals yet.'
                  : (isFirstTimeDonor ? 'Ready for Your 1st Session?' : 'Hospitals Need Your Help'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              !hasRequests
                  ? 'No hospital has posted a blood request yet. This screen updates automatically as soon as one goes out — check back later.'
                  : '${requests.length == 1 ? 'A hospital is' : '${requests.length} hospitals are'} requesting blood right now. Pick a request below to reserve a time slot.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            for (final request in requests) _buildRequestCard(request),
            const SizedBox(height: 8),
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

  /// One "Requested by <hospital>" card with its own booking button.
  Widget _buildRequestCard(EmergencyBloodRequest request) {
    final u = request.urgency.toLowerCase();
    final bool critical = u.contains('crit') || u.contains('emerg');
    final bool urgent = !critical && (u.contains('urg') || u.contains('high'));
    final Color tagBg = critical
        ? const Color(0xFF9B1B20)
        : urgent
            ? const Color(0xFFFFF4E5)
            : const Color(0xFFE8F5E9);
    final Color tagFg = critical
        ? Colors.white
        : urgent
            ? const Color(0xFFB45309)
            : const Color(0xFF2E7D32);
    final String tagText = critical ? 'CRITICAL' : (urgent ? 'URGENT' : 'OPEN');
    final details = [request.timeAgo].where((s) => s.trim().isNotEmpty && s != '—').join(' · ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: critical ? const Color(0xFF9B1B20) : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFF9B1B20).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(request.bloodType,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF9B1B20))),
                    Text('${request.unitsNeeded} ${request.unitsNeeded == 1 ? 'unit' : 'units'}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF9B1B20))),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: tagBg, borderRadius: BorderRadius.circular(6)),
                      child: Text(tagText,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tagFg, letterSpacing: 0.4)),
                    ),
                    const SizedBox(height: 6),
                    const Text('Requested by',
                        style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                    Text(request.hospital,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Color(0xFF1E1E1E))),
                    if (details.isNotEmpty)
                      Text(details, style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => onBookAppointment(request.hospitalId),
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: Text(
                isFirstTimeDonor ? 'Book 1st Donation Appointment' : 'Reserve a Slot',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B1B20),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
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