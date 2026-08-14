import 'dart:async';
import 'package:flutter/material.dart';
import 'package:resq/model/screening_input_model.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/utils/constants/theme_constants.dart';
import 'package:resq/views/home/home_view.dart';

enum OtpVerificationMode { phone, email }

class OtpVerView extends StatefulWidget {
  final String phoneNumber;
  final String email;
  final String donorName;
  final String bloodType;
  final String donorId;
  final ScreenNPTModel? screeningModel;
  final ClassificationResult? classificationResult;

  const OtpVerView({
    super.key,
    required this.phoneNumber,
    required this.email,
    required this.donorName,
    required this.bloodType,
    required this.donorId,
    this.screeningModel,
    this.classificationResult,
  });

  @override
  State<OtpVerView> createState() => _OtpVerViewState();
}

class _OtpVerViewState extends State<OtpVerView> {
  late OtpVerificationMode _verificationMode;
  late String _phoneNumber;
  late String _email;

  final List<TextEditingController> _controllers =
  List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  Timer? _timer;
  int _secondsRemaining = 60;
  bool _canResend = false;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _verificationMode = OtpVerificationMode.phone;
    _phoneNumber = widget.phoneNumber;
    _email = widget.email;
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        setState(() => _canResend = true);
        _timer?.cancel();
      }
    });
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  void _clearOtpInputs() {
    for (var controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });
  }

  void _switchVerificationMode(OtpVerificationMode mode) {
    if (_verificationMode != mode) {
      setState(() {
        _verificationMode = mode;
      });
      _clearOtpInputs();
      _startResendTimer();
    }
  }

  void _verifyOtp() async {
    if (_otpCode.length < 6) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Please enter all 6 digits of your verification code.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (_otpCode == '000000') {
      setState(() {
        _hasError = true;
        _errorMessage = 'Invalid verification code. Please try again.';
      });
    } else {
      _showSuccessDialog();
    }
  }

  void _resendCode() {
    _clearOtpInputs();
    _startResendTimer();

    final target = _verificationMode == OtpVerificationMode.phone ? _phoneNumber : _email;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('A new 6-digit OTP code was dispatched to $target'),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showChangeContactModal() {
    final isPhone = _verificationMode == OtpVerificationMode.phone;
    final editController = TextEditingController(text: isPhone ? _phoneNumber : _email);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 24,
          left: 24,
          right: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPhone ? 'Change Phone Number' : 'Change Email Address',
              style: ResQTheme.heading2.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ResQTheme.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isPhone
                  ? 'Enter your updated 11-digit mobile number:'
                  : 'Enter your updated email address:',
              style: const TextStyle(fontSize: 12.5, color: ResQTheme.textMuted),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: editController,
              keyboardType: isPhone ? TextInputType.phone : TextInputType.emailAddress,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                prefixIcon: Icon(
                  isPhone ? Icons.phone_android_rounded : Icons.email_outlined,
                  color: ResQTheme.primaryCrimson,
                  size: 20,
                ),
                hintText: isPhone ? '09123456789' : 'donor@resq.ph',
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ResQTheme.lightBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ResQTheme.lightBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ResQTheme.primaryCrimson, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  final input = editController.text.trim();
                  if (input.isNotEmpty) {
                    setState(() {
                      if (isPhone) {
                        _phoneNumber = input;
                      } else {
                        _email = input;
                      }
                    });
                    Navigator.pop(context);
                    _resendCode();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ResQTheme.primaryCrimson,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'UPDATE & RESEND CODE',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF2E7D32),
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Account Verified!',
                textAlign: TextAlign.center,
                style: ResQTheme.heading1.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ResQTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _verificationMode == OtpVerificationMode.phone
                    ? 'Your phone number ($_phoneNumber) has been verified.'
                    : 'Your email address ($_email) has been verified.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: ResQTheme.textMuted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => HomeView(
                          donorName: widget.donorName,
                          bloodType: widget.bloodType,
                          donorId: widget.donorId,
                          screeningModel: widget.screeningModel,
                          classificationResult: widget.classificationResult,
                          isFirstTimeDonor:
                          widget.screeningModel?.screensNPT.isFirstTimeDonor ?? true,
                        ),
                      ),
                          (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ResQTheme.primaryCrimson,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'PROCEED TO DASHBOARD',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTarget =
    _verificationMode == OtpVerificationMode.phone ? _phoneNumber : _email;

    return Scaffold(
      backgroundColor: ResQTheme.bgOffWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: ResQTheme.textDark, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: ResQTheme.primaryCrimson.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.shield_outlined,
                    size: 38,
                    color: ResQTheme.primaryCrimson,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Verification Code',
                style: ResQTheme.heading1.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: ResQTheme.textDark,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _switchVerificationMode(OtpVerificationMode.phone),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _verificationMode == OtpVerificationMode.phone
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _verificationMode == OtpVerificationMode.phone
                                ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                              )
                            ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.phone_android,
                                size: 16,
                                color: _verificationMode == OtpVerificationMode.phone
                                    ? ResQTheme.primaryCrimson
                                    : ResQTheme.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Phone SMS',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _verificationMode == OtpVerificationMode.phone
                                      ? ResQTheme.primaryCrimson
                                      : ResQTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _switchVerificationMode(OtpVerificationMode.email),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _verificationMode == OtpVerificationMode.email
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _verificationMode == OtpVerificationMode.email
                                ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                              )
                            ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.email_outlined,
                                size: 16,
                                color: _verificationMode == OtpVerificationMode.email
                                    ? ResQTheme.primaryCrimson
                                    : ResQTheme.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Email OTP',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _verificationMode == OtpVerificationMode.email
                                      ? ResQTheme.primaryCrimson
                                      : ResQTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: ResQTheme.bodyText.copyWith(
                    fontSize: 12.5,
                    color: ResQTheme.textMuted,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: _verificationMode == OtpVerificationMode.phone
                          ? 'Enter code sent via SMS to\n'
                          : 'Enter code sent via email to\n',
                    ),
                    TextSpan(
                      text: activeTarget,
                      style: TextStyle(
                        color: ResQTheme.textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: _showChangeContactModal,
                icon: Icon(Icons.edit_outlined, size: 14, color: ResQTheme.primaryCrimson),
                label: Text(
                  _verificationMode == OtpVerificationMode.phone
                      ? 'Change phone number'
                      : 'Change email address',
                  style: TextStyle(
                    color: ResQTheme.primaryCrimson,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  6,
                      (index) => SizedBox(
                    width: 44,
                    height: 54,
                    child: TextFormField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _hasError ? Colors.red.shade700 : ResQTheme.primaryCrimson,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _hasError ? Colors.red.shade400 : ResQTheme.lightBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _hasError ? Colors.red.shade400 : ResQTheme.lightBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _hasError ? Colors.red.shade700 : ResQTheme.primaryCrimson,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          if (index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          } else {
                            _focusNodes[index].unfocus();
                          }
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                      },
                    ),
                  ),
                ),
              ),
              if (_hasError) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, color: Colors.red.shade700, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _errorMessage,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              _canResend
                  ? TextButton(
                onPressed: _resendCode,
                child: Text(
                  'RESEND CODE NOW',
                  style: TextStyle(
                    color: ResQTheme.primaryCrimson,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    letterSpacing: 0.8,
                  ),
                ),
              )
                  : Text(
                'Resend code in ${_secondsRemaining.toString().padLeft(2, '0')}s',
                style: TextStyle(
                  fontSize: 12,
                  color: ResQTheme.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ResQTheme.primaryCrimson,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: ResQTheme.primaryCrimson.withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'VERIFY & CONTINUE',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}