import 'package:flutter/material.dart';
import 'package:resq/utils/constants/theme_constants.dart';
import 'package:resq/widgets/app_notif_bell.dart';

class EligibleAppointView extends StatefulWidget {
  final bool isFirstTimeDonor;
  final VoidCallback onBookingCompleted;

  const EligibleAppointView({
    super.key,
    required this.isFirstTimeDonor,
    required this.onBookingCompleted,
  });

  @override
  State<EligibleAppointView> createState() => _EligibleAppointViewState();
}

class _EligibleAppointViewState extends State<EligibleAppointView> {
  int _selectedCenterIndex = 0;
  int _selectedSlotIndex = 0;

  final List<Map<String, String>> _centers = [
    {
      'name': 'Philippine Red Cross - Quezon Chapter',
      'address': 'Quezon Ave, Lucena City',
      'distance': '1.2 km',
    },
    {
      'name': 'Quezon Medical Center (QMC) Blood Bank',
      'address': 'Lucena City, Quezon',
      'distance': '2.8 km',
    },
    {
      'name': 'St. Anne General Hospital',
      'address': 'Gulang-Gulang, Lucena City',
      'distance': '3.5 km',
    },
  ];

  final List<String> _slots = [
    '08:30 AM - 09:30 AM',
    '10:00 AM - 11:00 AM',
    '01:30 PM - 02:30 PM',
    '03:00 PM - 04:00 PM',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBEBEB),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppointmentHeaderWithBack(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Blood Donation Center',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(_centers.length, (index) {
                      final center = _centers[index];
                      final isSelected = _selectedCenterIndex == index;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: InkWell(
                          onTap: () => setState(() => _selectedCenterIndex = index),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF7D1B22) : const Color(0xFFE5E7EB),
                                width: isSelected ? 1.8 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  color: isSelected ? const Color(0xFF7D1B22) : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        center['name']!,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${center['address']} • ${center['distance']}',
                                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    const Text(
                      'Select Preferred Time Slot',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_slots.length, (index) {
                        final isSelected = _selectedSlotIndex == index;
                        return ChoiceChip(
                          label: Text(_slots[index]),
                          selected: isSelected,
                          selectedColor: const Color(0xFF7D1B22),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF1E1E1E),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          onSelected: (val) => setState(() => _selectedSlotIndex = index),
                        );
                      }),
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: widget.onBookingCompleted,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7D1B22),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'CONFIRM APPOINTMENT SLOT',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentHeaderWithBack(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 14, bottom: 14, left: 8, right: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF7D1B22),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              Image.asset(
                'assets/images/rq_logo_white.png',
                height: 28,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text(
                  'RQ',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Container(width: 1.5, height: 20, color: Colors.white60),
              const SizedBox(width: 10),
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
}