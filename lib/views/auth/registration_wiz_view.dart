import 'package:flutter/material.dart';
import 'package:resq/model/screening_input_model.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/utils/constants/theme_constants.dart';
import 'package:resq/views/auth/otp_ver_view.dart';

class RegistrationWizView extends StatefulWidget {
  final bool isRetake;
  final ScreenNPTModel? initialScreening;
  final String donorName;
  final String bloodType;
  final String donorId;
  final Function(ScreenNPTModel updatedModel, ClassificationResult result)? onRetakeCompleted;

  const RegistrationWizView({
    super.key,
    this.isRetake = false,
    this.initialScreening,
    this.donorName = '',
    this.bloodType = '',
    this.donorId = '',
    this.onRetakeCompleted,
  });

  @override
  State<RegistrationWizView> createState() => _RegistrationWizViewState();
}

class _RegistrationWizViewState extends State<RegistrationWizView> {
  late PageController _pageController;
  late int _currentStep;
  late int _totalSteps;

  // STEP 1: Account Credentials
  late final TextEditingController _fullNameController;
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // STEP 2: Physical Metrics
  String _selectedBloodType = '';
  DateTime? _dob;
  BioSex _selectedGender = BioSex.male;
  final _weightController = TextEditingController();
  DateTime? _lastDonationDate;
  bool _isFirstTimeDonating = true;
  bool _hasTattoosOrPiercings = false;
  DateTime? _lastTattooDate;

  // STEP 3: Final Screening (Female)
  DateTime? _lastMensDate;
  String _pregnancyStatus = 'Not currently pregnant';
  bool _isBreastfeeding = false;
  bool _femaleRecentSexualRisk = false;

  // STEP 3: Final Screening (Male)
  bool _maleStiHistory = false;
  bool _maleHighRiskContact = false;
  String _msmHistory = 'Never had sex with a man';
  bool _maleRecentSexualRisk = false;

  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    _currentStep = widget.isRetake ? 1 : 0;
    _totalSteps = 3;
    _pageController = PageController(initialPage: _currentStep);

    _fullNameController = TextEditingController(text: widget.donorName);
    _selectedBloodType = widget.bloodType;

