import 'package:flutter/material.dart';

class SettingsView extends StatefulWidget {
  // Accept user details as constructor arguments
  final String userName;
  final String userPhone;
  final String userEmail;

  const SettingsView({
    Key? key,
    required this.userName,
    required this.userPhone,
    required this.userEmail,
  }) : super(key: key);

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // Declare late TextEditingController variables
  late TextEditingController nameCtrl;
  late TextEditingController phoneCtrl;
  late TextEditingController emailCtrl;

  @override
  void initState() {
    super.initState();
    // Initialize the controllers with the dynamic data from the widget parameters
    nameCtrl = TextEditingController(text: widget.userName);
    phoneCtrl = TextEditingController(text: widget.userPhone);
    emailCtrl = TextEditingController(text: widget.userEmail);
  }

  @override
  void dispose() {
    // Dispose of the controllers when the state object is removed permanently
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF7D1B22),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email Address'),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
      ),
    );
  }
}