import 'package:flutter/material.dart';
import 'package:resq/model/donor_profile_model.dart';
import 'package:resq/model/screening_input_model.dart';
import 'package:resq/model/user_model.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/views/auth/login_view.dart';
import 'package:resq/views/auth/registration_summary_view.dart';
import 'package:resq/widgets/custom_input_field.dart';

class RegistrationWizView extends StatefulWidget {
  final bool isRetake;
  final ScreenNPTModel? initialScreening;
  final String? donorName;
  final String? bloodType;
  final String? donorId;
  final Function(ScreenNPTModel updatedModel, ClassificationResult result)? onRetakeCompleted;

  const RegistrationWizView({
    super.key,
    this.isRetake = false,
    this.initialScreening,
    this.donorName,
    this.bloodType,
    this.donorId,
    this.onRetakeCompleted,
  });

  @override
  State<RegistrationWizView> createState() => _RegistrationWizViewState();
}

class _RegistrationWizViewState extends State<RegistrationWizView> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 1;
  // Steps: 1 Account, 2 Physical Metrics, 3 Health Screening,
  // 4 Medical History & Risk Factors, 5 Final Screening (sex-specific)
  final int _totalSteps = 5;
  bool _isLoading = false;

  // Step 1: Account Controllers & Toggles
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Step 2: Physical Metrics State & Controllers
  String _selectedBloodType = 'O+';
  DateTime? _dob;
  BioSex _gender = BioSex.male;
  final _weightController = TextEditingController();
  DateTime? _lastDonationDate;
  bool _isFirstTimeDonor = false;
  int _totalDonations = 0;
  bool _hasTattoosOrPiercings = false;
  DateTime? _tattooDate;

  // Step 3: Immediate Readiness State (NEW)
  bool _feelsWellToday = true;
  bool _hasEatenRecently = true;
  bool _hasAlcoholPast24hr = false;

  // Step 4: Medical History & Risk Factors State (NEW)
  static const List<String> _medProcedureOptions = [
    'Antibiotics',
    'Aspirin',
    'Vaccines',
    'Dental Work',
    'Minor Surgery',
  ];
  final Set<String> _recentMedProcedures = {};
  bool _hasMajorMedicalHistory = false;
  bool _hasTransfusionOrSurgery = false;
  bool _hasTravelOrNeedleStick = false;

  // Step 5: Final Screening (Sex-Specific) State & Controllers
  // Female Specific
  DateTime? _lastMensDate;
  int _pregnancyStatusIndex = 0; // 0: Not pregnant, 1: Currently pregnant, 2: Within last 6 weeks
  bool _isBreastfeeding = false;

  // Male Specific
  bool _hasStiHistory = false;
  bool _hasHighRiskContact = false;
  int _msmHistoryIndex = 0; // 0: Never, 1: >3 mos ago, 2: Within 3 mos

  // Shared Lifestyle / Medical
  bool _hasRecentSexualRisk = false;
  bool _hasActiveInfectOrMeds = false;

  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    if (widget.isRetake && widget.initialScreening != null) {
      final initial = widget.initialScreening!.screensNPT;
      _currentStep = 2; // Skip account creation on retake
      _nameController.text = widget.donorName ?? '';
      _selectedBloodType = widget.bloodType ?? 'O+';
      _weightController.text = initial.weight > 0 ? initial.weight.toString() : '';
      _gender = initial.gender;
      _isFirstTimeDonor = initial.isFirstTimeDonor;
      _lastDonationDate = initial.lastDonationDate;
      _totalDonations = initial.totalDonations;
      _hasTattoosOrPiercings = initial.hasTattsOrPierce;
      _hasActiveInfectOrMeds = initial.hasActiveInfectOrMeds;
      _hasAlcoholPast24hr = initial.hasAlcoholPast24hr;
      _feelsWellToday = initial.feelsWellToday;
      _hasEatenRecently = initial.hasEatenRecently;
      _recentMedProcedures.addAll(initial.recentMedProcedures);
      _hasMajorMedicalHistory = initial.hasMajorMedicalHistory;
      _hasTransfusionOrSurgery = initial.hasTransfusionOrSurgery;
      _hasTravelOrNeedleStick = initial.hasTravelOrNeedleStick;
      _lastMensDate = initial.lastMensPeriodDate;
      _hasHighRiskContact = initial.hasHighRiskExpo ?? false;
      if (initial.isPregOrNursing == true) {
        _pregnancyStatusIndex = 1;
        _isBreastfeeding = true;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Date Picker';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _pickDate({
    required BuildContext context,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    required Function(DateTime) onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7D1B22),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  Future<void> _promptForDonationCount(BuildContext context) async {
    final TextEditingController countController = TextEditingController(
      text: _totalDonations > 0 ? _totalDonations.toString() : '',
    );

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Lifetime Donation History',
            style: TextStyle(color: Color(0xFF7D1B22), fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How many times have you donated blood in total (lifetime)?',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              CustomInputField(
                controller: countController,
                hintText: 'e.g., 4',
                labelText: 'Total Lifetime Donations',
                icon: Icons.history_edu_rounded,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final int? count = int.tryParse(countController.text.trim());
                if (count != null && count >= 0) {
                  setState(() => _totalDonations = count);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid number.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7D1B22)),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  bool _validateStep() {
    if (_currentStep == 1 && !widget.isRetake) {
      if (!(_formKey.currentState?.validate() ?? false)) {
        return false;
      }
    } else if (_currentStep == 2) {
      final weight = double.tryParse(_weightController.text.trim()) ?? 0.0;
      if (weight <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid weight in kg.')),
        );
        return false;
      }
    }
    return true;
  }

  void _nextStep() {
    if (!_validateStep()) return;
    if (_currentStep < _totalSteps) {
      setState(() => _currentStep++);
    } else {
      _finishAssessment();
    }
  }

  void _prevStep() {
    final int floor = widget.isRetake ? 2 : 1;
    if (_currentStep > floor) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _finishAssessment() async {
    setState(() => _isLoading = true);

    await Future.delayed(const Duration(milliseconds: 600));

    final double weight = double.tryParse(_weightController.text.trim()) ?? 52.0;
    int calculatedAge = 22;
    if (_dob != null) {
      final now = DateTime.now();
      calculatedAge = now.year - _dob!.year;
      if (now.month < _dob!.month || (now.month == _dob!.month && now.day < _dob!.day)) {
        calculatedAge--;
      }
    }

    final bool isPregOrNursing = _gender == BioSex.female && (_pregnancyStatusIndex != 0 || _isBreastfeeding);
    final bool hasHighRiskExpo = _gender == BioSex.male ? (_hasStiHistory || _hasHighRiskContact || _msmHistoryIndex == 2) : false;

    final DonorScreensNPT evaluatedParams = DonorScreensNPT(
      gender: _gender,
      weight: weight,
      age: calculatedAge,
      isFirstTimeDonor: _isFirstTimeDonor,
      lastDonationDate: _isFirstTimeDonor ? null : _lastDonationDate,
      totalDonations: _isFirstTimeDonor ? 0 : _totalDonations,
      feelsWellToday: _feelsWellToday,
      hasEatenRecently: _hasEatenRecently,
      hasTattsOrPierce: _hasTattoosOrPiercings,
      hasAlcoholPast24hr: _hasAlcoholPast24hr,
      hasActiveInfectOrMeds: _hasActiveInfectOrMeds,
      recentMedProcedures: _recentMedProcedures,
      hasMajorMedicalHistory: _hasMajorMedicalHistory,
      hasTransfusionOrSurgery: _hasTransfusionOrSurgery,
      hasTravelOrNeedleStick: _hasTravelOrNeedleStick,
      isPregOrNursing: _gender == BioSex.female ? isPregOrNursing : null,
      lastMensPeriodDate: _gender == BioSex.female ? _lastMensDate : null,
      hasHighRiskExpo: _gender == BioSex.male ? hasHighRiskExpo : null,
    );

    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final String activeUserId = 'USR-$timestamp';
    final String activeProfId = widget.donorId ?? 'PRF-$timestamp';

    final ScreenNPTModel finalModel = ScreenNPTModel(
      donorProfId: activeProfId,
      submissionDate: DateTime.now(),
      screensNPT: evaluatedParams,
    );

    final ClassificationResult result = finalModel.evaluateEligibility();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (widget.isRetake) {
      widget.onRetakeCompleted?.call(finalModel, result);
      Navigator.pop(context);
    } else {
      final UserModel newUser = UserModel(
        id: activeUserId,
        email: _emailController.text.trim(),
        fullName: _nameController.text.trim(),
        phoneNum: '+63${_phoneController.text.trim()}',
        createdAt: DateTime.now(),
      );

      final DonorProfModel newProfile = DonorProfModel(
        profId: activeProfId,
        userId: activeUserId,
        bloodType: _selectedBloodType == "I'm not sure" ? 'Unknown' : _selectedBloodType,
        gender: _gender,
        weight: weight,
        age: calculatedAge,
        eligibilityStats: result.status,
        lastDonationDate: _lastDonationDate,
      );

      // Navigate to Summary View to allow donor review before SMS OTP verification
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RegistrationSummaryView(
            userModel: newUser,
            profileModel: newProfile,
            screeningModel: finalModel,
            classificationResult: result,
            rawPassword: _passwordController.text,
            isFirstTimeDonor: _isFirstTimeDonor,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F5),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF7D1B22)))
            : Column(
          children: [
            if (_currentStep > 1) _buildCurvedTopHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    if (_currentStep == 1) _buildStep1AccountUI(),
                    if (_currentStep == 2) _buildStep2PhysicalMetricsUI(),
                    if (_currentStep == 3) _buildStep3HealthScreeningUI(),
                    if (_currentStep == 4) _buildStep4MedicalHistoryUI(),
                    if (_currentStep == 5) _buildStep5FinalScreeningUI(),
                  ],
                ),
              ),
            ),
            if (_currentStep == 3 || _currentStep == 4)
              _buildStepNavRow(
                onPrev: _prevStep,
                onNext: _nextStep,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurvedTopHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 14, bottom: 22, left: 18, right: 18),
      decoration: const BoxDecoration(
        color: Color(0xFF7D1B22),
        borderRadius: BorderRadius.vertical(bottom: Radius.elliptical(240, 30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/rq_logo_white.png',
            height: 32,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text(
              'RQ',
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 1.5, height: 26, color: Colors.white70),
          const SizedBox(width: 12),
          const Text(
            'Connect, Save Lives, On time.',
            style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1AccountUI() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFF7D1B22),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7D1B22).withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Image.asset(
              'assets/images/rq_logo_white.png',
              height: 52,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text(
                'RQ',
                style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Create Your Account',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E), letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          const Text(
            'Join our community of lifesaving donors.',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 32),
          _buildBorderedInput(
            controller: _nameController,
            hintText: 'Full Name',
            icon: Icons.person_rounded,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Please enter your full name';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildBorderedInput(
            controller: _emailController,
            hintText: 'Email Address',
            icon: Icons.email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Please enter your email';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildPhoneInput(),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_rounded, size: 16, color: Color(0xFF7D1B22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "We'll send a 6-digit verification code via SMS to this number.",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBorderedInput(
            controller: _passwordController,
            hintText: 'Password',
            icon: Icons.lock_rounded,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.grey[400], size: 22),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter a password';
              if (value.length < 8) return 'Password must be at least 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildBorderedInput(
            controller: _confirmPasswordController,
            hintText: 'Confirm Password',
            icon: Icons.lock_clock_rounded,
            obscureText: _obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.grey[400], size: 22),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please confirm your password';
              if (value != _passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6F6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEAA1A5).withOpacity(0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7D1B22).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield_rounded, color: Color(0xFF7D1B22), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Privacy Guaranteed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF7D1B22))),
                      SizedBox(height: 4),
                      Text(
                        'Your data is encrypted and strictly used for medical eligibility checks within our secure network',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280), height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Already have an account? ', style: TextStyle(fontSize: 14, color: Color(0xFF4B5563))),
              InkWell(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginView()),
                  );
                },
                child: const Text('Log In', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF7D1B22))),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildPrimaryCTA(
            title: 'Continue to Details',
            onTap: _nextStep,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPhoneInput() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1E1E1E), fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: true,
        fillColor: Colors.white,
        hintText: 'Phone Number',
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, fontWeight: FontWeight.normal),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🇵🇭 +63', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E1E1E))),
              const Icon(Icons.arrow_drop_down, color: Color(0xFF1E1E1E), size: 20),
              const SizedBox(width: 12),
              Container(width: 1.5, height: 24, color: const Color(0xFFE5E7EB)),
            ],
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7D1B22), width: 2),
        ),
      ),
    );
  }

  Widget _buildStep2PhysicalMetricsUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Physical Metrics',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
          ),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text(
            'Please provide your basic physical information to help us determine your donation eligibility.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280), height: 1.35),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Blood Type Selection', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E))),
        const SizedBox(height: 2),
        const Text('Select your blood type if known. Otherwise, choose "I\'m not sure".', style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280))),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.25,
          ),
          itemCount: _bloodTypes.length,
          itemBuilder: (context, index) {
            final type = _bloodTypes[index];
            final isSelected = _selectedBloodType == type;
            return InkWell(
              onTap: () => setState(() => _selectedBloodType = type),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF7D1B22) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF7D1B22), width: 1.4),
                ),
                alignment: Alignment.center,
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFF7D1B22),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            onPressed: () => setState(() => _selectedBloodType = "I'm not sure"),
            style: OutlinedButton.styleFrom(
              backgroundColor: _selectedBloodType == "I'm not sure" ? const Color(0xFF7D1B22) : Colors.white,
              side: const BorderSide(color: Color(0xFF7D1B22), width: 1.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              "I'm not sure",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _selectedBloodType == "I'm not sure" ? Colors.white : const Color(0xFF7D1B22),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text('Date of Birth', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildCrimsonDateButton(
          title: _dob != null ? _formatDate(_dob) : 'Date Picker',
          onTap: () => _pickDate(
            context: context,
            initialDate: DateTime(2002),
            firstDate: DateTime(1940),
            lastDate: DateTime.now(),
            onPicked: (d) => _dob = d,
          ),
        ),
        const SizedBox(height: 16),
        const Text('Biological Sex', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFD4D4D8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _gender = BioSex.female),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _gender == BioSex.female ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Female',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: _gender == BioSex.female ? const Color(0xFF1E1E1E) : const Color(0xFF52525B),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _gender = BioSex.male),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _gender == BioSex.male ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Male',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: _gender == BioSex.male ? const Color(0xFF1E1E1E) : const Color(0xFF52525B),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Weight (kg)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildBorderedInput(
          controller: _weightController,
          hintText: 'Enter your weight here',
          icon: Icons.monitor_weight_outlined,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 18),
        const Text('Last Blood Donation', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildCrimsonDateButton(
          title: _lastDonationDate != null ? _formatDate(_lastDonationDate) : 'Date Picker',
          onTap: () async {
            await _pickDate(
              context: context,
              initialDate: DateTime.now().subtract(const Duration(days: 90)),
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
              onPicked: (d) {
                _lastDonationDate = d;
                _isFirstTimeDonor = false;
              },
            );
            if (!mounted) return;
            await _promptForDonationCount(context);
          },
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => setState(() {
            _isFirstTimeDonor = !_isFirstTimeDonor;
            if (_isFirstTimeDonor) _lastDonationDate = null;
          }),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: _isFirstTimeDonor ? const Color(0xFF7D1B22) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF9CA3AF), width: 1.5),
                ),
                child: _isFirstTimeDonor ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
              ),
              const SizedBox(width: 8),
              const Text('First time donating.', style: TextStyle(fontSize: 12.5, color: Color(0xFF4B5563))),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Recent Procedures', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _buildProcedureOption(
          label: 'No Tattoos or Piercings',
          isSelected: !_hasTattoosOrPiercings,
          onTap: () => setState(() => _hasTattoosOrPiercings = false),
        ),
        const SizedBox(height: 8),
        _buildProcedureOption(
          label: 'Yes, I have Tattoos / Piercings',
          isSelected: _hasTattoosOrPiercings,
          onTap: () => setState(() => _hasTattoosOrPiercings = true),
        ),
        if (_hasTattoosOrPiercings) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE2EDFE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_outline_rounded, color: Color(0xFF1D4ED8), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Standard deferral period is 6 months to 12 months. Please provide the date of your last procedure for verification',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('Date of Last Tattoo / Piercing', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          _buildCrimsonDateButton(
            title: _tattooDate != null ? _formatDate(_tattooDate) : 'dd/mm/yyyy',
            onTap: () => _pickDate(
              context: context,
              initialDate: DateTime.now().subtract(const Duration(days: 180)),
              firstDate: DateTime(2010),
              lastDate: DateTime.now(),
              onPicked: (d) => _tattooDate = d,
            ),
          ),
        ],
        const SizedBox(height: 24),
        _buildPrimaryCTA(
          title: 'Continue to Health Screening',
          onTap: _nextStep,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Step 3: Immediate Readiness (Health Screening) — NEW
  Widget _buildStep3HealthScreeningUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Health Screening',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
          ),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text(
            'Answer truthfully to ensure donor and recipient safety.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
          ),
        ),
        const SizedBox(height: 18),
        _buildInfoBanner(
          'Your data is encrypted and handled according to medical privacy standards (HIPAA compliance). We only use this information to determine eligibility.',
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(Icons.access_time_filled_rounded, 'Immediate Readiness'),
        const SizedBox(height: 12),
        _buildYesNoCard(
          question: 'Are you feeling well and healthy today?',
          value: _feelsWellToday,
          onChanged: (val) => setState(() => _feelsWellToday = val),
        ),
        const SizedBox(height: 10),
        _buildYesNoCard(
          question: 'Have you had a full meal & fluids in the last 4-6 hrs?',
          value: _hasEatenRecently,
          onChanged: (val) => setState(() => _hasEatenRecently = val),
        ),
        const SizedBox(height: 10),
        _buildYesNoCard(
          question: 'Have you consumed alcohol in the past 24 hours?',
          value: _hasAlcoholPast24hr,
          onChanged: (val) => setState(() => _hasAlcoholPast24hr = val),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Step 4: Medical History & Risk Factors — NEW
  Widget _buildStep4MedicalHistoryUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildSectionHeader(Icons.assignment_rounded, 'Medical History'),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Check all that apply in the last 4 weeks:',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _medProcedureOptions.map((option) {
                  final isSelected = _recentMedProcedures.contains(option);
                  return _buildChipToggle(
                    label: option,
                    isSelected: isSelected,
                    onTap: () => setState(() {
                      if (isSelected) {
                        _recentMedProcedures.remove(option);
                      } else {
                        _recentMedProcedures.add(option);
                      }
                    }),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildYesNoCard(
          question: 'Major Medical History',
          subtitle: 'Heart disease, Asthma, Diabetes, etc.',
          value: _hasMajorMedicalHistory,
          onChanged: (val) => setState(() => _hasMajorMedicalHistory = val),
        ),
        const SizedBox(height: 22),
        _buildSectionHeader(Icons.warning_rounded, 'Risk Factors'),
        const SizedBox(height: 12),
        _buildYesNoCard(
          question: 'Transfusions or Surgeries?',
          subtitle: 'In the last 12 months',
          value: _hasTransfusionOrSurgery,
          onChanged: (val) => setState(() => _hasTransfusionOrSurgery = val),
        ),
        const SizedBox(height: 10),
        _buildYesNoCard(
          question: 'Travel or Needle Sticks?',
          subtitle: 'International travel or accidental sticks (12 mos)',
          value: _hasTravelOrNeedleStick,
          onChanged: (val) => setState(() => _hasTravelOrNeedleStick = val),
        ),
        const SizedBox(height: 20),
        _buildComfortBanner(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStep5FinalScreeningUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Final Screening',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
          ),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text(
            'Additional questions based on the biological sex.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
          ),
        ),
        const SizedBox(height: 18),
        if (_gender == BioSex.female) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'If you are currently pregnant or nursing, your donation will be temporarily deferred.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Date of Last Menstrual Period', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => _pickDate(
              context: context,
              initialDate: DateTime.now().subtract(const Duration(days: 14)),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              onPicked: (d) => _lastMensDate = d,
            ),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                _lastMensDate != null ? _formatDate(_lastMensDate) : 'mm/dd/yyyy',
                style: TextStyle(fontSize: 13, color: _lastMensDate != null ? const Color(0xFF1E1E1E) : const Color(0xFF9CA3AF)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Pregnancy Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildSelectionOption(
            title: 'Not currently pregnant',
            isSelected: _pregnancyStatusIndex == 0,
            onTap: () => setState(() => _pregnancyStatusIndex = 0),
          ),
          const SizedBox(height: 8),
          _buildSelectionOption(
            title: 'Currently pregnant',
            isSelected: _pregnancyStatusIndex == 1,
            onTap: () => setState(() => _pregnancyStatusIndex = 1),
          ),
          const SizedBox(height: 8),
          _buildSelectionOption(
            title: 'Pregnant within last 6 weeks',
            isSelected: _pregnancyStatusIndex == 2,
            onTap: () => setState(() => _pregnancyStatusIndex = 2),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Currently Breastfeeding', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    SizedBox(height: 2),
                    Text('Toggle if nursing a child', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                  ],
                ),
                Switch(
                  value: _isBreastfeeding,
                  onChanged: (val) => setState(() => _isBreastfeeding = val),
                  activeColor: const Color(0xFF7D1B22),
                ),
              ],
            ),
          ),
        ],
        if (_gender == BioSex.male) ...[
          const Text('History of STI/STD (Last 12 mos)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDualChoiceButton('Yes', _hasStiHistory, () => setState(() => _hasStiHistory = true)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDualChoiceButton('No', !_hasStiHistory, () => setState(() => _hasStiHistory = false)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('High-Risk Sexual Contact (Last 12 mos)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Have you had sexual contact with anyone who has ever had a positive HIV test or used needles for non-prescription drugs?',
                  style: TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.35),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDualChoiceButton('Yes', _hasHighRiskContact, () => setState(() => _hasHighRiskContact = true)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDualChoiceButton('No', !_hasHighRiskContact, () => setState(() => _hasHighRiskContact = false)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('MSM History (Men who have sex with men)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildSelectionOption(
            title: 'Never had sex with a man',
            isSelected: _msmHistoryIndex == 0,
            onTap: () => setState(() => _msmHistoryIndex = 0),
          ),
          const SizedBox(height: 8),
          _buildSelectionOption(
            title: 'Last contact over 3 months ago',
            isSelected: _msmHistoryIndex == 1,
            onTap: () => setState(() => _msmHistoryIndex = 1),
          ),
          const SizedBox(height: 8),
          _buildSelectionOption(
            title: 'Recent contact within 3 months',
            isSelected: _msmHistoryIndex == 2,
            onTap: () => setState(() => _msmHistoryIndex = 2),
          ),
        ],
        const SizedBox(height: 16),
        const Text('Recent Sexual Risk', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => setState(() => _hasRecentSexualRisk = !_hasRecentSexualRisk),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _hasRecentSexualRisk,
                  onChanged: (val) => setState(() => _hasRecentSexualRisk = val ?? false),
                  activeColor: const Color(0xFF7D1B22),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      'I have had a new sexual partner or multiple partners in the last 3 months.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFD32F2F),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 12),
              const Text(
                'Almost Ready',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
              ),
              const SizedBox(height: 6),
              const Text(
                'Review your details to ensure eligibility verification matches your government clinical records.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            SizedBox(
              width: 56,
              height: 50,
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF7D1B22), width: 1.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF7D1B22)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildPrimaryCTA(
                title: 'Review Registration Summary',
                onTap: _nextStep,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildBorderedInput({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1E1E1E), fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: true,
        fillColor: Colors.white,
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, fontWeight: FontWeight.normal),
        prefixIcon: Icon(icon, color: const Color(0xFF7D1B22), size: 20),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7D1B22), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildCrimsonDateButton({
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF8A1E26),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
            const Icon(Icons.calendar_month_rounded, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProcedureOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF8A1E26) : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? const Color(0xFF8A1E26) : const Color(0xFF64748B),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionOption({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF8A1E26) : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF8A1E26) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF94A3B8), width: 1.5),
              ),
              child: isSelected ? const Icon(Icons.check, size: 10, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDualChoiceButton(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8A1E26) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF8A1E26) : const Color(0xFFCBD5E1),
            width: 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryCTA({
    required String title,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8A1E26),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF8A1E26), size: 14),
            ),
          ],
        ),
      ),
    );
  }

  // --- New shared widgets for Health Screening / Medical History steps ---

  /// Blue info banner, matches the HIPAA-style disclosure box in the design.
  Widget _buildInfoBanner(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE2EDFE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF1D4ED8), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  /// Red icon + bold title section header, e.g. "⏱ Immediate Readiness".
  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF7D1B22), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
        ),
      ],
    );
  }

  /// White card with a question (+ optional subtitle) on the left and a
  /// compact Yes/No pill selector on the right.
  Widget _buildYesNoCard({
    required String question,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF1E1E1E), height: 1.3),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildCompactYesNo(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildCompactYesNo({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCompactYesNoOption(label: 'Yes', isSelected: value, onTap: () => onChanged(true), isLeft: true),
          _buildCompactYesNoOption(label: 'No', isSelected: !value, onTap: () => onChanged(false), isLeft: false),
        ],
      ),
    );
  }

  Widget _buildCompactYesNoOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isLeft,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.horizontal(
        left: isLeft ? const Radius.circular(9) : Radius.zero,
        right: !isLeft ? const Radius.circular(9) : Radius.zero,
      ),
      child: Container(
        width: 52,
        height: 34,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8A1E26) : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isLeft ? const Radius.circular(9) : Radius.zero,
            right: !isLeft ? const Radius.circular(9) : Radius.zero,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  /// Rounded pill chip used for the "Check all that apply" medical history list.
  Widget _buildChipToggle({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8A1E26) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF8A1E26) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  /// Decorative reassurance banner shown at the end of Medical History /
  /// Risk Factors, matching the "Your comfort is our priority" panel.
  /// Swap the icon container for an Image.asset(...) once you have a photo.
  Widget _buildComfortBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7D1B22), Color(0xFF3A0C10)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your comfort is our priority.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Medical professionals are on-site for any questions.',
                    style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fixed footer nav row with Prev / Next pill buttons, matching the design.
  Widget _buildStepNavRow({
    required VoidCallback onPrev,
    required VoidCallback onNext,
    String nextLabel = 'Next',
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: onPrev,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF7D1B22), width: 1.4),
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.arrow_back_rounded, size: 17, color: Color(0xFF7D1B22)),
                    SizedBox(width: 6),
                    Text('Prev', style: TextStyle(color: Color(0xFF7D1B22), fontWeight: FontWeight.bold, fontSize: 13.5)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8A1E26),
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(nextLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 17, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}