    if (widget.initialScreening != null) {
      final prev = widget.initialScreening!.screensNPT;
      _selectedGender = prev.gender;
      _weightController.text = prev.weight > 0 ? prev.weight.toStringAsFixed(1) : '';
      _isFirstTimeDonating = prev.isFirstTimeDonor;
      _lastDonationDate = prev.lastDonationDate;
      _hasTattoosOrPiercings = prev.hasTattsOrPierce;
      _lastMensDate = prev.lastMensPeriodDate;
      _isBreastfeeding = prev.isPregOrNursing ?? false;
      _maleHighRiskContact = prev.hasHighRiskExpo ?? false;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  int get _calculatedAge {
    if (_dob == null) return widget.initialScreening?.screensNPT.age ?? 21;
    final now = DateTime.now();
    int age = now.year - _dob!.year;
    if (now.month < _dob!.month || (now.month == _dob!.month && now.day < _dob!.day)) {
      age--;
    }
    return age;
  }

  void _nextPage() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submitRegistrationOrRetake();
    }
  }

  void _previousPage() {
    final int minStep = widget.isRetake ? 1 : 0;
    if (_currentStep > minStep) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _submitRegistrationOrRetake() {
    final double weight = double.tryParse(_weightController.text.trim()) ?? 0.0;

    final donorScreens = DonorScreensNPT(
      gender: _selectedGender,
      weight: weight,
      age: _calculatedAge,
      isFirstTimeDonor: _isFirstTimeDonating,
      lastDonationDate: _isFirstTimeDonating ? null : _lastDonationDate,
      hasTattsOrPierce: _hasTattoosOrPiercings,
      hasAlcoholPast24hr: false,
      hasActiveInfectOrMeds: _selectedGender == BioSex.male ? _maleStiHistory : false,
      isPregOrNursing: _selectedGender == BioSex.female
          ? (_pregnancyStatus != 'Not currently pregnant' || _isBreastfeeding)
          : null,
      lastMensPeriodDate: _selectedGender == BioSex.female ? _lastMensDate : null,
      hasHighRiskExpo: _selectedGender == BioSex.male
          ? (_maleHighRiskContact || _maleRecentSexualRisk || _msmHistory == 'Recent contact within 3 months')
          : _femaleRecentSexualRisk,
    );

    final screeningModel = ScreenNPTModel(
      donorProfId: widget.initialScreening?.donorProfId ?? 'donor_${DateTime.now().millisecondsSinceEpoch}',
      screensNPT: donorScreens,
      submissionDate: DateTime.now(),
    );

    final classificationResult = screeningModel.evaluateEligibility();

    if (widget.isRetake) {
      Navigator.of(context).pop();
      if (widget.onRetakeCompleted != null) {
        widget.onRetakeCompleted!(screeningModel, classificationResult);
      }
      return;
    }

    final String chosenBloodType = (_selectedBloodType.isEmpty || _selectedBloodType == "I'm not sure")
        ? 'Unknown'
        : _selectedBloodType;

    final String generatedDonorId =
        'RESQ-PH-${DateTime.now().year}-${(DateTime.now().millisecondsSinceEpoch % 100000).toString().padLeft(5, '0')}';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OtpVerView(
          phoneNumber: _phoneController.text.trim().isEmpty ? '09123456789' : _phoneController.text.trim(),
          email: _emailController.text.trim().isEmpty ? 'donor@resq.ph' : _emailController.text.trim(),
          donorName: _fullNameController.text.trim().isEmpty ? 'Volunteer Donor' : _fullNameController.text.trim(),
          bloodType: chosenBloodType,
          donorId: generatedDonorId,
          screeningModel: screeningModel,
          classificationResult: classificationResult,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ResQTheme.bgOffWhite,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _currentStep = i),
        children: [
          _buildStep1Account(),
          _buildStep2PhysicalMetrics(),
          _buildStep3FinalScreening(),
        ],
      ),
    );
  }

  // ===========================================================================
  // STEP 1: Account Creation
  // ===========================================================================
  Widget _buildStep1Account() {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(color: Color(0xFF7D2229), shape: BoxShape.circle),
              child: Center(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                    children: [
                      TextSpan(text: 'R'),
                      TextSpan(text: 'Q', style: TextStyle(color: Color(0xFFFFA726))),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Create Your Account', style: ResQTheme.heading1.copyWith(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Join our community of lifesaving donors.', style: TextStyle(color: ResQTheme.textMuted, fontSize: 13)),
            const SizedBox(height: 24),

            _buildCustomInput(controller: _fullNameController, hint: 'Full Name', icon: Icons.person_outline_rounded),
            const SizedBox(height: 14),
            _buildCustomInput(controller: _emailController, hint: 'Email', icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 14),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF7D2229), width: 1.2),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Text('🇵🇭 +63', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  const Icon(Icons.arrow_drop_down, color: Colors.black54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 13.5),
                      decoration: const InputDecoration(
                        hintText: 'Phone Number',
                        hintStyle: TextStyle(color: Colors.black38, fontSize: 13.5),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_outline, color: Color(0xFF7D2229), size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "We'll send a 6-digit verification code via SMS to this number. Standard rates may apply.",
                    style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _buildCustomInput(
              controller: _passwordController,
              hint: 'Password',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Must be at least 8 characters with a number & symbol.', style: TextStyle(fontSize: 10.5, color: Colors.black54)),
            ),
            const SizedBox(height: 14),

            _buildCustomInput(
              controller: _confirmPasswordController,
              hint: 'Confirm Password',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscureConfirmPassword,
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF7D2229).withValues(alpha: 0.5), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7D2229).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFF7D2229), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Privacy Guaranteed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF7D2229))),
                        SizedBox(height: 2),
                        Text(
                          'Your data is encrypted and strictly used for medical eligibility checks within our secure network',
                          style: TextStyle(fontSize: 10.5, color: Colors.black54, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Already have an account? ', style: TextStyle(fontSize: 12, color: Colors.black54)),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Text('Log In', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7D2229))),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7D2229),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('Continue to Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // STEP 2: Physical Metrics
  // ===========================================================================
  Widget _buildStep2PhysicalMetrics() {
    return Column(
      children: [
        _buildCurvedHeader(widget.isRetake ? 'Retake Physical Metrics' : 'Physical Metrics'),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.isRetake ? 'Update Physical Metrics' : 'Physical Metrics', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  'Please provide your basic physical information to help us determine your donation eligibility.',
                  style: TextStyle(color: Colors.black54, fontSize: 12.5),
                ),
                const SizedBox(height: 20),

                const Text('Blood Type Selection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                const SizedBox(height: 2),
                const Text("Select your blood type if known. Otherwise, choose \"I'm not sure\".", style: TextStyle(color: Colors.black54, fontSize: 11.5)),
                const SizedBox(height: 12),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 1.3,
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
                          color: isSelected ? const Color(0xFF7D2229) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF7D2229), width: 1.2),
                        ),
                        child: Center(
                          child: Text(
                            type,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF7D2229),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),

                InkWell(
                  onTap: () => setState(() => _selectedBloodType = "I'm not sure"),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedBloodType == "I'm not sure" ? const Color(0xFF7D2229) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF7D2229), width: 1.2),
                    ),
                    child: Center(
                      child: Text(
                        "I'm not sure",
                        style: TextStyle(
                          color: _selectedBloodType == "I'm not sure" ? Colors.white : const Color(0xFF7D2229),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text('Date of Birth', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dob ?? DateTime(2003, 1, 1),
                      firstDate: DateTime(1950),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _dob = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7D2229),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _dob == null ? 'Date Picker' : '${_dob!.month}/${_dob!.day}/${_dob!.year}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const Icon(Icons.calendar_month, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text('Biological Sex', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6D3D1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedGender = BioSex.female),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedGender == BioSex.female ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'Female',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedGender == BioSex.female ? Colors.black87 : Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedGender = BioSex.male),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedGender == BioSex.male ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'Male',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedGender == BioSex.male ? Colors.black87 : Colors.black54,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                const Text('Weight (kg)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                const SizedBox(height: 8),
                _buildCustomInput(
                  controller: _weightController,
                  hint: 'Enter your weight here',
                  icon: Icons.scale_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),

                const Text('Last Blood Donation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                const SizedBox(height: 8),
                if (!_isFirstTimeDonating) ...[
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _lastDonationDate ?? DateTime.now().subtract(const Duration(days: 95)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _lastDonationDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7D2229),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _lastDonationDate == null
                                ? 'Date Picker'
                                : '${_lastDonationDate!.month}/${_lastDonationDate!.day}/${_lastDonationDate!.year}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const Icon(Icons.calendar_month, color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Row(
                  children: [
                    Checkbox(
                      value: _isFirstTimeDonating,
                      activeColor: const Color(0xFF7D2229),
                      onChanged: (val) => setState(() => _isFirstTimeDonating = val ?? true),
                    ),
                    const Text('First time donating.', style: TextStyle(fontSize: 13, color: Colors.black87)),
                  ],
                ),
                const SizedBox(height: 16),

                const Text('Recent Procedures', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                const SizedBox(height: 10),
                _buildCardSelection(
                  title: 'No Tattoos or Piercings',
                  icon: Icons.radio_button_unchecked,
                  isSelected: !_hasTattoosOrPiercings,
                  onTap: () => setState(() => _hasTattoosOrPiercings = false),
                ),
                const SizedBox(height: 8),
                _buildCardSelection(
                  title: 'Yes, I have Tattoos / Piercings',
                  icon: Icons.edit_outlined,
                  isSelected: _hasTattoosOrPiercings,
                  onTap: () => setState(() => _hasTattoosOrPiercings = true),
                ),

                if (_hasTattoosOrPiercings) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F1FC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.info_outline, color: Color(0xFF1976D2), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Standard deferral period is 6 months to 12 months. Please provide the date of your last procedure for verification',
                            style: TextStyle(color: Color(0xFF1976D2), fontSize: 11.5, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Date of Last Tattoo / Piercing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _lastTattooDate ?? DateTime.now().subtract(const Duration(days: 190)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _lastTattooDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7D2229),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _lastTattooDate == null
                                ? 'dd/mm/yyyy'
                                : '${_lastTattooDate!.day}/${_lastTattooDate!.month}/${_lastTattooDate!.year}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const Icon(Icons.calendar_month, color: Colors.white, size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7D2229),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('CONTINUE TO FINAL SCREENING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // STEP 3: Final Screening
  // ===========================================================================
  Widget _buildStep3FinalScreening() {
    return Column(
      children: [
        _buildCurvedHeader(widget.isRetake ? 'Retake Final Screening' : 'Final Screening'),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Final Screening', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Additional questions based on the biological sex.', style: TextStyle(color: Colors.black54, fontSize: 12.5)),
                const SizedBox(height: 16),

                if (_selectedGender == BioSex.female) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9E6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'If you are currently pregnant or nursing, your donation will be temporarily deferred.',
                            style: TextStyle(color: Color(0xFFE65100), fontSize: 12, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Date of Last Menstrual Period', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _lastMensDate ?? DateTime.now().subtract(const Duration(days: 14)),
                        firstDate: DateTime(2023),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _lastMensDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _lastMensDate == null
                            ? 'mm/dd/yyyy'
                            : '${_lastMensDate!.month}/${_lastMensDate!.day}/${_lastMensDate!.year}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Pregnancy Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  _buildCardSelection(
                    title: 'Not currently pregnant',
                    icon: Icons.circle_outlined,
                    isSelected: _pregnancyStatus == 'Not currently pregnant',
                    onTap: () => setState(() => _pregnancyStatus = 'Not currently pregnant'),
                  ),
                  const SizedBox(height: 6),
                  _buildCardSelection(
                    title: 'Currently pregnant',
                    icon: Icons.circle_outlined,
                    isSelected: _pregnancyStatus == 'Currently pregnant',
                    onTap: () => setState(() => _pregnancyStatus = 'Currently pregnant'),
                  ),
                  const SizedBox(height: 6),
                  _buildCardSelection(
                    title: 'Pregnant within last 6 weeks',
                    icon: Icons.circle_outlined,
                    isSelected: _pregnancyStatus == 'Pregnant within last 6 weeks',
                    onTap: () => setState(() => _pregnancyStatus = 'Pregnant within last 6 weeks'),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Currently Breastfeeding', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            Text('Toggle if nursing a child', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                        Switch(
                          value: _isBreastfeeding,
                          activeColor: const Color(0xFF7D2229),
                          onChanged: (val) => setState(() => _isBreastfeeding = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Recent Sexual Risk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ResQTheme.lightBorder),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _femaleRecentSexualRisk,
                          activeColor: const Color(0xFF7D2229),
                          onChanged: (val) => setState(() => _femaleRecentSexualRisk = val ?? false),
                        ),
                        const Expanded(
                          child: Text(
                            'I have had a new sexual partner or multiple partners in the last 3 months.',
                            style: TextStyle(fontSize: 11.5, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Text('History of STI/STD (Last 12 mos)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCardSelection(
                          title: 'Yes',
                          icon: Icons.circle_outlined,
                          isSelected: _maleStiHistory,
                          onTap: () => setState(() => _maleStiHistory = true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildCardSelection(
                          title: 'No',
                          icon: Icons.circle_outlined,
                          isSelected: !_maleStiHistory,
                          onTap: () => setState(() => _maleStiHistory = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text('High-Risk Sexual Contact (Last 12 mos)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Have you had sexual contact with anyone who has ever had a positive HIV test or used needles for non-prescription drugs?',
                          style: TextStyle(fontSize: 11.5, color: Colors.black87, height: 1.35),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildCardSelection(
                                title: 'Yes',
                                icon: Icons.circle_outlined,
                                isSelected: _maleHighRiskContact,
                                onTap: () => setState(() => _maleHighRiskContact = true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildCardSelection(
                                title: 'No',
                                icon: Icons.circle_outlined,
                                isSelected: !_maleHighRiskContact,
                                onTap: () => setState(() => _maleHighRiskContact = false),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('MSM History (Men who have sex with men)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  _buildCardSelection(
                    title: 'Never had sex with a man',
                    icon: Icons.circle_outlined,
                    isSelected: _msmHistory == 'Never had sex with a man',
                    onTap: () => setState(() => _msmHistory = 'Never had sex with a man'),
                  ),
                  const SizedBox(height: 6),
                  _buildCardSelection(
                    title: 'Last contact over 3 months ago',
                    icon: Icons.circle_outlined,
                    isSelected: _msmHistory == 'Last contact over 3 months ago',
                    onTap: () => setState(() => _msmHistory = 'Last contact over 3 months ago'),
                  ),
                  const SizedBox(height: 6),
                  _buildCardSelection(
                    title: 'Recent contact within 3 months',
                    icon: Icons.circle_outlined,
                    isSelected: _msmHistory == 'Recent contact within 3 months',
                    onTap: () => setState(() => _msmHistory = 'Recent contact within 3 months'),
                  ),
                  const SizedBox(height: 16),

                  const Text('Recent Sexual Risk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ResQTheme.lightBorder),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _maleRecentSexualRisk,
                          activeColor: const Color(0xFF7D2229),
                          onChanged: (val) => setState(() => _maleRecentSexualRisk = val ?? false),
                        ),
                        const Expanded(
                          child: Text(
                            'I have had a new sexual partner or multiple partners in the last 3 months.',
                            style: TextStyle(fontSize: 11.5, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ResQTheme.lightBorder),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(color: Color(0xFF7D2229), shape: BoxShape.circle),
                        child: const Icon(Icons.shield_outlined, color: Colors.white, size: 24),
                      ),
                      const SizedBox(height: 8),
                      Text(widget.isRetake ? 'Update Assessment' : 'Almost Ready', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                      const SizedBox(height: 4),
                      Text(
                        widget.isRetake
                            ? 'Submitting these updated details will re-evaluate your donor eligibility status in real-time.'
                            : 'Completing this registration will book your appointment slot at the Downtown Clinical Center.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11.5, color: Colors.black54, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submitRegistrationOrRetake,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7D2229),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      widget.isRetake ? 'EVALUATE ELIGIBILITY' : 'COMPLETE REGISTRATION',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Helpers ---
  Widget _buildCurvedHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 48, bottom: 20, left: 24, right: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF7D2229),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            onPressed: _previousPage,
          ),
          const SizedBox(width: 8),
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              children: [
                TextSpan(text: 'R'),
                TextSpan(text: 'Q', style: TextStyle(color: Color(0xFFFFA726))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 1.5, height: 24, color: Colors.white70),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Connect, Save Lives, On time.', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(fontSize: 13.5),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 13.5),
        prefixIcon: Icon(icon, color: const Color(0xFF7D2229), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7D2229), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7D2229), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7D2229), width: 1.8),
        ),
      ),
    );
  }

  Widget _buildCardSelection({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF7D2229) : ResQTheme.lightBorder,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : icon,
              size: 18,
              color: isSelected ? const Color(0xFF7D2229) : Colors.grey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF7D2229) : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}