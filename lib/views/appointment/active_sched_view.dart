import 'package:flutter/material.dart';
import 'package:resq/utils/constants/theme_constants.dart';

class ConfirmedAppointmentData {
  final String facility;
  final DateTime date;
  final String timeSlot;
  final String queueNumber;

  ConfirmedAppointmentData({
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ResQTheme.bgOffWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Donation Schedule',
                style: ResQTheme.heading1.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('Your upcoming confirmed donation appointment', style: TextStyle(fontSize: 12.5, color: ResQTheme.textMuted)),
              const SizedBox(height: 20),

              // Confirmed Schedule Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
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
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'CONFIRMED APPOINTMENT',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Text(
                          appointment.queueNumber,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: ResQTheme.primaryCrimson,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Icon(Icons.local_hospital_rounded, color: ResQTheme.primaryCrimson, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            appointment.facility,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month, color: Colors.grey, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${appointment.date.month}/${appointment.date.day}/${appointment.date.year}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.access_time_rounded, color: Colors.grey, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          appointment.timeSlot,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline, color: Colors.grey, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Please arrive 10 minutes prior to your slot and bring a valid government ID.',
                              style: TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Cancel / Reschedule CTA
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: onCancelAppointment,
                  icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 18),
                  label: const Text(
                    'Cancel Appointment',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
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