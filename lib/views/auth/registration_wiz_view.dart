import 'package:flutter/material.dart';
import 'package:resq/model/screening_input_model.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/utils/constants/theme_constants.dart';
import 'package:resq/views/auth/login_view.dart';
import 'package:resq/views/home/home_view.dart';
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
  int _currentStep = 1;
  final int _totalSteps = 4;
  bool _isLoading = false;

  // Step 1: Account Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  // Step 2: Physical & Health Controllers
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _lastDonationController = TextEditingController();

  // Mutable state variables for wizard evaluation
  BioSex _gender = BioSex.male;
  bool _isFirstTimeDonor = true;
  DateTime? _lastDonationDate;
  int _totalDonations = 0;
  bool _hasActiveInfectOrMeds = false;
  bool _hasAlcoholPast24hr = false;
  bool _hasTattsOrPierce = false;
  bool _isPregOrNursing = false;
  bool _hasRecentTravelRisk = false;

  @override
  void initState() {
    super.initState();
    if (widget.isRetake && widget.initialScreening != null) {
      final initial = widget.initialScreening!.screensNPT;
      _currentStep = 2; // Skip account creation on retake
      _nameController.text = widget.donorName ?? '';
      _ageController.text = initial.age > 0 ? initial.age.toString() : '';
      _weightController.text = initial.weight > 0 ? initial.weight.toString() : '';
      _gender = initial.gender;
      _isFirstTimeDonor = initial.isFirstTimeDonor;
      _lastDonationDate = initial.lastDonationDate;
      _totalDonations = initial.totalDonations;
      _hasActiveInfectOrMeds = initial.hasActiveInfectOrMeds;
      _hasAlcoholPast24hr = initial.hasAlcoholPast24hr;
      _hasTattsOrPierce = initial.hasTattsOrPierce;
      _isPregOrNursing = initial.isPregOrNursing ?? false;

      if (_lastDonationDate != null) {
        _lastDonationController.text =
        "${_lastDonationDate!.year}-${_lastDonationDate!.month.toString().padLeft(2, '0')}-${_lastDonationDate!.day.toString().padLeft(2, '0')}";
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _lastDonationController.dispose();
    super.dispose();
  }

  // --- Date Picker & Donation Count Popup ---
  Future<void> _selectLastDonationDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _lastDonationDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7D1B22),
              onPrimary: Colors.white,
              onSurface: ResQTheme.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _lastDonationDate = picked;
        _isFirstTimeDonor = false;
        _lastDonationController.text =
        "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
      if (!mounted) return;
      await _promptForDonationCount(context);
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
              const SizedBox(height: 16),
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
                  setState(() {
                    _totalDonations = count;
                  });
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid number (0 or higher).')),
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
      if (_nameController.text.trim().isEmpty ||
          _emailController.text.trim().isEmpty ||
          _passwordController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please complete all account fields.')),
        );
        return false;
      }
    } else if (_currentStep == 2) {
      final age = int.tryParse(_ageController.text.trim()) ?? 0;
      final weight = double.tryParse(_weightController.text.trim()) ?? 0.0;
      if (age <= 0 || weight <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid age and weight.')),
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

  Future<void> _finishAssessment() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1000));

    final int age = int.tryParse(_ageController.text.trim()) ?? 21;
    final double weight = double.tryParse(_weightController.text.trim()) ?? 55.0;

    final DonorScreensNPT evaluatedParams = DonorScreensNPT(
      age: age,
      weight: weight,
      gender: _gender,
      isFirstTimeDonor: _isFirstTimeDonor,
      lastDonationDate: _lastDonationDate,
      totalDonations: _isFirstTimeDonor ? 0 : _totalDonations,
      hasActiveInfectOrMeds: _hasActiveInfectOrMeds,
      hasAlcoholPast24hr: _hasAlcoholPast24hr,
      hasTattsOrPierce: _hasTattsOrPierce,
      isPregOrNursing: _gender == BioSex.female ? _isPregOrNursing : null,
    );

    final String assignedDonorId = widget.donorId ?? 'BD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final String activeDonorName = widget.isRetake
        ? (widget.donorName ?? 'Donor')
        : (_nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Donor');
    final String activeBloodType = widget.bloodType ?? 'O+';

    final ScreenNPTModel finalModel = ScreenNPTModel(
      donorProfId: assignedDonorId,
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
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => HomeView(
            donorName: activeDonorName,
            bloodType: activeBloodType,
            donorId: assignedDonorId,
            screeningModel: finalModel,
            classificationResult: result,
            isFirstTimeDonor: _isFirstTimeDonor,
          ),
        ),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7D1B22),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () {
            if (_currentStep > 1 && !(widget.isRetake && _currentStep == 2)) {
              setState(() => _currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          widget.isRetake ? 'Retake Health Assessment' : 'Donor Registration ($currentStepTitle)',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF7D1B22)))
            : SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressBar(),
              const SizedBox(height: 20),
              _buildCurrentStepContent(),
              const SizedBox(height: 26),
              _buildActionButtons(),
              if (!widget.isRetake && _currentStep == 1) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? ', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    InkWell(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginView()),
                        );
                      },
                      child: const Text(
                        'Log In',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7D1B22)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String get currentStepTitle {
    switch (_currentStep) {
      case 1:
        return 'Step 1 of 4: Account';
      case 2:
        return 'Step 2 of 4: Physical Metrics';
      case 3:
        return 'Step 3 of 4: Medical History';
      case 4:
        return 'Step 4 of 4: Lifestyle & Risk';
      default:
        return 'Assessment';
    }
  }

  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              currentStepTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF7D1B22)),
            ),
            Text(
              '${((_currentStep / _totalSteps) * 100).toInt()}%',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF7D1B22)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: _currentStep / _totalSteps,
          backgroundColor: Colors.grey.shade300,
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7D1B22)),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1Account();
      case 2:
        return _buildStep2Physical();
      case 3:
        return _buildStep3Medical();
      case 4:
        return _buildStep4Lifestyle();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1Account() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7D1B22), width: 1.2),
      ),
      child: Column(
        children: [
          CustomInputField(
            controller: _nameController,
            hintText: 'Full Name',
            labelText: 'Full Name',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 14),
          CustomInputField(
            controller: _emailController,
            hintText: 'donor@resq.ph',
            labelText: 'Email Address',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          CustomInputField(
            controller: _phoneController,
            hintText: '09123456789',
            labelText: 'Mobile Number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          CustomInputField(
            controller: _passwordController,
            hintText: '••••••••',
            labelText: 'Password',
            icon: Icons.lock_outline_rounded,
            obscureText: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Physical() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7D1B22), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Biological Sex', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Male')),
                  selected: _gender == BioSex.male,
                  selectedColor: const Color(0xFF7D1B22),
                  labelStyle: TextStyle(
                    color: _gender == BioSex.male ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (val) => setState(() => _gender = BioSex.male),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Female')),
                  selected: _gender == BioSex.female,
                  selectedColor: const Color(0xFF7D1B22),
                  labelStyle: TextStyle(
                    color: _gender == BioSex.female ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (val) => setState(() => _gender = BioSex.female),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CustomInputField(
                  controller: _ageController,
                  hintText: 'e.g. 21',
                  labelText: 'Age (yrs)',
                  icon: Icons.cake_outlined,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomInputField(
                  controller: _weightController,
                  hintText: 'e.g. 55.0',
                  labelText: 'Weight (kg)',
                  icon: Icons.monitor_weight_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          CustomInputField(
            controller: _lastDonationController,
            hintText: 'Tap to select last donation date',
            labelText: 'Last Donation Date (if applicable)',
            icon: Icons.calendar_month_rounded,
            readOnly: true,
            onTap: () => _selectLastDonationDate(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Medical() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7D1B22), width: 1.2),
      ),
      child: Column(
        children: [
          SwitchListTile(
            activeColor: const Color(0xFF7D1B22),
            contentPadding: EdgeInsets.zero,
            title: const Text('Active Infection or Contraindicated Meds', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text('Taking antibiotics or experiencing fever/cold/cough', style: TextStyle(fontSize: 11.5)),
            value: _hasActiveInfectOrMeds,
            onChanged: (val) => setState(() => _hasActiveInfectOrMeds = val),
          ),
          const Divider(),
          SwitchListTile(
            activeColor: const Color(0xFF7D1B22),
            contentPadding: EdgeInsets.zero,
            title: const Text('Alcohol Intake in Past 24 Hours', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text('Consumed alcoholic beverages within the last 24h', style: TextStyle(fontSize: 11.5)),
            value: _hasAlcoholPast24hr,
            onChanged: (val) => setState(() => _hasAlcoholPast24hr = val),
          ),
          if (_gender == BioSex.female) ...[
            const Divider(),
            SwitchListTile(
              activeColor: const Color(0xFF7D1B22),
              contentPadding: EdgeInsets.zero,
              title: const Text('Pregnancy / Lactation Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text('Currently pregnant, breastfeeding, or within 6 months postpartum', style: TextStyle(fontSize: 11.5)),
              value: _isPregOrNursing,
              onChanged: (val) => setState(() => _isPregOrNursing = val),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep4Lifestyle() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7D1B22), width: 1.2),
      ),
      child: Column(
        children: [
          SwitchListTile(
            activeColor: const Color(0xFF7D1B22),
            contentPadding: EdgeInsets.zero,
            title: const Text('Tattoos / Piercings within 12 Months', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text('New tattoo, body piercing, or microblading within past year', style: TextStyle(fontSize: 11.5)),
            value: _hasTattsOrPierce,
            onChanged: (val) => setState(() => _hasTattsOrPierce = val),
          ),
          const Divider(),
          SwitchListTile(
            activeColor: const Color(0xFF7D1B22),
            contentPadding: EdgeInsets.zero,
            title: const Text('Recent Travel to Endemic Areas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text('Travel to malaria-risk or infectious zones in the past 30 days', style: TextStyle(fontSize: 11.5)),
            value: _hasRecentTravelRisk,
            onChanged: (val) => setState(() => _hasRecentTravelRisk = val),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _nextStep,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7D1B22),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          _currentStep == _totalSteps ? 'SUBMIT & EVALUATE' : 'CONTINUE',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
        ),
      ),
    );
  }
}