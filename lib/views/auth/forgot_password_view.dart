import 'package:flutter/material.dart';
import 'package:resq/services/api_service.dart';

/// Forgot Password flow, opened from LoginView's "Forgot my password?":
/// Enter email/phone -> Code sent -> Enter code + new password -> Reset.
///
/// Both steps live on this one screen (a `_codeSent` switch) rather than
/// two pushed routes, so "Back" from the code step returns to editing the
/// email/phone instead of dropping the donor back on the login screen.
/// Pops with the identifier on success so LoginView can pre-fill it.
class ForgotPasswordView extends StatefulWidget {
  final String initialIdentifier;
  final bool initialIsEmail;

  const ForgotPasswordView({
    super.key,
    this.initialIdentifier = '',
    this.initialIsEmail = true,
  });

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _identifierFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  late final TextEditingController _identifierController;
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late bool _isEmailMode;
  bool _codeSent = false;
  bool _sending = false;
  bool _resetting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _destination;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isEmailMode = widget.initialIsEmail;
    _identifierController = TextEditingController(text: widget.initialIdentifier);
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String get _identifier => _identifierController.text.trim().toLowerCase();

  // Same rules as LoginView._validateIdentifier, so an identifier that
  // would be accepted at login is accepted here too.
  String? _validateIdentifier(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _isEmailMode ? 'Please enter your email' : 'Please enter your phone number';
    }
    final trimmed = value.trim();
    if (_isEmailMode) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(trimmed)) return 'Please enter a valid email address';
    } else {
      final phPhoneRegex = RegExp(r'^(09|\+639)\d{9}$');
      if (!phPhoneRegex.hasMatch(trimmed)) return 'Enter a valid PH mobile number (e.g. 09123456789)';
    }
    return null;
  }

  Future<void> _sendCode({bool isResend = false}) async {
    setState(() => _error = null);
    if (!isResend && !_identifierFormKey.currentState!.validate()) return;

    setState(() => _sending = true);
    try {
      final response = await ApiService.requestPasswordReset(_identifier);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _destination = response['destination']?.toString();
      });
      if (isResend) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new verification code has been sent.')),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach the ResQ server. Please try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _resetPassword() async {
    setState(() => _error = null);
    if (!_resetFormKey.currentState!.validate()) return;

    setState(() => _resetting = true);
    try {
      await ApiService.resetPassword(
        identifier: _identifier,
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      await _showResetSuccess();
      if (!mounted) return;
      Navigator.pop(context, _identifier);
    } on ApiException catch (e) {
      if (!mounted) return;
      // Most likely an incorrect/expired code — the backend verifies it as
      // part of this same call (see ApiService.resetPassword).
      setState(() {
        _resetting = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resetting = false;
        _error = 'Could not reach the ResQ server. Please try again.';
      });
    }
  }

  Future<void> _showResetSuccess() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 22),
            SizedBox(width: 10),
            Text('Password Reset', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Your password has been changed. Please sign in with your new password.',
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
              child: const Text('SIGN IN', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({String? hintText, Widget? prefixIcon, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      counterText: '',
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF9B1B20), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFB91C1C), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFB91C1C), width: 2),
      ),
    );
  }

  Widget _infoBanner(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_reset_rounded, color: Color(0xFF9B1B20), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D), height: 1.35)),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
    );
  }

  Widget _errorText() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12.5)),
    );
  }

  Widget _primaryButton({required String label, required bool busy, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9B1B20),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          elevation: 0,
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
      ),
    );
  }

  Widget _modeToggle() {
    Widget tab(String label, bool isEmail) {
      final selected = _isEmailMode == isEmail;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (selected) return;
            setState(() {
              _isEmailMode = isEmail;
              _identifierController.clear();
              _error = null;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: selected
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? Colors.black : const Color(0xFF8E8E93),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [tab('Email', true), tab('Phone No.', false)]),
    );
  }

  Widget _buildIdentifierStep() {
    return Form(
      key: _identifierFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoBanner(
            'Enter the email or phone number on your ResQ account. We\'ll send you a 6-digit code to reset your password.',
          ),
          const SizedBox(height: 24),
          _modeToggle(),
          const SizedBox(height: 16),
          _label(_isEmailMode ? 'Email' : 'Phone Number'),
          TextFormField(
            controller: _identifierController,
            keyboardType: _isEmailMode ? TextInputType.emailAddress : TextInputType.phone,
            autocorrect: false,
            validator: _validateIdentifier,
            onFieldSubmitted: (_) => _sendCode(),
            decoration: _fieldDecoration(
              hintText: _isEmailMode ? 'Email' : 'Phone Number',
              prefixIcon: Icon(
                _isEmailMode ? Icons.mail_outline_rounded : Icons.phone_outlined,
                color: const Color(0xFF8E8E93),
                size: 20,
              ),
            ),
          ),
          _errorText(),
          const SizedBox(height: 28),
          _primaryButton(label: 'SEND CODE', busy: _sending, onPressed: _sendCode),
        ],
      ),
    );
  }

  Widget _buildResetStep() {
    final sentTo = _destination ?? _identifier;
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoBanner('We sent a 6-digit code to $sentTo. Enter it below with your new password.'),
          const SizedBox(height: 24),
          _label('Verification Code'),
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
            validator: (value) => (value == null || value.trim().length != 6) ? 'Please enter the 6-digit code.' : null,
            decoration: _fieldDecoration(hintText: '------'),
          ),
          Center(
            child: TextButton(
              onPressed: _sending ? null : () => _sendCode(isResend: true),
              child: Text(
                _sending ? 'Sending...' : 'Resend Code',
                style: const TextStyle(color: Color(0xFF9B1B20), fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _label('New Password'),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter a new password';
              if (value.length < 8) return 'Password must be at least 8 characters';
              return null;
            },
            decoration: _fieldDecoration(
              hintText: 'New password',
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF8E8E93), size: 20),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: const Color(0xFF8E8E93),
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _label('Confirm New Password'),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please confirm your new password';
              if (value != _passwordController.text) return 'Passwords do not match';
              return null;
            },
            decoration: _fieldDecoration(
              hintText: 'Confirm new password',
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF8E8E93), size: 20),
              suffixIcon: IconButton(
                tooltip: _obscureConfirmPassword ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: const Color(0xFF8E8E93),
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
          ),
          _errorText(),
          const SizedBox(height: 28),
          _primaryButton(label: 'RESET PASSWORD', busy: _resetting, onPressed: _resetPassword),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _sending || _resetting;
    return PopScope(
      canPop: !_codeSent && !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || busy) return;
        // Back from the code step returns to editing the email/phone.
        setState(() {
          _codeSent = false;
          _error = null;
        });
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F3F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFF9B1B20),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            onPressed: busy ? null : () => Navigator.maybePop(context),
          ),
          title: const Text(
            'Reset Password',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: _codeSent ? _buildResetStep() : _buildIdentifierStep(),
          ),
        ),
      ),
    );
  }
}
