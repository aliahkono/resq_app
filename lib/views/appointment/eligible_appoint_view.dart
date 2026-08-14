import 'package:flutter/material.dart';
import 'package:resq/utils/constants/theme_constants.dart';

class EligibleAppointView extends StatefulWidget {
  final bool isFirstTimeDonor;
  final VoidCallback onBookingCompleted;

  const EligibleAppointView({
    super.key,
    this.isFirstTimeDonor = false,
    required this.onBookingCompleted,
  });

  @override
  State<EligibleAppointView> createState() => _EligibleAppointViewState();
}

class _EligibleAppointViewState extends State<EligibleAppointView> {
  String _selectedLocation = 'Philippine Red Cross - Quezon Chapter';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 2));
  String _selectedTimeSlot = '09:00 AM - 10:00 AM';

  final List<String> _locations = [
    'Philippine Red Cross - Quezon Chapter',
    'Lucena United Doctors Hospital',
    'MSEUF Main Campus Medical Hub',
  ];

  final List<String> _timeSlots = [
    '08:00 AM - 09:00 AM',
    '09:00 AM - 10:00 AM',
    '01:00 PM - 02:00 PM',
    '03:00 PM - 04:00 PM',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ResQTheme.bgOffWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.isFirstTimeDonor ? 'First-Time Donation Booking' : 'Schedule Appointment',
          style: ResQTheme.heading2.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Badge Info
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.isFirstTimeDonor
                            ? 'Eligible for First-Time Contribution! Secure your priority check-in slot.'
                            : 'Eligible for Regular Donation Cycle. Book your preferred slot below.',
                        style: const TextStyle(
                          color: Color(0xFF1B5E20),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Location Selection
              const Text('Select Donation Facility / Center', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedLocation,
                items: _locations.map((loc) => DropdownMenuItem(value: loc, child: Text(loc, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (val) => setState(() => _selectedLocation = val!),
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: ResQTheme.lightBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: ResQTheme.lightBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: ResQTheme.primaryCrimson, width: 1.5)),
                ),
              ),

              const SizedBox(height: 20),

              // Date Selector
              const Text('Target Donation Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ResQTheme.lightBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      const Icon(Icons.calendar_month, color: ResQTheme.primaryCrimson, size: 20),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Time Slot Selection Grid
              const Text('Select Time Slot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.8,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _timeSlots.length,
                itemBuilder: (context, index) {
                  final slot = _timeSlots[index];
                  final isSelected = slot == _selectedTimeSlot;
                  return InkWell(
                    onTap: () => setState(() => _selectedTimeSlot = slot),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? ResQTheme.primaryCrimson : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? ResQTheme.primaryCrimson : ResQTheme.lightBorder,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          slot,
                          style: TextStyle(
                            color: isSelected ? Colors.white : ResQTheme.textDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 36),

              // Confirm Booking CTA
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: widget.onBookingCompleted,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ResQTheme.primaryCrimson,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'CONFIRM APPOINTMENT SLOT',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, letterSpacing: 0.8),
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