import 'package:flutter/material.dart';
import '../../utils/constants/theme_constants.dart';

class RegistrationWizView extends StatelessWidget {
  const RegistrationWizView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registration'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.app_registration_rounded,
              size: 100,
              color: ResQTheme.primaryCrimson,
            ),
            SizedBox(height: 20),
            Text(
              'Registration Wizard',
              style: ResQTheme.heading1,
            ),
            SizedBox(height: 10),
            Text('This is a placeholder for your registration flow.'),
          ],
        ),
      ),
    );
  }
}
