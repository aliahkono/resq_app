import 'package:flutter/material.dart';
import 'package:resq/services/api_service.dart';
import 'package:resq/services/session_storage.dart';
import 'package:resq/views/auth/auth_landing_view.dart';

/// Delete-account flow, per the requested navigation:
/// Delete Account (Settings) -> OTP Verification (this screen) ->
/// Confirmation to Delete Account (a dialog on this screen) -> Deleted.
///
/// requestOtp has already been fired once by SettingsView right before
/// pushing this screen; "Resend Code" below re-fires it on demand.
class DeleteAccountOtpView extends StatefulWidget {
  final String phone;
  final String token;

  const DeleteAccountOtpView({
    super.key,
    required this.phone,
    required this.token,
  });

  @override
  State<DeleteAccountOtpView> createState() => _DeleteAccountOtpViewState();
}

class _DeleteAccountOtpViewState extends State<DeleteAccountOtpView> {
  final _codeController = TextEditingController();
  bool _resending = false;
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String get _maskedPhone {
    final p = widget.phone;
    if (p.length <= 4) return p;
    return '${p.substring(0, p.length - 4).replaceAll(RegExp(r'.'), '•')}${p.substring(p.length - 4)}';
  }

  Future<void> _resendCode() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await ApiService.requestOtp(widget.phone);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new verification code has been sent.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach the ResQ server. Please try again.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  /// Step 2 of the requested flow — an explicit, separate "are you sure"
  /// confirmation shown only after the OTP has been entered, so deletion
  /// still needs a second deliberate tap even once the code is in.
  Future<void> _confirmThenDelete() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Please enter the 6-digit code sent to your phone.');
      return;
    }
    setState(() => _error = null);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Permanently Delete Account?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFB91C1C)),
        ),
        content: const Text(
          'This cannot be undone. Your donor profile, donation history, and appointments will be permanently removed, and your name will no longer appear in Donor Management on the hospital dashboard.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                    side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _deleteAccount(code);
  }

  Future<void> _deleteAccount(String code) async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ApiService.deleteMyAccount(widget.token, otpCode: code);
      if (!mounted) return;
      await _showDeletedThenSignOut();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        // Most likely an incorrect/expired code (backend verifies it as
        // part of this same call — see ApiService.deleteMyAccount).
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = 'Could not reach the ResQ server. Please try again.';
      });
    }
  }

  /// Step 4 — "Deleted": a brief confirmation before the app clears the
  /// session and returns to the auth landing screen, since popping
  /// straight to a login screen with no acknowledgement at all can read as
  /// the action having silently failed.
  Future<void> _showDeletedThenSignOut() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 22),
            SizedBox(width: 10),
            Text('Account Deleted', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Your ResQ donor account has been permanently deleted. Thank you for the donations you made.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B1B20),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );

    await SessionStorage.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthLandingView()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF9B1B20),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: _deleting ? null : () => Navigator.pop(context),
        ),
        title: const Text('Verify to Delete Account', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFB91C1C), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'To protect your account, please confirm the 6-digit code sent to $_maskedPhone before your account can be deleted.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D), height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text('Verification Code', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '------',
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF9B1B20), width: 2),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12.5)),
              ],
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: _resending ? null : _resendCode,
                  child: Text(
                    _resending ? 'Sending...' : 'Resend Code',
                    style: const TextStyle(color: Color(0xFF9B1B20), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _deleting ? null : _confirmThenDelete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    elevation: 0,
                  ),
                  child: _deleting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Text('VERIFY & CONTINUE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}