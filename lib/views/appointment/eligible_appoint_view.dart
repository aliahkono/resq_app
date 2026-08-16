import 'package:flutter/material.dart';
import 'package:resq/widgets/app_notif_bell.dart';

class Clinic {
  final String name;
  final String address;
  final String distance;
  final double rating;

  Clinic({
    required this.name,
    required this.address,
    required this.distance,
    required this.rating,
  });
}

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
  final List<Clinic> _clinics = [
    Clinic(
      name: 'Philippine Red Cross - Quezon Chapter',
      address: 'Quezon Blvd, Quezon City, Metro Manila',
      distance: '1.2 km',
      rating: 4.8,
    ),
    Clinic(
      name: 'St. Luke\'s Medical Center - Blood Bank',
      address: '279 E Rodriguez Sr. Ave, Quezon City',
      distance: '3.5 km',
      rating: 4.9,
    ),
    Clinic(
      name: 'Lung Center of the Philippines',
      address: 'Quezon Ave, Diliman, Quezon City',
      distance: '4.1 km',
      rating: 4.7,
    ),
  ];

  String? _selectedClinic;
  String? _selectedTime;

  final List<String> _timeSlots = [
    '08:00 AM - 09:00 AM',
    '09:00 AM - 10:00 AM',
    '10:00 AM - 11:00 AM',
    '01:00 PM - 02:00 PM',
    '02:00 PM - 03:00 PM',
    '03:00 PM - 04:00 PM',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBEBEB),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.isFirstTimeDonor) _buildFirstTimeBadge(),
                    const SizedBox(height: 16),
                    const Text(
                      'Choose a Donation Center',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._clinics.map((clinic) => _buildClinicCard(clinic)),
                    const SizedBox(height: 24),
                    if (_selectedClinic != null) ...[
                      const Text(
                        'Available Time Slots',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _timeSlots.map((slot) => _buildTimeSlot(slot)).toList(),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _selectedTime != null ? widget.onBookingCompleted : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7D1B22),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Confirm Booking',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(color: Color(0xFF7D1B22)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              const Text(
                'Book Appointment',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const AppNotificationBell(isEligible: true, donorBloodType: ''),
        ],
      ),
    );
  }

  Widget _buildFirstTimeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: const Row(
        children: [
          Icon(Icons.stars_rounded, color: Color(0xFFE65100), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'First-Time Donor Priority: Slots are prioritized for your first quest!',
              style: TextStyle(color: Color(0xFFBF360C), fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicCard(Clinic clinic) {
    bool isSelected = _selectedClinic == clinic.name;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedClinic = clinic.name;
        _selectedTime = null;
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF7D1B22) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
              children: [
                Expanded(
                  child: Text(
                    clinic.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E1E1E)),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF7D1B22), size: 20),
              ],
            ),
            const SizedBox(height: 6),
            Text(clinic.address, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF7D1B22)),
                const SizedBox(width: 4),
                Text(clinic.distance, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                const SizedBox(width: 4),
                Text(clinic.rating.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlot(String slot) {
    bool isSelected = _selectedTime == slot;
    return GestureDetector(
      onTap: () => setState(() => _selectedTime = slot),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7D1B22) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF7D1B22) : const Color(0xFFD1D5DB),
          ),
        ),
        child: Text(
          slot,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF4B5563),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}