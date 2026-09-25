import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:resq/model/screening_input_model.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/views/auth/auth_landing_view.dart';
import 'package:resq/views/auth/registration_wiz_view.dart';
import 'package:resq/services/api_service.dart';
import 'package:resq/services/session_storage.dart';
import 'package:resq/services/local_prefs.dart';
import 'package:resq/services/push_service.dart';
import 'package:resq/views/settings/delete_acc_otp_view.dart';
import 'package:resq/widgets/resq_ui.dart';

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
            Icon(Icons.logout_rounded, color: Color(0xFF9B1B20), size: 20),
            SizedBox(width: 8),
            Text(
              'Sign Out',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9B1B20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _radiusKm(String option) => int.tryParse(option.split(' ').first) ?? 15;

  void _showRadiusPicker(BuildContext context) {
    String pending = _selectedRadius;

    showResQSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final int index = _radiusOptions.indexOf(pending).clamp(0, _radiusOptions.length - 1);
          final int km = _radiusKm(pending);
          final int maxKm = _radiusKm(_radiusOptions.last);

          return ResQSheet(
            icon: Icons.radar_rounded,
            title: 'Urgent Alert Radius',
            subtitle: 'How far away can hospitals alert you?',
            footer: RQButton(
              label: 'Save radius',
              onPressed: () {
                setState(() => _selectedRadius = pending);
                LocalPrefs.setString(widget.donorId, 'alertRadius', pending);
                Navigator.pop(ctx);
              },
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Radius preview: rings for each option, the chosen one filled.
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    height: 190,
                    width: double.infinity,
                    color: const Color(0xFFECEAE4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: km.toDouble()),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      builder: (context, value, _) => CustomPaint(
                        painter: _RadiusPainter(
                          selectedKm: value,
                          maxKm: maxKm.toDouble(),
                          ringsKm: _radiusOptions.map(_radiusKm).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$km',
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: RQColors.ink),
                      ),
                      const TextSpan(
                        text: ' km radius',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: RQColors.muted),
                      ),
                    ],
                  ),
                ),
                Text('You\'ll get urgent alerts from hospitals within $km km of you.',
                    style: const TextStyle(fontSize: 12.5, color: RQColors.muted)),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(ctx).copyWith(
                    activeTrackColor: RQColors.blood,
                    inactiveTrackColor: RQColors.hairline,
                    thumbColor: RQColors.blood,
                    overlayColor: RQColors.blood.withValues(alpha: 0.12),
                    trackHeight: 6,
                    showValueIndicator: ShowValueIndicator.never,
                  ),
                  child: Slider(
                    value: index.toDouble(),
                    min: 0,
                    max: (_radiusOptions.length - 1).toDouble(),
                    divisions: _radiusOptions.length - 1,
                    semanticFormatterCallback: (v) => _radiusOptions[v.round()],
                    onChanged: (v) => setModalState(() => pending = _radiusOptions[v.round()]),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    for (int i = 0; i < _radiusOptions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: _radiusOptions[i] == pending
                              ? ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: RQColors.blood,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    minimumSize: Size.zero,
                                    padding: EdgeInsets.zero,
                                    shape: const StadiumBorder(),
                                  ),
                                  child: Text(_radiusOptions[i],
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                )
                              : OutlinedButton(
                                  onPressed: () => setModalState(() => pending = _radiusOptions[i]),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: RQColors.ink,
                                    side: const BorderSide(color: RQColors.hairline, width: 1.5),
                                    minimumSize: Size.zero,
                                    padding: EdgeInsets.zero,
                                    shape: const StadiumBorder(),
                                  ),
                                  child: Text(_radiusOptions[i],
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: RQColors.hairline),
                  ),
                  child: Column(
                    children: [
                      RQToggleRow(
                        title: 'Use my location',
                        subtitle: 'Needed to measure distance to hospitals',
                        value: _locationServices,
                        onChanged: (val) {
                          setState(() => _locationServices = val);
                          setModalState(() {});
                          LocalPrefs.setBool(widget.donorId, 'locationServices', val);
                        },
                      ),
                      RQToggleRow(
                        title: 'Also send by SMS',
                        subtitle: "When you're offline or have no data",
                        value: _notifySms,
                        showDivider: false,
                        onChanged: _loadingPrefs
                            ? null
                            : (val) async {
                                setModalState(() {});
                                await _updateNotifyPref(sms: val);
                                if (ctx.mounted) setModalState(() {});
                              },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String get _initials {
    final parts = _name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  void _showEditPersonalDetailsModal(BuildContext context) {
    final nameCtrl = TextEditingController(text: _name);
    final phoneCtrl = TextEditingController(text: _phone);
    final emailCtrl = TextEditingController(text: _email);
    bool saving = false;
    String? error;

    Future<void> save(BuildContext ctx, StateSetter setModalState) async {
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
      if (newName.isEmpty) {
        setModalState(() => error = 'Please enter your full name.');
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
          const SnackBar(content: Text('Personal details saved.'), backgroundColor: RQColors.success),
        );
      } on ApiException catch (e) {
        if (!ctx.mounted) return;
        setModalState(() {
          saving = false;
          error = e.message;
        });
      } catch (_) {
        if (!ctx.mounted) return;
        setModalState(() {
          saving = false;
          error = 'Could not reach the ResQ server.';
        });
      }
    }

    showResQSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => ResQSheet(
          title: 'Edit personal details',
          subtitle: 'So hospitals can reach you quickly',
          footer: Row(
            children: [
              Expanded(
                child: RQButton.secondary(label: 'Cancel', onPressed: saving ? null : () => Navigator.pop(ctx)),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: RQButton(
                  label: 'Save changes',
                  loading: saving,
                  onPressed: () => save(ctx, setModalState),
                ),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(color: RQColors.bloodTint, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(_initials,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: RQColors.bloodText)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_name.isNotEmpty ? _name : 'Your name',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: RQColors.ink)),
                        if (widget.donorId.isNotEmpty)
                          Text('Donor ID ${widget.donorId}',
                              style: const TextStyle(fontSize: 12, color: RQColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const RQSectionLabel('Basic info'),
              const SizedBox(height: 10),
              RQTextField(controller: nameCtrl, label: 'Full name', enabled: !saving),
              const SizedBox(height: 18),
              const RQSectionLabel('Contact'),
              const SizedBox(height: 10),
              RQTextField(
                controller: phoneCtrl,
                label: 'Mobile number',
                keyboardType: TextInputType.phone,
                enabled: !saving,
              ),
              const SizedBox(height: 12),
              RQTextField(
                controller: emailCtrl,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                enabled: !saving,
              ),
              if (widget.bloodType.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: RQColors.surface, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: RQColors.blood, borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: Text(widget.bloodType,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Blood type',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: RQColors.ink)),
                            Text("Can't be changed here",
                                style: TextStyle(fontSize: 12, color: RQColors.muted)),
                          ],
                        ),
                      ),
                      const Icon(Icons.lock_outline_rounded, size: 18, color: RQColors.muted),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: saving
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
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Update health screening answers',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: RQColors.navy)),
                      ),
                      Icon(Icons.chevron_right_rounded, color: RQColors.navy),
                    ],
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                _sheetError(error!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetError(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFB91C1C)),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFFB91C1C)))),
        ],
      ),
    );
  }

  void _showChangePasswordModal(BuildContext context) {
    final currentPw = TextEditingController();
    final newPw = TextEditingController();
    final confirmPw = TextEditingController();
    bool saving = false;
    String? error;
    bool obscureCurrent = true;
    bool obscureNew = true;

    Widget eye(bool obscured, VoidCallback onTap) => IconButton(
          tooltip: obscured ? 'Show password' : 'Hide password',
          icon: Icon(obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: RQColors.muted),
          onPressed: onTap,
        );

    Widget rule(bool ok, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ok ? Icons.check_rounded : Icons.circle_outlined,
                size: 15, color: ok ? RQColors.success : const Color(0xFF9CA3AF)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(text, style: TextStyle(fontSize: 12, color: ok ? RQColors.ink : RQColors.muted)),
            ),
          ],
        );

    showResQSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final pw = newPw.text;
          final bool hasLen = pw.length >= 8;
          final bool hasUpper = pw.contains(RegExp(r'[A-Z]'));
          final bool hasNum = pw.contains(RegExp(r'[0-9]'));
          final bool hasSym = pw.contains(RegExp(r'[^A-Za-z0-9]'));
          final int score = [hasLen, hasUpper, hasNum, hasSym].where((b) => b).length;
          final bool matches = confirmPw.text.isNotEmpty && confirmPw.text == pw;
          final bool canSave = hasLen && matches && !saving;

          const labels = ['Too weak', 'Weak', 'Fair', 'Good', 'Strong'];
          final Color strengthColor = score >= 3
              ? RQColors.success
              : score == 2
                  ? RQColors.warning
                  : const Color(0xFFB91C1C);

          Future<void> submit() async {
            setModalState(() {
              saving = true;
              error = null;
            });
            try {
              await ApiService.updateMyProfile(widget.token, {
                'password': newPw.text,
                'currentPassword': currentPw.text,
              });
              if (!mounted || !ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password updated.'), backgroundColor: RQColors.success),
              );
            } on ApiException catch (e) {
              if (!ctx.mounted) return;
              setModalState(() {
                saving = false;
                error = e.message;
              });
            } catch (_) {
              if (!ctx.mounted) return;
              setModalState(() {
                saving = false;
                error = 'Could not reach the ResQ server.';
              });
            }
          }

          return ResQSheet(
            icon: Icons.shield_outlined,
            title: 'Password & Security',
            subtitle: 'Keep your ResQ account safe',
            footer: RQButton(
              label: 'Update password',
              loading: saving,
              onPressed: canSave ? submit : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const RQSectionLabel('Change password'),
                const SizedBox(height: 10),
                // currentPassword is only checked server-side if the donor
                // already has a password set — an OTP-only donor setting
                // their first one here can leave it blank (see
                // updateMyProfile, donorPortal.controller.js).
                RQTextField(
                  controller: currentPw,
                  label: 'Current password',
                  obscureText: obscureCurrent,
                  enabled: !saving,
                  suffix: eye(obscureCurrent, () => setModalState(() => obscureCurrent = !obscureCurrent)),
                ),
                const SizedBox(height: 12),
                RQTextField(
                  controller: newPw,
                  label: 'New password',
                  obscureText: obscureNew,
                  enabled: !saving,
                  onChanged: (_) => setModalState(() {}),
                  suffix: eye(obscureNew, () => setModalState(() => obscureNew = !obscureNew)),
                ),
                if (pw.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (int i = 0; i < 4; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            height: 5,
                            decoration: BoxDecoration(
                              color: i < score ? strengthColor : RQColors.hairline,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 10),
                      Text(labels[score],
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: strengthColor)),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: rule(hasLen, '8+ characters')),
                    Expanded(child: rule(hasUpper, 'Uppercase letter')),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: rule(hasNum, 'A number')),
                    Expanded(child: rule(hasSym, 'A symbol (!@#)')),
                  ],
                ),
                const SizedBox(height: 12),
                RQTextField(
                  controller: confirmPw,
                  label: 'Confirm new password',
                  obscureText: obscureNew,
                  enabled: !saving,
                  onChanged: (_) => setModalState(() {}),
                  suffix: confirmPw.text.isEmpty
                      ? null
                      : Icon(
                          matches ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                          color: matches ? RQColors.success : const Color(0xFFB91C1C),
                        ),
                ),
                if (confirmPw.text.isNotEmpty && !matches) ...[
                  const SizedBox(height: 6),
                  const Text("Passwords don't match",
                      style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  _sheetError(error!),
                ],
                const SizedBox(height: 22),
                const RQSectionLabel('Sign-in security'),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: RQColors.hairline),
                  ),
                  child: RQToggleRow(
                    title: 'Fingerprint / Face unlock',
                    subtitle: 'Open ResQ without typing your password',
                    value: _biometricLogin,
                    showDivider: false,
                    onChanged: (val) {
                      setState(() => _biometricLogin = val);
                      setModalState(() {});
                      SessionStorage.setBiometricEnabled(val);
                    },
                  ),
                ),
              ],
            ),
          );
        },
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
                    // Best-effort too — a device that fails to unregister
                    // just means it keeps getting pushes for the account it
                    // already signed out of locally, not a blocker to
                    // finishing sign-out.
                    try {
                      await PushService.instance.unregisterDevice(widget.token);
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

/// Preview for the alert-radius sheet: faint rings for every option and the
/// chosen radius filled, with "you" in the middle. Uses a square-root scale
/// so the 5 km ring is still visible next to the 50 km one.
class _RadiusPainter extends CustomPainter {
  final double selectedKm;
  final double maxKm;
  final List<int> ringsKm;

  _RadiusPainter({required this.selectedKm, required this.maxKm, required this.ringsKm});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double maxR = size.height / 2 - 12;
    double radiusFor(double km) => maxR * math.sqrt((km / maxKm).clamp(0.0, 1.0));

    // A couple of plain "roads" so it reads as a map.
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 6;
    canvas.drawLine(Offset(0, size.height * 0.35), Offset(size.width, size.height * 0.45), road);
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.38, size.height), road..strokeWidth = 4);
    canvas.drawLine(Offset(size.width * 0.78, 0), Offset(size.width * 0.7, size.height), road..strokeWidth = 3);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x33000000);
    for (final km in ringsKm) {
      canvas.drawCircle(center, radiusFor(km.toDouble()), ring);
    }

    final r = radiusFor(selectedKm);
    canvas.drawCircle(center, r, Paint()..color = RQColors.blood.withValues(alpha: 0.14));
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = RQColors.blood,
    );

    canvas.drawCircle(center, 13, Paint()..color = RQColors.navy.withValues(alpha: 0.2));
    canvas.drawCircle(center, 9, Paint()..color = Colors.white);
    canvas.drawCircle(center, 6, Paint()..color = RQColors.navy);
  }

  @override
  bool shouldRepaint(_RadiusPainter old) => old.selectedKm != selectedKm || old.maxKm != maxKm;
}