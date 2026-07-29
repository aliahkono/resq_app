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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.app_registration_rounded,
              size: 100,
              color: ResQTheme.primaryCrimson,
            ),
            const SizedBox(height: 20),
            Text(
              'Registration Wizard',
              style: ResQTheme.heading1,
            ),
            const SizedBox(height: 10),
            const Text('This is a placeholder for your registration flow.'),
          ],
        ),
      ),
    );
  }
}
