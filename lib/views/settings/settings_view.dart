import 'package:flutter/material.dart';
import 'package:resq/model/screening_input_model.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/utils/constants/theme_constants.dart';
import 'package:resq/views/auth/registration_wiz_view.dart';

class SettingsView extends StatefulWidget {
  final ScreenNPTModel? screeningModel;
  final String donorName;
  final String bloodType;
  final String donorId;
  final Function(ScreenNPTModel updatedModel, ClassificationResult result)? onRetakeCompleted;

  const SettingsView({
    super.key,
    this.screeningModel,
    this.donorName = '',
    this.bloodType = '',
    this.donorId = '',
    this.onRetakeCompleted,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // Notification Toggles
  bool _enableCodeRedAlerts = true;
  bool _enableAppointmentReminders = true;
  bool _enableHealthTips = false;

  // Security Toggles
  bool _enableBiometrics = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ResQTheme.bgOffWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: ResQTheme.textDark, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: ResQTheme.heading2.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: ResQTheme.textDark,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SECTION 1: Notifications & Emergency Alerts
              _buildSectionHeader('Notifications & Alerts'),
              const SizedBox(height: 8),
              _buildSettingsCard([
                _buildSwitchTile(
                  icon: Icons.emergency_rounded,
                  iconColor: ResQTheme.primaryCrimson,
                  title: 'Code Red Emergency Alerts',
                  subtitle: 'Receive instant notifications for critical blood needs near you',
                  value: _enableCodeRedAlerts,
                  onChanged: (val) => setState(() => _enableCodeRedAlerts = val),
                ),
                const Divider(height: 1),
                _buildSwitchTile(
                  icon: Icons.calendar_month_rounded,
                  iconColor: Colors.blueAccent,
                  title: 'Appointment Reminders',
                  subtitle: 'Upcoming donation schedule notifications',
                  value: _enableAppointmentReminders,
                  onChanged: (val) => setState(() => _enableAppointmentReminders = val),
                ),
                const Divider(height: 1),
                _buildSwitchTile(
                  icon: Icons.lightbulb_outline_rounded,
                  iconColor: Colors.amber.shade700,
                  title: 'Health & Nutrition Tips',
                  subtitle: 'Iron restoration and dietary advice during recovery',
                  value: _enableHealthTips,
                  onChanged: (val) => setState(() => _enableHealthTips = val),
                ),
              ]),

              const SizedBox(height: 24),

              // SECTION 2: Account & Security (Retake Screening linked here)
              _buildSectionHeader('Account & Security'),
              const SizedBox(height: 8),
              _buildSettingsCard([
                _buildSwitchTile(
                  icon: Icons.fingerprint_rounded,
                  iconColor: Colors.purple,
                  title: 'Biometric Login',
                  subtitle: 'Use Face ID / Fingerprint to access digital QR pass',
                  value: _enableBiometrics,
                  onChanged: (val) => setState(() => _enableBiometrics = val),
                ),
                const Divider(height: 1),
                _buildNavigationTile(
                  icon: Icons.lock_outline_rounded,
                  iconColor: ResQTheme.textDark,
                  title: 'Change Password',
                  subtitle: 'Update your account security credentials',
                  onTap: () {},
                ),
                const Divider(height: 1),
                _buildNavigationTile(
                  icon: Icons.refresh_rounded,
                  iconColor: ResQTheme.primaryCrimson,
                  title: 'Retake Health Assessment',
                  subtitle: 'Re-evaluate clinical donor parameters',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => RegistrationWizView(
                          isRetake: true,
                          initialScreening: widget.screeningModel,
                          donorName: widget.donorName,
                          bloodType: widget.bloodType,
                          donorId: widget.donorId,
                          onRetakeCompleted: (updatedModel, result) {
                            if (widget.onRetakeCompleted != null) {
                              widget.onRetakeCompleted!(updatedModel, result);
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result.isEligible
                                      ? 'Assessment updated: You are now verified eligible!'
                                      : 'Assessment updated: Deferred (${result.status.name})',
                                ),
                                backgroundColor: result.isEligible ? Colors.green : Colors.orange,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ]),

              const SizedBox(height: 24),

              // SECTION 3: Guidelines & Legal
              _buildSectionHeader('Guidelines & Legal'),
              const SizedBox(height: 8),
              _buildSettingsCard([
                _buildNavigationTile(
                  icon: Icons.health_and_safety_outlined,
                  iconColor: Colors.teal,
                  title: 'NVBSP & DOH Guidelines',
                  subtitle: 'Philippine blood donation regulations',
                  onTap: () {},
                ),
                const Divider(height: 1),
                _buildNavigationTile(
                  icon: Icons.privacy_tip_outlined,
                  iconColor: Colors.blueGrey,
                  title: 'Privacy Policy',
                  subtitle: 'Data handling and donor medical privacy',
                  onTap: () {},
                ),
                const Divider(height: 1),
                _buildNavigationTile(
                  icon: Icons.description_outlined,
                  iconColor: Colors.blueGrey,
                  title: 'Terms of Service',
                  subtitle: 'ResQ mobile application terms',
                  onTap: () {},
                ),
              ]),

              const SizedBox(height: 24),

              // SECTION 4: Sign Out Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => _showSignOutDialog(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    foregroundColor: Colors.redAccent,
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text(
                    'SIGN OUT',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // App Version Footer
              Center(
                child: Text(
                  'ResQ Blood Donation System • v1.0.0',
                  style: TextStyle(fontSize: 11, color: ResQTheme.textMuted),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: ResQTheme.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ResQTheme.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeColor: ResQTheme.primaryCrimson,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: ResQTheme.textMuted, height: 1.25)),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: ResQTheme.textMuted, height: 1.25)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'Are you sure you want to sign out of your ResQ donor account?',
          style: TextStyle(fontSize: 13, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const RegistrationWizView()),
                    (route) => false,
              );
            },
            child: const Text('SIGN OUT'),
          ),
        ],
      ),
    );
  }
}