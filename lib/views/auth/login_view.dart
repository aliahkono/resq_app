import 'dart:io';
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/views/auth/auth_landing_view.dart';
import 'package:resq/views/home/home_view.dart';
import 'package:resq/services/api_service.dart';
import 'package:resq/services/session_storage.dart';

// =============================================================================
// AUTH RESULT MODELS — kept local to this file (small, only used here and
// by AuthService right below). Move to lib/model/auth_model.dart later if
// other screens end up needing them too.
// =============================================================================

/// Real-world model for returned donor profile data from database
class DonorProfileData {
  final String id;
  final String name;
  final String bloodType;
  final bool isEligible;
  final String? token; // JWT/Session token

  DonorProfileData({
    required this.id,
    required this.name,
    required this.bloodType,
    required this.isEligible,
    this.token,
  });
}

/// Structured response object for asynchronous auth service calls
class AuthResult {
  final bool success;
  final String? errorMessage;
  final DonorProfileData? donorData;

  AuthResult({required this.success, this.errorMessage, this.donorData});
}

/// Talks to the real ResQ backend (see lib/services/api_service.dart for
/// the base URL you need to set for your machine/device).
class AuthService {
  /// identifier/password login — POST /api/donor-auth/login. The login
  /// endpoint's own response doesn't include eligibility/last-donation
  /// info (that's specific to GET /me), so this makes one extra call right
  /// after to fetch the full profile rather than guessing isEligible.
  Future<AuthResult> signInWithCredentials({
    required String identifier, // Email or Phone
    required String password,
    required bool isEmail,
  }) async {
    try {
      final loginResponse = await ApiService.loginWithPassword(identifier: identifier, password: password);
      final token = loginResponse['token'] as String;

      final profile = await ApiService.getMyProfile(token);
      await SessionStorage.saveToken(token);

      return AuthResult(
        success: true,
        donorData: DonorProfileData(
          id: profile['id'] as String,
          name: profile['name'] as String,
          bloodType: profile['bloodType'] as String,
          isEligible: profile['isEligible'] as bool? ?? true,
          token: token,
        ),
      );
    } on ApiException catch (e) {
      // e.message is already the backend's own error text (e.g. "Account
      // does not exist. Please register first.", "Incorrect password.",
      // the 429 lockout message) — safe to show directly, see ApiException.
      return AuthResult(success: false, errorMessage: e.message);
    }
  }

