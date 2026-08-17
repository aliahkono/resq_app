import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:resq/model/screening_input_model.dart';
import 'package:resq/services/api_service.dart';
import 'package:resq/services/session_storage.dart';
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
  // Only required on a fresh registration (not currently reachable from any
  // other flow — see registration_summary_view.dart) — carried through so
  // this screen can call complete-profile once the code is verified. The
  // backend hashes it immediately on arrival; nothing keeps it around
  // beyond that single request.
  final String password;
  final ScreenNPTModel? screeningModel;
  final ClassificationResult? classificationResult;

  const OtpVerView({
    super.key,
    required this.phoneNumber,
    required this.email,
    required this.donorName,
    required this.bloodType,
    required this.donorId,
    required this.password,
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

  // Separate from the resend cooldown above (_secondsRemaining/_timer),
  // which only governs when the RESEND button re-enables. This tracks how
  // long the *current* code itself stays valid server-side — driven by the
  // real expiresIn the backend returns from request-otp (otp.js's
  // OTP_TTL_SECONDS, 5 minutes by default), not a guessed client-side
  // number, so it can never drift out of sync with what the backend
  // actually enforces.
  Timer? _expiryTimer;
  int _secondsUntilExpiry = 300;
  bool _codeExpired = false;

  @override
  void initState() {
    super.initState();
    _verificationMode = OtpVerificationMode.phone;
    _phoneNumber = widget.phoneNumber;
    _email = widget.email;
    _startResendTimer();
    // Fire the actual SMS the moment this screen appears — the resend
    // countdown above already assumes a code was just sent, so the first
    // send has to happen here, not wait for the donor to tap anything.
    _sendOtp(showSnackBarOnSuccess: false);
  }

  /// POST /api/donor-auth/request-otp. The code is always issued for
  /// _phoneNumber server-side (see api_service.dart) — the active tab just
  /// picks which channel this particular send goes out on.
  Future<bool> _sendOtp({bool showSnackBarOnSuccess = true}) async {
    final byEmail = _verificationMode == OtpVerificationMode.email;
    try {
      final response = await ApiService.requestOtp(
        _phoneNumber,
        channel: byEmail ? 'email' : 'sms',
        email: byEmail ? _email : null,
      );
      if (!mounted) return true;
      // Falls back to 300s (5 min) only if an older backend build doesn't
      // send expiresIn back — the real backend always does.
      _startExpiryTimer((response['expiresIn'] as int?) ?? 300);
      if (showSnackBarOnSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('A new 6-digit code was sent to ${byEmail ? _email : _phoneNumber}'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;
      setState(() {
        _hasError = true;
        _errorMessage = e.message;
      });
      return false;
    } catch (_) {
      if (!mounted) return false;
      setState(() {
        _hasError = true;
        _errorMessage = 'Could not reach the ResQ server. Check your connection and try again.';
      });
      return false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _expiryTimer?.cancel();
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

  /// Starts (or restarts) the code-expiry countdown. `seconds` should come
  /// straight from request-otp's `expiresIn` — see _sendOtp below — so this
  /// always reflects however long the backend actually honors the code for.
  void _startExpiryTimer(int seconds) {
    setState(() {
      _secondsUntilExpiry = seconds;
      _codeExpired = false;
    });
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsUntilExpiry > 0) {
        setState(() => _secondsUntilExpiry--);
      } else {
        setState(() => _codeExpired = true);
        _expiryTimer?.cancel();
      }
    });
  }

  String _formatExpiry(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
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
      // Switching tabs means the donor wants the code somewhere else —
      // send a fresh one on the newly-selected channel right away, same as
      // the initial send in initState.
      _sendOtp(showSnackBarOnSuccess: false);
    }
  }

  void _verifyOtp() async {
    if (_codeExpired) {
      // Catches it client-side with a clearer message than the backend's
      // generic "Invalid or expired code." would give — the backend still
      // enforces this independently regardless (verifyOtp in otp.js), this
      // is purely a friendlier first check.
      setState(() {
        _hasError = true;
        _errorMessage = 'This code has expired. Tap "Resend Code" to get a new one.';
      });
      return;
    }

    // Same check regardless of which tab is active — the code is always
    // bound to _phoneNumber server-side (see api_service.dart's
    // requestOtp), so verification itself doesn't branch on channel at all.
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

    try {
      final verifyResponse = await ApiService.verifyOtp(phone: _phoneNumber, code: _otpCode);

      Map<String, dynamic>? donor;
      String sessionToken;

      if (verifyResponse['needsProfile'] == true) {
        // Brand-new donor — the token here is only a short-lived pending
        // token good for exactly one call: complete-profile.
        final screens = widget.screeningModel?.screensNPT;
        final completeResponse = await ApiService.completeProfile(
          pendingToken: verifyResponse['token'] as String,
          name: widget.donorName,
          bloodType: widget.bloodType,
          password: widget.password,
          email: widget.email,
          age: screens?.age,
          weightKg: screens?.weight,
          gender: screens?.gender.name,
          healthScreening: screens == null
              ? null
              : {
                  'isFirstTimeDonor': screens.isFirstTimeDonor,
                  'lastDonationDate': screens.lastDonationDate?.toIso8601String(),
                  'totalDonations': screens.totalDonations,
                  'hasTattsOrPierce': screens.hasTattsOrPierce,
                  'hasAlcoholPast24hr': screens.hasAlcoholPast24hr,
                  'hasActiveInfectOrMeds': screens.hasActiveInfectOrMeds,
                  'isPregOrNursing': screens.isPregOrNursing,
                  'lastMensPeriodDate': screens.lastMensPeriodDate?.toIso8601String(),
                  'hasHighRiskExpo': screens.hasHighRiskExpo,
                  if (widget.classificationResult != null)
                    'classificationStatus': widget.classificationResult!.status.name,
                },
        );
        sessionToken = completeResponse['token'] as String;
        donor = completeResponse['donor'] as Map<String, dynamic>?;
      } else {
        // A donor record already existed for this phone (e.g. an admin
        // walk-in entry) — verify-otp already logged them in, no
        // complete-profile call needed or even valid at this point.
        sessionToken = verifyResponse['token'] as String;
        donor = verifyResponse['donor'] as Map<String, dynamic>?;
      }

      await SessionStorage.saveToken(sessionToken);

      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSuccessDialog(donor);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.message;
      });
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Network error: Cannot reach the ResQ server.';
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'The server took too long to respond. Please try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _resendCode() async {
    _clearOtpInputs();
    _startResendTimer();
    await _sendOtp();
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

  // `donor` is the real record the backend just returned (from
  // complete-profile or, for the already-existed branch, verify-otp
  // itself) — used in place of the locally-generated placeholder id so
  // HomeView gets the donor's actual database id, not a fake 'PRF-...' one.
  void _showSuccessDialog(Map<String, dynamic>? donor) {
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
                style: const TextStyle(
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
                          donorName: (donor?['name'] as String?) ?? widget.donorName,
                          bloodType: (donor?['bloodType'] as String?) ?? widget.bloodType,
                          donorId: (donor?['id'] as String?) ?? widget.donorId,
                          phoneNum: _phoneNumber,
                          donorEmail: _email,
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
                child: const Center(
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
                      style: const TextStyle(
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
                icon: const Icon(Icons.edit_outlined, size: 14, color: ResQTheme.primaryCrimson),
                label: const Text(
                  'Change contact details',
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
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _codeExpired ? const Color(0xFFFEE2E2) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _codeExpired ? Icons.error_outline_rounded : Icons.timer_outlined,
                      size: 14,
                      color: _codeExpired ? Colors.red.shade700 : ResQTheme.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _codeExpired ? 'Code expired' : 'Expires in ${_formatExpiry(_secondsUntilExpiry)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: _codeExpired ? Colors.red.shade700 : ResQTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
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
                child: const Text(
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
                style: const TextStyle(
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