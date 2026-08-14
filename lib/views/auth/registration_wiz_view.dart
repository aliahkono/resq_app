import 'package:flutter/material.dart';
import 'package:resq/model/screening_input_model.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/utils/constants/theme_constants.dart';
import 'package:resq/utils/helpers/eligibility_rules.dart';
import 'package:resq/views/auth/otp_ver_view.dart';

class RegistrationWizView extends StatefulWidget {
  const RegistrationWizView({super.key});

  @override
  State<RegistrationWizView> createState() => _RegistrationWizViewState();
}

class _RegistrationWizViewState extends State<RegistrationWizView> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Step 1 Controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // Step 2 Demographics
  String _selectedBloodType = 'O+';
  BioSex _selectedGender = BioSex.male;
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();

  // Step 3 Health Screening (General)
  bool _isFirstTimeDonor = true;
  DateTime? _lastDonationDate;
  bool _hasTattsOrPierce = false;
  bool _hasAlcoholPast24hr = false;
  bool _hasActiveInfectOrMeds = false;

  // Step 3 Health Screening (Female Specific)
  bool _isPregOrNursing = false;
  DateTime? _lastMensPeriodDate;

  // Step 3 Health Screening (Male Specific)
  bool _hasHighRiskExpo = false;

  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void dispose() {
    _pageController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submitRegistration();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  /// Builds and encapsulates user form inputs into [ScreenNPTModel]
  ScreenNPTModel _buildScreeningModel() {
    final double weight = double.tryParse(_weightController.text.trim()) ?? 0.0;
    final int age = int.tryParse(_ageController.text.trim()) ?? 0;

    final donorScreens = DonorScreensNPT(
      gender: _selectedGender,
      weight: weight,
      age: age,
      isFirstTimeDonor: _isFirstTimeDonor,
      lastDonationDate: _lastDonationDate,
      hasTattsOrPierce: _hasTattsOrPierce,
      hasAlcoholPast24hr: _hasAlcoholPast24hr,
      hasActiveInfectOrMeds: _hasActiveInfectOrMeds,
      isPregOrNursing: _selectedGender == BioSex.female ? _isPregOrNursing : null,
      lastMensPeriodDate: _selectedGender == BioSex.female ? _lastMensPeriodDate : null,
      hasHighRiskExpo: _selectedGender == BioSex.male ? _hasHighRiskExpo : null,
    );

    return ScreenNPTModel(
      donorProfId: 'temp_profile_${DateTime.now().millisecondsSinceEpoch}',
      screensNPT: donorScreens,
      submissionDate: DateTime.now(),
    );
  }

  void _submitRegistration() {
    // 1. Construct screening model from user inputs
    final screeningModel = _buildScreeningModel();

    // 2. Evaluate eligibility using model's decision tree classifier
    final classificationResult = screeningModel.evaluateEligibility();

    // 3. Generate a dynamic Donor ID based on timestamp
    final String generatedDonorId =
        'RESQ-PH-${DateTime.now().year}-${(DateTime.now().millisecondsSinceEpoch % 100000).toString().padLeft(5, '0')}';

    // 4. Navigate to OTP passing user's real registration data
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OtpVerView(
          phoneNumber: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          donorName: _fullNameController.text.trim(),
          bloodType: _selectedBloodType,
          donorId: generatedDonorId,
          screeningModel: screeningModel,
          classificationResult: classificationResult,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_currentStep + 1) / _totalSteps;

    return Scaffold(
      backgroundColor: ResQTheme.bgOffWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: ResQTheme.textDark, size: 18),
          onPressed: _previousStep,
        ),
        title: Text(
          'Donor Registration',
          style: ResQTheme.heading2.copyWith(
            fontSize: 18,
            color: ResQTheme.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Wizard Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step ${_currentStep + 1} of $_totalSteps',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: ResQTheme.primaryCrimson,
                        ),
                      ),
                      Text(
                        _getStepTitle(_currentStep),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ResQTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: ResQTheme.lightBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(ResQTheme.primaryCrimson),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Page View Form Deck
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentStep = index);
                },
                children: [
                  _buildStep1AccountCredentials(),
                  _buildStep2Demographics(),
                  _buildStep3HealthScreening(),
                  _buildStep4SummaryReview(),
                ],
              ),
            ),

            // Bottom Navigation Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ResQTheme.primaryCrimson,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _currentStep == _totalSteps - 1 ? 'COMPLETE REGISTRATION' : 'CONTINUE',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Account Info';
      case 1:
        return 'Demographics';
      case 2:
        return 'Health Screening';
      case 3:
        return 'Confirmation';
      default:
        return '';
    }
  }

  // --- Step 1: Account Info ---
  Widget _buildStep1AccountCredentials() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create Your Account', style: ResQTheme.heading1.copyWith(fontSize: 20)),
          const SizedBox(height: 4),
          Text('Enter your credentials to register on ResQ', style: TextStyle(color: ResQTheme.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          _buildTextField('Full Name', 'e.g., Juan Cruz', _fullNameController, Icons.person_outline),
          const SizedBox(height: 16),
          _buildTextField('Email Address', 'donor@resq.ph', _emailController, Icons.email_outlined, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _buildTextField('Mobile Number', '09123456789', _phoneController, Icons.phone_outlined, keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          _buildTextField('Password', '••••••••', _passwordController, Icons.lock_outline, obscureText: _obscurePassword, isPassword: true),
        ],
      ),
    );
  }

  // --- Step 2: Demographics & Blood Type ---
  Widget _buildStep2Demographics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Donor Demographics', style: ResQTheme.heading1.copyWith(fontSize: 20)),
          const SizedBox(height: 4),
          Text('Select your blood group and baseline physical parameters', style: TextStyle(color: ResQTheme.textMuted, fontSize: 13)),
          const SizedBox(height: 20),

          // Blood Type Selector Grid
          const Text('Select Blood Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1.4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _bloodTypes.length,
            itemBuilder: (context, index) {
              final type = _bloodTypes[index];
              final isSelected = type == _selectedBloodType;
              return InkWell(
                onTap: () => setState(() => _selectedBloodType = type),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? ResQTheme.primaryCrimson : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? ResQTheme.primaryCrimson : ResQTheme.lightBorder,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      type,
                      style: TextStyle(
                        color: isSelected ? Colors.white : ResQTheme.textDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // Gender Selection
          const Text('Biological Sex', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Male')),
                  selected: _selectedGender == BioSex.male,
                  selectedColor: ResQTheme.primaryCrimson,
                  labelStyle: TextStyle(color: _selectedGender == BioSex.male ? Colors.white : ResQTheme.textDark, fontWeight: FontWeight.bold),
                  onSelected: (val) => setState(() => _selectedGender = BioSex.male),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Female')),
                  selected: _selectedGender == BioSex.female,
                  selectedColor: ResQTheme.primaryCrimson,
                  labelStyle: TextStyle(color: _selectedGender == BioSex.female ? Colors.white : ResQTheme.textDark, fontWeight: FontWeight.bold),
                  onSelected: (val) => setState(() => _selectedGender = BioSex.female),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildTextField('Age (years)', 'e.g., 21', _ageController, Icons.cake_outlined, keyboardType: TextInputType.number),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField('Weight (kg)', 'e.g., 55', _weightController, Icons.scale_outlined, keyboardType: TextInputType.number),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Step 3: Dynamic Gender-Specific Health Screening ---
  Widget _buildStep3HealthScreening() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Clinical Screening', style: ResQTheme.heading1.copyWith(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            _selectedGender == BioSex.female
                ? 'Maternal & Menstrual Health Parameters'
                : 'Clinical Risk & Exposure Parameters',
            style: TextStyle(color: ResQTheme.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 20),

          // General Screening Section
          SwitchListTile(
            title: const Text('First-Time Blood Donor?', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
            activeThumbColor: ResQTheme.primaryCrimson,
            value: _isFirstTimeDonor,
            onChanged: (val) => setState(() => _isFirstTimeDonor = val),
          ),
          const Divider(),

          SwitchListTile(
            title: const Text('Tattoo/piercing in the past 6 months?', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
            activeThumbColor: ResQTheme.primaryCrimson,
            value: _hasTattsOrPierce,
            onChanged: (val) => setState(() => _hasTattsOrPierce = val),
          ),
          const Divider(),

          SwitchListTile(
            title: const Text('Alcohol intake in the past 24 hours?', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
            activeThumbColor: ResQTheme.primaryCrimson,
            value: _hasAlcoholPast24hr,
            onChanged: (val) => setState(() => _hasAlcoholPast24hr = val),
          ),
          const Divider(),

          SwitchListTile(
            title: const Text('Active infection or ongoing medication?', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
            activeThumbColor: ResQTheme.primaryCrimson,
            value: _hasActiveInfectOrMeds,
            onChanged: (val) => setState(() => _hasActiveInfectOrMeds = val),
          ),
          const Divider(),

          // DYNAMIC BRANCHING BASED ON BIOSEX
          if (_selectedGender == BioSex.female) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ResQTheme.primaryCrimson.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ResQTheme.primaryCrimson.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Female Health Assessment',
                    style: TextStyle(color: ResQTheme.primaryCrimson, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Currently Pregnant or Nursing?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    activeThumbColor: ResQTheme.primaryCrimson,
                    value: _isPregOrNursing,
                    onChanged: (val) => setState(() => _isPregOrNursing = val),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Last Menstrual Period Date:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      TextButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().subtract(const Duration(days: 14)),
                            firstDate: DateTime.now().subtract(const Duration(days: 90)),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) setState(() => _lastMensPeriodDate = date);
                        },
                        icon: Icon(Icons.calendar_month, color: ResQTheme.primaryCrimson, size: 18),
                        label: Text(
                          _lastMensPeriodDate == null
                              ? 'Select Date'
                              : '${_lastMensPeriodDate!.month}/${_lastMensPeriodDate!.day}/${_lastMensPeriodDate!.year}',
                          style: TextStyle(color: ResQTheme.primaryCrimson, fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Clinical Risk Assessment',
                    style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('High-risk clinical exposure in past 12 months?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    activeThumbColor: Colors.blue,
                    value: _hasHighRiskExpo,
                    onChanged: (val) => setState(() => _hasHighRiskExpo = val),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Step 4: Summary Review with ScreenNPTModel Eligibility Evaluation ---
  Widget _buildStep4SummaryReview() {
    final screeningModel = _buildScreeningModel();
    final result = screeningModel.evaluateEligibility();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review Details', style: ResQTheme.heading1.copyWith(fontSize: 20)),
          const SizedBox(height: 4),
          Text('Confirm your information before finalizing registration', style: TextStyle(color: ResQTheme.textMuted, fontSize: 13)),
          const SizedBox(height: 16),

          // SCREEN NPT MODEL EVALUATION BANNER
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: result.isEligible ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: result.isEligible ? const Color(0xFFA5D6A7) : const Color(0xFFFFCC80),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  result.isEligible ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  color: result.isEligible ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Eligibility Evaluation: ${EligibilityRules.getStatsTitle(result.status)}',
                        style: TextStyle(
                          color: result.isEligible ? const Color(0xFF1B5E20) : const Color(0xFFE65100),
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        EligibilityRules.getStatsDesc(result),
                        style: TextStyle(
                          color: result.isEligible ? const Color(0xFF388E3C) : const Color(0xFFF57C00),
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ResQTheme.lightBorder),
            ),
            child: Column(
              children: [
                _buildSummaryRow('Full Name', _fullNameController.text.isEmpty ? 'Juan Cruz' : _fullNameController.text),
                const Divider(height: 20),
                _buildSummaryRow('Blood Type', _selectedBloodType),
                const Divider(height: 20),
                _buildSummaryRow('Biological Sex', _selectedGender == BioSex.male ? 'Male' : 'Female'),
                const Divider(height: 20),
                _buildSummaryRow(
                  'Age / Weight',
                  '${_ageController.text.isEmpty ? '0' : _ageController.text} yrs / ${_weightController.text.isEmpty ? '0' : _weightController.text} kg',
                ),
                const Divider(height: 20),
                _buildSummaryRow('Donor History', _isFirstTimeDonor ? 'First-Time Donor' : 'Recurring Donor'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: ResQTheme.textMuted, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
      ],
    );
  }

  Widget _buildTextField(
      String label,
      String hint,
      TextEditingController controller,
      IconData icon, {
        TextInputType keyboardType = TextInputType.text,
        bool obscureText = false,
        bool isPassword = false,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: ResQTheme.textDark)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(fontSize: 13.5),
          onChanged: (_) {
            if (_currentStep == 3) setState(() {});
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12.5),
            prefixIcon: Icon(icon, color: ResQTheme.primaryCrimson, size: 20),
            suffixIcon: isPassword
                ? IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            )
                : null,
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ResQTheme.lightBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ResQTheme.lightBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ResQTheme.primaryCrimson, width: 1.5)),
          ),
        ),
      ],
    );
  }
}