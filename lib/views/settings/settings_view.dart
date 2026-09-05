import 'package:flutter/material.dart';
import 'package:resq/model/screening_input_model.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/views/auth/auth_landing_view.dart';
import 'package:resq/views/auth/registration_wiz_view.dart';
import 'package:resq/services/api_service.dart';
import 'package:resq/services/session_storage.dart';
import 'package:resq/services/local_prefs.dart';
import 'package:resq/views/settings/delete_acc_otp_view.dart';

class SettingsView extends StatefulWidget {
  final ScreenNPTModel? screeningModel;
  final String donorName;
  final String bloodType;
  final String donorId;
  final Function(ScreenNPTModel updatedModel, ClassificationResult result)? onRetakeCompleted;
  final void Function({required String name, required String phone, required String email})?
      onProfileDetailsUpdated;
  final String? userName;
  final String? userPhone;
  final String? userEmail;
  // Session token (see HomeView.token) — required for every real call this
  // screen makes (GET/PATCH /api/donor/me, POST /donor-auth/logout).
  final String token;

  const SettingsView({
    super.key,
    this.screeningModel,
    this.donorName = '',
    this.bloodType = '',
    this.donorId = '',
    this.onRetakeCompleted,
    this.onProfileDetailsUpdated,
    this.userName,
    this.userPhone,
    this.userEmail,
    this.token = '',
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // Account & Security Toggles — no backend feature behind this yet (no
  // biometric/device-credential endpoint exists), so it stays local-only
  // until that's built.
  bool _biometricLogin = false;

  // Alert & Notification Preferences — real donor.notify_sms /
  // donor.notify_email columns (see donorPortal.controller.js
  // updateMyProfile), fetched fresh on open via GET /api/donor/me rather
  // than trusted from whatever HomeView happened to pass down. Seeded to
  // `true` before the fetch resolves since that's the backend's own
  // default for a new donor.
  bool _notifySms = true;
  bool _notifyEmail = true;
  bool _loadingPrefs = true;

  // The backend has no separate "appointment reminder" notification type —
  // notify_sms/notify_email only ever gate the broadcast-alert emails/SMS
  // (see notifications.service.js). This toggle has nothing to connect to
  // yet, so it's shown disabled rather than pretending to work.
  static const bool _appointmentRemindersImplemented = false;

  // Editable profile fields — start from whatever HomeView passed down (so
  // the screen isn't blank on first paint), then get overwritten by the
  // GET /api/donor/me fetch below once it resolves, since that's the real
  // source of truth.
  late String _name;
  late String _phone;
  late String _email;

  // Location & Emergency Radius — no geofencing feature on the backend
  // (hospitals aren't matched to donors by a radius anywhere server-side),
  // local-only for the same reason as biometric login above.
  bool _locationServices = false;
  String _selectedRadius = '15 km';

  final List<String> _radiusOptions = ['5 km', '10 km', '15 km', '25 km', '50 km'];

  @override
  void initState() {
    super.initState();
    _name = widget.userName ?? (widget.donorName.isNotEmpty ? widget.donorName : '');
    _phone = widget.userPhone ?? '';
    _email = widget.userEmail ?? '';
    _loadProfile();
    _loadLocalPrefs();
  }

  /// Restores toggles that have no backend field yet from on-device storage.
  /// Location services / alert radius persist per donor across logins.
  /// Biometric login is intentionally session-scoped, not donor-scoped (see
  /// SessionStorage.isBiometricEnabled) — off by default on every fresh
  /// login, has to be explicitly re-enabled, rather than silently carrying
  /// over from whoever last used this device.
  Future<void> _loadLocalPrefs() async {
    final biometric = await SessionStorage.isBiometricEnabled();
    if (widget.donorId.isEmpty) {
      if (!mounted) return;
      setState(() => _biometricLogin = biometric);
      return;
    }
    final location = await LocalPrefs.getBool(widget.donorId, 'locationServices');
    final radius = await LocalPrefs.getString(widget.donorId, 'alertRadius');
    if (!mounted) return;
    setState(() {
      _biometricLogin = biometric;
      if (location != null) _locationServices = location;
      if (radius != null) _selectedRadius = radius;
    });
  }

  /// GET /api/donor/me — refreshes name/phone/email and the two real
  /// notification toggles from the backend. Silent on failure (keeps
  /// whatever was passed down from HomeView) since this runs automatically
  /// on open, not in response to a donor action — a network hiccup here
  /// shouldn't block the whole Settings screen with an error banner.
  Future<void> _loadProfile() async {
    if (widget.token.isEmpty) {
      setState(() => _loadingPrefs = false);
      return;
    }
    try {
      final profile = await ApiService.getMyProfile(widget.token);
      if (!mounted) return;
      setState(() {
        _name = (profile['name'] as String?) ?? _name;
        _phone = (profile['phone'] as String?) ?? _phone;
        _email = (profile['email'] as String?) ?? _email;
        _notifySms = (profile['notifySms'] as bool?) ?? _notifySms;
        _notifyEmail = (profile['notifyEmail'] as bool?) ?? _notifyEmail;
        _loadingPrefs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPrefs = false);
    }
  }

  /// PATCH /api/donor/me — optimistically flips the switch, then confirms
  /// against the backend; reverts and shows the real error message if the
  /// save fails, rather than leaving the UI showing a preference that never
  /// actually took effect.
  Future<void> _updateNotifyPref({bool? sms, bool? email}) async {
    final prevSms = _notifySms;
    final prevEmail = _notifyEmail;
    setState(() {
      if (sms != null) _notifySms = sms;
      if (email != null) _notifyEmail = email;
    });
    try {
      await ApiService.updateMyProfile(widget.token, {
        if (sms != null) 'notifySms': sms,
        if (email != null) 'notifyEmail': email,
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _notifySms = prevSms;
        _notifyEmail = prevEmail;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade700),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notifySms = prevSms;
        _notifyEmail = prevEmail;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Could not reach the ResQ server.'), backgroundColor: Colors.red.shade700),
      );
    }
  }

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
                        onChanged: (val) {
                          setState(() => _biometricLogin = val);
                          SessionStorage.setBiometricEnabled(val);
                        },
                      ),
                      const Divider(height: 1, color: Color(0xFFF0F0F2)),
                      _buildNavigationTile(
                        title: 'Delete Account',
                        titleColor: const Color(0xFFB91C1C),
                        onTap: () => _startDeleteAccountFlow(context),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // SECTION 2: ALERT & NOTIFICATION PREFERENCES
                    _buildSectionTitle('ALERT & NOTIFICATION PREFERENCES'),
                    const SizedBox(height: 8),
                    _buildCardGroup([
                      _buildSwitchTile(
                        title: 'SMS Alerts (Urgent Hospital Broadcasts)',
                        value: _notifySms,
                        enabled: !_loadingPrefs,
                        onChanged: (val) => _updateNotifyPref(sms: val),
                      ),
                      const Divider(height: 1, color: Color(0xFFF0F0F2)),
                      _buildSwitchTile(
                        title: 'Email Alerts (Broadcast Notifications)',
                        value: _notifyEmail,
                        enabled: !_loadingPrefs,
                        onChanged: (val) => _updateNotifyPref(email: val),
                      ),
                      const Divider(height: 1, color: Color(0xFFF0F0F2)),
                      _buildSwitchTile(
                        title: 'Appointment Reminders & Tips',
                        subtitle: 'Coming soon',
                        value: false,
                        enabled: _appointmentRemindersImplemented,
                        onChanged: (val) {},
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
                        onChanged: (val) {
                          setState(() => _locationServices = val);
                          LocalPrefs.setBool(widget.donorId, 'locationServices', val);
                        },
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
        color: Color(0xFF9B1B20),
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
    Color? titleColor,
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
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: titleColor ?? const Color(0xFF1E2432),
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: titleColor ?? const Color(0xFF4B5563)),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: enabled ? const Color(0xFF1E2432) : const Color(0xFF9CA3AF),
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF)),
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF9B1B20),
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
                          color: Color(0xFF9B1B20),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF9B1B20)),
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF9B1B20)),
            ),
            const SizedBox(height: 12),
            ...List.generate(_radiusOptions.length, (index) {
              final option = _radiusOptions[index];
              return ListTile(
                title: Text(option, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: _selectedRadius == option
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF9B1B20))
                    : null,
                onTap: () {
                  setState(() => _selectedRadius = option);
                  LocalPrefs.setString(widget.donorId, 'alertRadius', option);
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
    final nameCtrl = TextEditingController(text: _name);
    final phoneCtrl = TextEditingController(text: _phone);
    final emailCtrl = TextEditingController(text: _email);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        bool saving = false;
        String? error;
        return StatefulBuilder(
          builder: (ctx, setModalState) => Padding(
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
                  const Text('Personal Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF9B1B20))),
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
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: saving
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => RegistrationWizView(
                                        isRetake: true,
                                        initialScreening: widget.screeningModel,
                                        donorName: widget.donorName,
                                        bloodType: widget.bloodType,
                                        donorId: widget.donorId,
                                        token: widget.token,
                                        onRetakeCompleted: widget.onRetakeCompleted,
                                      ),
                                    ),
                                  );
                                },
                          child: const Text('RETAKE SCREENING', style: TextStyle(color: Color(0xFF9B1B20), fontSize: 11.5)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  final newName = nameCtrl.text.trim();
                                  final newPhone = phoneCtrl.text.trim();
                                  final newEmail = emailCtrl.text.trim();
                                  final updates = <String, dynamic>{};
                                  if (newName != _name) updates['name'] = newName;
                                  if (newPhone != _phone) updates['phone'] = newPhone;
                                  if (newEmail != _email) updates['email'] = newEmail;

                                  if (updates.isEmpty) {
                                    Navigator.pop(ctx);
                                    return;
                                  }

                                  setModalState(() {
                                    saving = true;
                                    error = null;
                                  });

                                  try {
                                    final updated = await ApiService.updateMyProfile(widget.token, updates);
                                    if (!mounted) return;
                                    setState(() {
                                      _name = (updated['name'] as String?) ?? newName;
                                      _phone = (updated['phone'] as String?) ?? newPhone;
                                      _email = (updated['email'] as String?) ?? newEmail;
                                    });
                                    widget.onProfileDetailsUpdated?.call(name: _name, phone: _phone, email: _email);
                                    if (!ctx.mounted) return;
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Personal profile details saved successfully!'), backgroundColor: Color(0xFF2E7D32)),
                                    );
                                  } on ApiException catch (e) {
                                    setModalState(() {
                                      saving = false;
                                      error = e.message;
                                    });
                                  } catch (_) {
                                    setModalState(() {
                                      saving = false;
                                      error = 'Could not reach the ResQ server.';
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9B1B20)),
                          child: saving
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('SAVE CHANGES', style: TextStyle(color: Colors.white, fontSize: 11.5)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
  }

  void _showChangePasswordModal(BuildContext context) {
    final currentPw = TextEditingController();
    final newPw = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        bool saving = false;
        String? error;
        bool obscureCurrent = true;
        bool obscureNew = true;
        return StatefulBuilder(
          builder: (ctx, setModalState) => Padding(
            padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Change Password & Security', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF9B1B20))),
                const SizedBox(height: 14),
                // currentPassword is only checked server-side if the donor
                // already has a password set — an OTP-only donor setting
                // their first one here can leave it blank (see
                // updateMyProfile, donorPortal.controller.js).
                TextField(
                  controller: currentPw,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setModalState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newPw,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password (min. 8 characters)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setModalState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (newPw.text.length < 8) {
                              setModalState(() => error = 'New password must be at least 8 characters.');
                              return;
                            }
                            setModalState(() {
                              saving = true;
                              error = null;
                            });
                            try {
                              await ApiService.updateMyProfile(widget.token, {
                                'password': newPw.text,
                                'currentPassword': currentPw.text,
                              });
                              if (!mounted) return;
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Account security credentials updated!'), backgroundColor: Color(0xFF2E7D32)),
                              );
                            } on ApiException catch (e) {
                              setModalState(() {
                                saving = false;
                                error = e.message;
                              });
                            } catch (_) {
                              setModalState(() {
                                saving = false;
                                error = 'Could not reach the ResQ server.';
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9B1B20)),
                    child: saving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('UPDATE PASSWORD', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
            const Text('Medical Data Privacy & Encryption', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF9B1B20))),
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9B1B20)),
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
            const Text('Terms of Service & Health Guidelines', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF9B1B20))),
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9B1B20)),
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
            const Text('ResQ Donor Support & Help', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF9B1B20))),
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9B1B20)),
                child: const Text('GOT IT', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Delete Account Flow: confirm -> send OTP -> DeleteAccountOtpView ---
  // (see delete_account_otp_view.dart for the OTP verification + the
  // separate "are you sure" confirmation that happens after it).
  Future<void> _startDeleteAccountFlow(BuildContext context) async {
    if (_phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No registered mobile number on file. Please add one under Edit Personal Details first.'),
        ),
      );
      return;
    }

    try {
      await ApiService.requestOtp(_phone);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send verification code: ${e.message}')),
      );
      return;
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reach the ResQ server. Please try again.')),
      );
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DeleteAccountOtpView(phone: _phone, token: widget.token),
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
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF9B1B20),
                    side: const BorderSide(color: Color(0xFF9B1B20), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9B1B20),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    Navigator.pop(context);
                    // Best-effort: invalidate the session server-side (POST
                    // /donor-auth/logout deletes the Redis session row). If this
                    // fails — no connection, token already expired — sign the
                    // donor out locally anyway; there's nothing else useful to do
                    // with a stale/unreachable token.
                    try {
                      await ApiService.logout(widget.token);
                    } catch (_) {}
                    await SessionStorage.clearToken();
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const AuthLandingView()),
                          (route) => false,
                    );
                  },
                  child: const Text('SIGN OUT', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}