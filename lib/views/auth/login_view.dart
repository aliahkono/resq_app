import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:resq/model/screening_input_model.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/views/auth/registration_wiz_view.dart';
import 'package:resq/views/home/home_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isEmailMode = true; // true = Email, false = Phone No.
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Registered mock accounts for credential & biometric verification
  final List<Map<String, dynamic>> _registeredUsers = [
    {
      'email': 'donor@resq.ph',
      'phone': '09987654321',
      'password': 'Password123!',
      'name': 'John Doe',
      'bloodType': 'A+',
      'donorId': 'BD-10942',
      'isEligible': true,
      'biometricsLinked': true,
    },
    {
      'email': 'civic@gmail.com',
      'phone': '09123456789',
      'password': 'Password123!',
      'name': 'Civic Buenafe',
      'bloodType': 'O+',
      'donorId': 'BD-10942',
      'isEligible': true,
      'biometricsLinked': true,
    },
  ];

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Validation Helpers ---
  String? _validateIdentifier(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _isEmailMode ? 'Please enter your email' : 'Please enter your phone number';
    }
    final trimmed = value.trim();
    if (_isEmailMode) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(trimmed)) {
        return 'Please enter a valid email address';
      }
    } else {
      final phPhoneRegex = RegExp(r'^(09|\+639)\d{9}$');
      if (!phPhoneRegex.hasMatch(trimmed)) {
        return 'Enter a valid PH mobile number (e.g. 09123456789)';
      }
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }

  void _handleLogin() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 700));

    final input = _identifierController.text.trim().toLowerCase();
    final password = _passwordController.text;

    // Search user database
    final matchedUser = _registeredUsers.firstWhere(
          (u) => _isEmailMode
          ? (u['email'].toString().toLowerCase() == input)
          : (u['phone'].toString() == input),
      orElse: () => {},
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (matchedUser.isEmpty) {
      setState(() {
        _errorMessage = 'Account does not exist. Please register first.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('Account does not exist. Please register first.'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF8A1E26),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (matchedUser['password'] != password) {
      setState(() {
        _errorMessage = 'Incorrect password. Please try again.';
      });
      return;
    }

    _routeToHome(
      donorName: matchedUser['name'],
      bloodType: matchedUser['bloodType'],
      donorId: matchedUser['donorId'],
      isEligible: matchedUser['isEligible'],
    );
  }

  // --- Device Biometric / PIN Auth Dialog with Non-Existent User Handling ---
  Future<void> _handleDeviceBiometricAuth() async {
    setState(() => _errorMessage = null);

    try {
      final bool canCheck = await _localAuth.canCheckBiometrics;
      final bool isSupported = await _localAuth.isDeviceSupported();

      if (!canCheck && !isSupported) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device security (Fingerprint / PIN) is not set up on this device.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Scan fingerprint or enter device PIN to sign in to ResQ',
      );

      if (!didAuthenticate || !mounted) return;

      final input = _identifierController.text.trim().toLowerCase();

      // Check if typed user exists or resolve stored account
      Map<String, dynamic> matchedUser = {};

      if (input.isNotEmpty) {
        matchedUser = _registeredUsers.firstWhere(
              (u) => _isEmailMode
              ? (u['email'].toString().toLowerCase() == input)
              : (u['phone'].toString() == input),
          orElse: () => {},
        );
      } else {
        // Find default linked device account
        matchedUser = _registeredUsers.firstWhere(
              (u) => u['biometricsLinked'] == true,
          orElse: () => {},
        );
      }

      // Explicit error handling if no registered user matches the biometric request
      if (matchedUser.isEmpty) {
        setState(() {
          _errorMessage = 'No registered account found linked with this biometric. Please sign up first.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Account not found in system. Please register first.'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF8A1E26),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      _routeToHome(
        donorName: matchedUser['name'],
        bloodType: matchedUser['bloodType'],
        donorId: matchedUser['donorId'],
        isEligible: matchedUser['isEligible'],
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Authentication failed: ${e.message ?? "Try again"}'),
          backgroundColor: const Color(0xFF8A1E26),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _routeToHome({
    required String donorName,
    required String bloodType,
    required String donorId,
    required bool isEligible,
  }) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => HomeView(
          donorName: donorName,
          bloodType: bloodType,
          donorId: donorId,
          classificationResult: ClassificationResult(
            status: isEligible ? EligibleStats.eligible : EligibleStats.deferredWeight,
          ),
          isFirstTimeDonor: false,
        ),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBEBEB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Circular RQ Logo Badge
                  Container(
                    width: 110,
                    height: 110,
                    decoration: const BoxDecoration(
                      color: Color(0xFF7D1B22),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(22),
                    child: Image.asset(
                      'assets/images/rq_logo_white.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text(
                          'RQ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Welcome Back Header
                  const Text(
                    'Welcome Back!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sign in to your account.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF7A7A7A),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Segmented Switcher (Email vs Phone No.)
                  Container(
                    width: 220,
                    height: 40,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4D4D6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (!_isEmailMode) {
                                setState(() {
                                  _isEmailMode = true;
                                  _identifierController.clear();
                                  _errorMessage = null;
                                });
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: _isEmailMode ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _isEmailMode
                                    ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                                    : [],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Email',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: _isEmailMode ? FontWeight.bold : FontWeight.w500,
                                  color: _isEmailMode ? Colors.black : const Color(0xFF8E8E93),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (_isEmailMode) {
                                setState(() {
                                  _isEmailMode = false;
                                  _identifierController.clear();
                                  _errorMessage = null;
                                });
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: !_isEmailMode ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: !_isEmailMode
                                    ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                                    : [],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Phone No.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: !_isEmailMode ? FontWeight.bold : FontWeight.w500,
                                  color: !_isEmailMode ? Colors.black : const Color(0xFF8E8E93),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Error Message Banner
                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEF9A9A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFF8A1E26), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFF8A1E26),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Identifier Input Field (Email / Phone)
                  TextFormField(
                    controller: _identifierController,
                    keyboardType: _isEmailMode ? TextInputType.emailAddress : TextInputType.phone,
                    style: const TextStyle(fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: _isEmailMode ? 'Email' : 'Phone Number',
                      hintStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                      prefixIcon: const Icon(Icons.mail_outline_rounded, color: Color(0xFF8E8E93), size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF7D1B22), width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF7D1B22), width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF7D1B22), width: 2.0),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                      ),
                    ),
                    validator: _validateIdentifier,
                  ),

                  const SizedBox(height: 14),

                  // Password Input Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF8E8E93), size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: const Color(0xFF8E8E93),
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF7D1B22), width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF7D1B22), width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF7D1B22), width: 2.0),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                      ),
                    ),
                    validator: _validatePassword,
                  ),

                  const SizedBox(height: 6),

                  // Forgot my password?
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Password reset instructions sent to your email/phone.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Forgot my password?',
                        style: TextStyle(
                          color: Color(0xFF7D1B22),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Sign In Button
                  Container(
                    width: double.infinity,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7D1B22).withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8A1E26),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                          : const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Quick Biometric Icon Button (Device Fingerprint / PIN)
                  IconButton(
                    icon: const Icon(
                      Icons.fingerprint_rounded,
                      size: 34,
                      color: Color(0xFF7D1B22),
                    ),
                    onPressed: _handleDeviceBiometricAuth,
                    tooltip: 'Sign in with Fingerprint / PIN',
                  ),

                  const SizedBox(height: 10),

                  // Don't have an account? Sign Up
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7A7A7A),
                      ),
                      children: [
                        const TextSpan(text: "Don't have an account? "),
                        TextSpan(
                          text: 'Sign Up',
                          style: const TextStyle(
                            color: Color(0xFF7D1B22),
                            fontWeight: FontWeight.bold,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegistrationWizView(),
                                ),
                              );
                            },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}