import 'package:flutter/material.dart';
import 'package:resq/utils/constants/theme_constants.dart';

class ConfirmedAppointmentData {
  // Real appointments.id from the backend — needed so Cancel can call
  // PATCH /api/donor/appointments/:id/cancel for the right row. Every
  // source of ConfirmedAppointmentData (booking flow, Priority Request Feed
  // accept, notification bell accept) now goes through a real
  // POST /api/donor/appointments call first, so this is always populated.
  final String id;
  final String facility;
  final DateTime date;
  final String timeSlot;
  final String queueNumber;

  ConfirmedAppointmentData({
    required this.id,
    required this.facility,
    required this.date,
    required this.timeSlot,
    required this.queueNumber,
  });
}

class ActiveSchedView extends StatelessWidget {
  final ConfirmedAppointmentData appointment;
  final VoidCallback onCancelAppointment;

  const ActiveSchedView({
    super.key,
    required this.appointment,
    required this.onCancelAppointment,
  });

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F5),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check_circle_rounded,
                      color: Color(0xFF16A34A), size: 14),
                  SizedBox(width: 6),
                  Text(
                    'APPOINTMENT CONFIRMED',
                    style: TextStyle(
                        color: Color(0xFF15803D),
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF9B1B20), width: 1.2),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Color(0xFF9B1B20),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            appointment.queueNumber,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Priority Slot',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow(Icons.local_hospital_outlined,
                            'Facility Center', appointment.facility),
                        const Divider(height: 20),
                        _buildDetailRow(Icons.calendar_month_outlined,
                            'Scheduled Date', _formatDate(appointment.date)),
                        const Divider(height: 20),
                        _buildDetailRow(Icons.access_time_rounded,
                            'Time Window', appointment.timeSlot),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: const Text('Cancel Appointment?'),
                      content: const Text(
                          'Are you sure you want to cancel this scheduled donation slot?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Keep Slot')),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            onCancelAppointment();
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9B1B20)),
                          child: const Text('Yes, Cancel',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.cancel_outlined,
                    size: 18, color: Color(0xFF9B1B20)),
                label: const Text(
                  'Cancel This Appointment',
                  style: TextStyle(
                      color: Color(0xFF9B1B20),
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF9B1B20), width: 1.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF9B1B20), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280))),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E))),
            ],
          ),
        ),
      ],
    );
  }
}