  /// Biometric/PIN re-entry: re-validates whatever session token is saved
  /// on-device against GET /api/donor/me, rather than a separate
  /// refresh-token endpoint (the backend doesn't have one — a donor
  /// session is a single 30-day token, not an access/refresh pair).
  Future<AuthResult> signInWithStoredSessionToken() async {
    final token = await SessionStorage.readToken();
    if (token == null) {
      return AuthResult(success: false, errorMessage: 'No saved session. Please sign in with your credentials.');
    }

    try {
      final profile = await ApiService.getMyProfile(token);
      return AuthResult(
        success: true,
        donorData: DonorProfileData(
          id: profile['id'] as String,
          name: profile['name'] as String,
          bloodType: profile['bloodType'] as String,
          isEligible: profile['isEligible'] as bool? ?? true,
          token: token,
        ),
      );
    } on ApiException catch (e) {
      // A 401 here means the token itself is dead (session logged out
      // elsewhere, or the 30-day TTL lapsed) — clear it locally too so the
      // app stops trying to reuse a token the backend will keep rejecting.
      if (e.statusCode == 401) await SessionStorage.clearToken();
      return AuthResult(success: false, errorMessage: e.message);
    }
  }
}
// =============================================================================

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

  // Interface instance for database calls
  final AuthService _authService = AuthService();

  bool _isEmailMode = true; // true = Email, false = Phone No.
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // --- MOCK REGISTERED ACCOUNTS LIST REMOVED ---

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Validation Helpers (Keep existing local validation) ---
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
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    return null;
  }

  // ===========================================================================
  // PERMANENT LOGIC: HANDLE CREDENTIAL LOGIN
  // ===========================================================================
  void _handleLogin() async {
    setState(() => _errorMessage = null);

    // 1. Perform client-side validation
    if (!_formKey.currentState!.validate()) return;

    // 2. Start loading state
    setState(() => _isLoading = true);

    final input = _identifierController.text.trim().toLowerCase();
    final password = _passwordController.text;

    try {
      // 3. CALL API SERVICE (see lib/services/api_service.dart /
      // lib/services/session_storage.dart — token is saved inside
      // AuthService.signInWithCredentials itself once login succeeds)
      final AuthResult result = await _authService.signInWithCredentials(
        identifier: input,
        password: password,
        isEmail: _isEmailMode,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      // 4. Handle Service Result
      if (result.success) {
        // Success path
        final data = result.donorData!;

        _routeToHome(
          donorName: data.name,
          bloodType: data.bloodType,
          donorId: data.id,
          isEligible: data.isEligible,
        );
      } else {
        // Failure path returned by DB (e.g., 401, 404)
        setState(() {
          _errorMessage = result.errorMessage ?? 'Unable to sign in. Please try again.';
        });
      }
    } catch (e) {
      // 5. Handle Network/Connection Errors or Unimplemented Errors during testing
      if (!mounted) return;
      setState(() => _isLoading = false);

      String displayError = 'A connection error occurred. Please check your internet and try again.';

      if (e is UnimplementedError) {
        displayError = 'Error: The Database connection logic in AuthService is not yet implemented.';
      } else if (e is SocketException || e is TimeoutException) {
        displayError = 'Network error: Cannot reach the ResQ server.';
      }

      setState(() {
        _errorMessage = displayError;
      });

      _showFloatingErrorSnackBar(displayError);
    }
  }

  // ===========================================================================
  // PERMANENT LOGIC: HANDLE DEVICE BIOMETRIC / PIN AUTH
  // ===========================================================================
  Future<void> _handleDeviceBiometricAuth() async {
    setState(() => _errorMessage = null);

    try {
      // 1. Check device capabilities locally
      final bool canCheck = await _localAuth.canCheckBiometrics;
      final bool isSupported = await _localAuth.isDeviceSupported();

      if (!canCheck && !isSupported) {
        if (!mounted) return;
        _showFloatingErrorSnackBar('Device security (Fingerprint / PIN) is not set up on this device.');
        return;
      }

      // 2. UPDATED local_auth implementation for version 3.0.x
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Scan fingerprint or enter device PIN to sign in to ResQ',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      if (!didAuthenticate || !mounted) return;

      // 3. Local scan successful -> Start network loading
      setState(() => _isLoading = true);

      // 4. CALL DB SERVICE: Verify session with stored token
      // Mapping local biometric success to a remote DB user requires token verification.
      final AuthResult result = await _authService.signInWithStoredSessionToken();

      if (!mounted) return;
      setState(() => _isLoading = false);

      // 5. Handle Service Result
      if (result.success) {
        final data = result.donorData!;
        _routeToHome(
          donorName: data.name,
          bloodType: data.bloodType,
          donorId: data.id,
          isEligible: data.isEligible,
        );
      } else {
        // Token was invalid, expired, or biometrics revoked on backend
        final String failMsg = result.errorMessage ?? 'Biometric session expired. Please sign in with your credentials.';
        setState(() {
          _errorMessage = failMsg;
        });
        _showFloatingErrorSnackBar(failMsg);
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      _showFloatingErrorSnackBar('Authentication failed: ${e.message ?? "Try again"}');
    } catch (e) {
      // Handle Network Errors during token refresh or Unimplemented Error during testing
      if (!mounted) return;
      setState(() => _isLoading = false);

      String displayError = 'Connection error during biometric login. Please use your credentials.';
      if (e is UnimplementedError) {
        displayError = 'Biometric DB Logic Unimplemented in AuthService.';
      }

      setState(() {
        _errorMessage = displayError;
      });
      _showFloatingErrorSnackBar(displayError);
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
          // --- UPDATED: Passing correct structure of ClassificationResult ---
          classificationResult: ClassificationResult(
            status: isEligible ? EligibleStats.eligible : EligibleStats.deferredWeight,
          ),
          isFirstTimeDonor: false,
        ),
      ),
          (route) => false,
    );
  }

  void _showFloatingErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF8A1E26),
        behavior: SnackBarBehavior.floating,
      ),
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
                                  // --- UPDATED: Clears password when switching modes ---
                                  _passwordController.clear();
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
                                    color: Colors.black.withValues(alpha: 0.08),
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
                                  // --- UPDATED: Clears password when switching modes ---
                                  _passwordController.clear();
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
                                    color: Colors.black.withValues(alpha: 0.08),
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

                  // Error Message Banner (Now displays permanent error states)
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
                      prefixIcon: Icon(
                        _isEmailMode ? Icons.mail_outline_rounded : Icons.phone_outlined,
                        color: const Color(0xFF8E8E93),
                        size: 20,
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
                          color: const Color(0xFF7D1B22).withValues(alpha: 0.35),
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
                              // --- UPDATED: Routes using AuthLandingView when signing out ---
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AuthLandingView(),
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