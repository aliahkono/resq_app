import 'package:flutter/material.dart';
import 'package:resq/model/screening_input_model.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/views/auth/auth_landing_view.dart';
import 'package:resq/views/auth/registration_wiz_view.dart';

class SettingsView extends StatefulWidget {
  final ScreenNPTModel? screeningModel;
  final String donorName;
  final String bloodType;
  final String donorId;
  final Function(ScreenNPTModel updatedModel, ClassificationResult result)? onRetakeCompleted;
  final String? userName;
  final String? userPhone;
  final String? userEmail;

  const SettingsView({
    super.key,
    this.screeningModel,
    this.donorName = '',
    this.bloodType = '',
    this.donorId = '',
    this.onRetakeCompleted,
    this.userName,
    this.userPhone,
    this.userEmail,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // Account & Security Toggles
  bool _biometricLogin = false;

  // Alert & Notification Preferences Toggles
  bool _emergencyShortageAlerts = false;
  bool _smsAlerts = false;
  bool _appointmentReminders = false;

  // Location & Emergency Radius
  bool _locationServices = false;
  String _selectedRadius = '15 km';

  final List<String> _radiusOptions = ['5 km', '10 km', '15 km', '25 km', '50 km'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBEBEB),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SECTION 1: ACCOUNT & SECURITY
                    _buildSectionTitle('ACCOUNT & SECURITY'),
                    const SizedBox(height: 8),
                    _buildCardGroup([
                      _buildNavigationTile(
                        title: 'Edit Personal Details (Name, Phone, Email)',
                        onTap: () => _showEditPersonalDetailsModal(context),
                      ),
                      const Divider(height: 1, color: Color(0xFFF0F0F2)),
                      _buildNavigationTile(
                        title: 'Change Password & Security',
                        onTap: () => _showChangePasswordModal(context),
                      ),
                      const Divider(height: 1, color: Color(0xFFF0F0F2)),
                      _buildSwitchTile(
                        title: 'Biometric Login (FaceID / Fingerprint)',
                        value: _biometricLogin,
                        onChanged: (val) => setState(() => _biometricLogin = val),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // SECTION 2: ALERT & NOTIFICATION PREFERENCES
                    _buildSectionTitle('ALERT & NOTIFICATION PREFERENCES'),
                    const SizedBox(height: 8),
                    _buildCardGroup([
                      _buildSwitchTile(
                        title: 'Emergency Blood Shortage Alerts',
                        value: _emergencyShortageAlerts,
                        onChanged: (val) => setState(() => _emergencyShortageAlerts = val),
                      ),
                      const Divider(height: 1, color: Color(0xFFF0F0F2)),
                      _buildSwitchTile(
                        title: 'SMS Alerts (Urgent Hospital Broadcasts)',
                        value: _smsAlerts,
                        onChanged: (val) => setState(() => _smsAlerts = val),
                      ),
                      const Divider(height: 1, color: Color(0xFFF0F0F2)),
                      _buildSwitchTile(
                        title: 'Appointment Reminders & Tips',
                        value: _appointmentReminders,
                        onChanged: (val) => setState(() => _appointmentReminders = val),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // SECTION 3: LOCATION & EMERGENCY RADIUS
                    _buildSectionTitle('LOCATION & EMERGENCY RADIUS'),
                    const SizedBox(height: 8),
                    _buildCardGroup([
                      _buildSwitchTile(
                        title: 'Location Services Access',
                        value: _locationServices,
                        onChanged: (val) => setState(() => _locationServices = val),
                      ),
                      const Divider(height: 1, color: Color(0xFFF0F0F2)),
                      _buildRadiusSelectorTile(context),
                    ]),

                    const SizedBox(height: 20),

                    // SECTION 4: PRIVACY & SYSTEM
                    _buildSectionTitle('PRIVACY & SYSTEM'),
                    const SizedBox(height: 8),
                    _buildCardGroup([
                      _buildNavigationTile(
                        title: 'Medical Data Privacy & Encryption',
                        onTap: () => _showPrivacyModal(context),
                      ),
                      const Divider(height: 1, color: Color(0xFFF0F0F2)),
                      _buildNavigationTile(
                        title: 'Terms of Service & Health Guidelines',
                        onTap: () => _showTermsModal(context),
                      ),
                      const Divider(height: 1, color: Color(0xFFF0F0F2)),
                      _buildVersionTile(),
                    ]),

                    const SizedBox(height: 24),

                    // SECTION 5: SIGN OUT BUTTON
                    _buildSignOutButton(context),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Top Navigation Header ---
  Widget _buildTopHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 10, bottom: 14, left: 8, right: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF7D1B22),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  Icon(Icons.arrow_back, color: Colors.white, size: 18),
                  SizedBox(width: 4),
                  Text(
                    'Profile',
                    style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          const Text(
            'Settings',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: Colors.white, size: 22),
            onPressed: () => _showHelpModal(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
          color: Color(0xFF5A4D4A),
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildCardGroup(List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildNavigationTile({
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 15.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E2432),
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF4B5563)),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E2432),
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF7D1B22),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFD1D5DB),
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusSelectorTile(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Urgent Alert Radius Range',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E2432),
                ),
              ),
              InkWell(
                onTap: () => _showRadiusPicker(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedRadius,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7D1B22),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF7D1B22)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '(Receive alerts for nearby hospitals within $_selectedRadius)',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionTile() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 15.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'App Version 2.4.0 (Up to date)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1E2432),
            ),
          ),
          Icon(Icons.verified_rounded, size: 16, color: Color(0xFF1D4ED8)),
        ],
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showSignOutDialog(context),
        borderRadius: BorderRadius.circular(16),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFF1E2432), size: 20),
            SizedBox(width: 8),
            Text(
              'Sign Out',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E2432),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRadiusPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Urgent Alert Radius',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF7D1B22)),
            ),
            const SizedBox(height: 12),
            ...List.generate(_radiusOptions.length, (index) {
              final option = _radiusOptions[index];
              return ListTile(
                title: Text(option, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: _selectedRadius == option
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF7D1B22))
                    : null,
                onTap: () {
                  setState(() => _selectedRadius = option);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showEditPersonalDetailsModal(BuildContext context) {
    // Dynamic initialization using passed user details
    final initialName = widget.userName ?? (widget.donorName.isNotEmpty ? widget.donorName : '');
    final initialPhone = widget.userPhone ?? '';
    final initialEmail = widget.userEmail ?? '';

    final nameCtrl = TextEditingController(text: initialName);
    final phoneCtrl = TextEditingController(text: initialPhone);
    final emailCtrl = TextEditingController(text: initialEmail);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Personal Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF7D1B22))),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile Number', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => RegistrationWizView(
                            isRetake: true,
                            initialScreening: widget.screeningModel,
                            donorName: widget.donorName,
                            bloodType: widget.bloodType,
                            donorId: widget.donorId,
                            onRetakeCompleted: widget.onRetakeCompleted,
                          ),
                        ),
                      );
                    },
                    child: const Text('RETAKE SCREENING', style: TextStyle(color: Color(0xFF7D1B22), fontSize: 11.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Personal profile details saved successfully!'), backgroundColor: Color(0xFF2E7D32)),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7D1B22)),
                    child: const Text('SAVE CHANGES', style: TextStyle(color: Colors.white, fontSize: 11.5)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordModal(BuildContext context) {
    final currentPw = TextEditingController();
    final newPw = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Change Password & Security', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF7D1B22))),
            const SizedBox(height: 14),
            TextField(controller: currentPw, obscureText: true, decoration: const InputDecoration(labelText: 'Current Password', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: newPw, obscureText: true, decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account security credentials updated!'), backgroundColor: Color(0xFF2E7D32)),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7D1B22)),
                child: const Text('UPDATE PASSWORD', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Medical Data Privacy & Encryption', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF7D1B22))),
            const SizedBox(height: 10),
            const Text(
              'All donor health evaluations, biometrics, and clinical vitals logged by hospital staff are secured using AES-256 end-to-end encryption in compliance with the Philippine Data Privacy Act of 2012 (RA 10173).',
              style: TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFF374151)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7D1B22)),
                child: const Text('CLOSE', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTermsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Terms of Service & Health Guidelines', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF7D1B22))),
            const SizedBox(height: 10),
            const Text(
              'ResQ operates under National Voluntary Blood Services Program (NVBSP) and Department of Health (DOH) clinical donor safety criteria. Voluntary donors agree to accurate disclosure of physical metrics.',
              style: TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFF374151)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7D1B22)),
                child: const Text('AGREE & CLOSE', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ResQ Donor Support & Help', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF7D1B22))),
            const SizedBox(height: 10),
            const Text(
              'Need assistance with emergency blood requests, screening retakes, or booking queue slots? Contact your local Red Cross chapter or email support@resq.ph.',
              style: TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFF374151)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7D1B22)),
                child: const Text('GOT IT', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Sign Out Dialog Linking to AuthLandingView ---
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
              backgroundColor: const Color(0xFF7D1B22),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const AuthLandingView()),
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