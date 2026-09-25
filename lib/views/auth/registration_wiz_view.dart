import 'package:flutter/material.dart';
import 'package:resq/model/donor_profile_model.dart';
import 'package:resq/model/screening_input_model.dart';
import 'package:resq/model/user_model.dart';
import 'package:resq/services/api_service.dart';
import 'package:resq/utils/algo/decision_tree_class.dart';
import 'package:resq/views/auth/login_view.dart';
import 'package:resq/views/auth/med_history_details_view.dart';
import 'package:resq/views/auth/registration_summary_view.dart';
import 'package:resq/utils/helpers/responsive.dart';
import 'package:resq/widgets/editable_avatar.dart';
import 'package:resq/widgets/resq_ui.dart';

class RegistrationWizView extends StatefulWidget {
  final bool isRetake;
  final ScreenNPTModel? initialScreening;
  final String? donorName;
  final String bloodType;
  final String? donorId;
  final Function(ScreenNPTModel updatedModel, ClassificationResult result)? onRetakeCompleted;
  // Only meaningful (and only ever used) when isRetake is true — the
  // very first registration pass happens before a donor has a session
  // token at all, so this stays empty for that path.
  final String token;

  const RegistrationWizView({
    super.key,
    this.isRetake = false,
    this.initialScreening,
    this.donorName,
    this.bloodType = '',
    this.donorId,
    this.onRetakeCompleted,
    this.token = '',
  });

  @override
  State<RegistrationWizView> createState() => _RegistrationWizViewState();
}

class _RegistrationWizViewState extends State<RegistrationWizView> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 1;
  final int _totalSteps = 5;
  bool _isLoading = false;

  // Step 1: Account Controllers & Toggles
  final _nameController = TextEditingController();
  // Local file path of a photo picked during registration — no session
  // token exists yet to upload with (see EditableAvatar's mode split), so
  // this is only actually uploaded once _finishAssessment's account
  // creation succeeds and otp_ver_view.dart has a real token to use.
  String? _photoPath;
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
  // Retake-only stand-in for the Date of Birth picker — see _prefilledAge's
  // comment below for why a retake can't just re-show the real DOB picker.
  // Editable, so a donor whose age changed since last time can still update
  // it, but it starts filled with their real last-known age instead of
  // looking reset/blank the way the DOB picker did.
  final _ageController = TextEditingController();
  DateTime? _lastDonationDate;
  bool _isFirstTimeDonor = false;
  int _totalDonations = 0;
  bool _hasTattoosOrPiercings = false;
  DateTime? _tattooDate;

  // Step 3: Immediate Readiness State
  bool _feelsWellToday = true;
  bool _hasEatenRecently = true;
  bool _hasAlcoholPast24hr = false;

  // Step 4: Medical History & Risk Factors State
  static const List<String> _medProcedureOptions = [
    'Antibiotics',
    'Aspirin',
    'Vaccines',
    'Dental Work',
  ];
  final Set<String> _recentMedProcedures = {};
  // Date + dosage/reason collected per chip the instant it's checked (see
  // _promptMedProcedureDetail) — keyed by the same option name.
  final Map<String, MedProcedureDetail> _medProcedureDetails = {};
  bool _hasMajorMedicalHistory = false;
  // Collected on the follow-up question screen (see _openMedicalHistoryDetails)
  // when Major Medical History, Transfusion/Surgery, or Travel/Needle Stick
  // is toggled "yes" — no date for major medical history since no deferral
  // window applies to it (see decision_tree_class.dart).
  String? _majorMedicalHistoryDesc;
  bool _hasTransfusionOrSurgery = false;
  DateTime? _transfusionOrSurgeryDate;
  String? _transfusionOrSurgeryDesc;
  bool _hasTravelOrNeedleStick = false;
  DateTime? _travelOrNeedleDate;
  String? _travelOrNeedleDesc;

  // Step 5: Final Screening (Sex-Specific) State & Controllers
  DateTime? _lastMensDate;
  int _pregnancyStatusIndex = 0;
  bool _isBreastfeeding = false;

  bool _hasStiHistory = false;
  bool _hasHighRiskContact = false;
  int _msmHistoryIndex = 0;

  bool _hasRecentSexualRisk = false;
  bool _hasActiveInfectOrMeds = false;

  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    if (widget.isRetake) {
      // Always skip Step 1 on a retake, even if there's no prior screening
      // to pre-fill (e.g. a donor who logged into an existing account via
      // OTP and never actually went through complete-profile) — otherwise
      // this fell through to the "Create Account" UI, which is wrong and
      // confusing for someone whose account already exists.
      _currentStep = 2;
      _nameController.text = widget.donorName ?? '';
      _selectedBloodType = widget.bloodType.isNotEmpty ? widget.bloodType : 'O+';
      if (widget.initialScreening != null) {
        final initial = widget.initialScreening!.screensNPT;
        _weightController.text = initial.weight > 0 ? initial.weight.toString() : '';
        _gender = initial.gender;
        _isFirstTimeDonor = initial.isFirstTimeDonor;
        _lastDonationDate = initial.lastDonationDate;
        _totalDonations = initial.totalDonations;
        _hasTattoosOrPiercings = initial.hasTattsOrPierce;
        _tattooDate = initial.tattooDate;
        _hasActiveInfectOrMeds = initial.hasActiveInfectOrMeds;
        _hasAlcoholPast24hr = initial.hasAlcoholPast24hr;
        _feelsWellToday = initial.feelsWellToday;
        _hasEatenRecently = initial.hasEatenRecently;
        _recentMedProcedures.addAll(initial.recentMedProcedures);
        _medProcedureDetails.addAll(initial.medProcedureDetails);
        _hasMajorMedicalHistory = initial.hasMajorMedicalHistory;
        _majorMedicalHistoryDesc = initial.majorMedicalHistoryDesc;
        _hasTransfusionOrSurgery = initial.hasTransfusionOrSurgery;
        _transfusionOrSurgeryDate = initial.transfusionOrSurgeryDate;
        _transfusionOrSurgeryDesc = initial.transfusionOrSurgeryDesc;
        _hasTravelOrNeedleStick = initial.hasTravelOrNeedleStick;
        _travelOrNeedleDate = initial.travelOrNeedleDate;
        _travelOrNeedleDesc = initial.travelOrNeedleDesc;
        _lastMensDate = initial.lastMensPeriodDate;
        _hasHighRiskContact = initial.hasHighRiskExpo ?? false;
        if (initial.isPregOrNursing == true) {
          _pregnancyStatusIndex = 1;
          _isBreastfeeding = true;
        }
        _ageController.text = _prefilledAge != null ? _prefilledAge.toString() : '';
      }
      // else: no prior screening data at all — Step 2 onward just starts
      // blank/default, so the donor fills it in for the first time instead
      // of being bounced to account creation.
    }
  }

  // Real last-known age from the donor's prior screening, used as the
  // starting value for the retake-only Age field (see initState) and as
  // the fallback in _finishAssessment if the donor leaves that field
  // untouched or clears it. Guards against a stray non-positive value
  // from the backend rather than prefilling with garbage.
  int? get _prefilledAge {
    final age = widget.initialScreening?.screensNPT.age;
    return (age != null && age > 0) ? age : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select a date';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
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
              primary: RQColors.blood,
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

  /// Lifetime donation count — a bottom sheet with a −/+ counter and quick
  /// picks, shown right after the donor picks their last donation date (and
  /// from the "Edit" link under it).
  Future<void> _promptForDonationCount(BuildContext context) async {
    int count = _totalDonations > 0 ? _totalDonations : 1;
    const quick = [1, 2, 3, 4, 5, 10];

    await showResQSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return ResQSheet(
            icon: Icons.history_rounded,
            title: 'Lifetime donations',
            subtitle: 'How many times have you given blood in total?',
            footer: Row(
              children: [
                Expanded(child: RQButton.secondary(label: 'Skip', onPressed: () => Navigator.pop(ctx))),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: RQButton(
                    label: 'Save',
                    onPressed: () {
                      setState(() => _totalDonations = count);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _roundStepButton(
                      icon: Icons.remove_rounded,
                      tooltip: 'Decrease',
                      filled: false,
                      onTap: count > 1 ? () => setSheet(() => count--) : null,
                    ),
                    SizedBox(
                      width: 120,
                      child: Column(
                        children: [
                          Text('$count',
                              style: const TextStyle(
                                  fontSize: 56, height: 1.1, fontWeight: FontWeight.w700, color: RQColors.bloodText)),
                          Text(count == 1 ? 'donation' : 'donations',
                              style: const TextStyle(fontSize: 13, color: RQColors.muted)),
                        ],
                      ),
                    ),
                    _roundStepButton(
                      icon: Icons.add_rounded,
                      tooltip: 'Increase',
                      filled: true,
                      onTap: count < 300 ? () => setSheet(() => count++) : null,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final q in quick)
                      _choiceChip(
                        label: q == 10 ? '10+' : '$q',
                        selected: count == q,
                        onTap: () => setSheet(() => count = q),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _noteBox(
                  Icons.info_outline_rounded,
                  'Count every donation, including those before ResQ. New donations are added for you automatically.',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _roundStepButton({
    required IconData icon,
    required String tooltip,
    required bool filled,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: 56,
      height: 56,
      child: filled
          ? IconButton.filled(
              onPressed: onTap,
              tooltip: tooltip,
              style: IconButton.styleFrom(
                backgroundColor: RQColors.blood,
                foregroundColor: Colors.white,
                disabledBackgroundColor: RQColors.hairline,
              ),
              icon: Icon(icon),
            )
          : IconButton.outlined(
              onPressed: onTap,
              tooltip: tooltip,
              style: IconButton.styleFrom(
                foregroundColor: RQColors.ink,
                side: const BorderSide(color: RQColors.hairline, width: 1.5),
              ),
              icon: Icon(icon),
            ),
    );
  }

  /// Instant follow-up sheet shown the moment a donor taps one of the
  /// "recent meds/procedures" tiles (Antibiotics, Aspirin, Vaccines, Dental
  /// Work) — collects when it happened and the dosage/reason so the
  /// decision tree can judge the 4-week window against a real date instead
  /// of deferring forever. Confirming checks the tile; tapping an already
  /// checked tile reopens this with a "Remove" option.
  Future<void> _promptMedProcedureDetail(String option) async {
    final bool editing = _recentMedProcedures.contains(option);
    DateTime? pickedDate = _medProcedureDetails[option]?.date;
    final reasonController = TextEditingController(text: _medProcedureDetails[option]?.dosageOrReason ?? '');
    String? error;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final earliest = today.subtract(const Duration(days: 90));
    const quick = <List<Object>>[
      ['Today', 0],
      ['1 week ago', 7],
      ['2 weeks ago', 14],
      ['3 weeks ago', 21],
    ];

    await showResQSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          return ResQSheet(
            icon: _medIcon(option),
            title: option,
            subtitle: 'Tell us when you last took or had it',
            footer: Row(
              children: [
                Expanded(
                  child: RQButton.secondary(
                    label: editing ? 'Remove' : 'Cancel',
                    color: editing ? RQColors.blood : null,
                    onPressed: () {
                      if (editing) {
                        setState(() {
                          _recentMedProcedures.remove(option);
                          _medProcedureDetails.remove(option);
                        });
                      }
                      Navigator.pop(ctx);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: RQButton(
                    label: 'Confirm',
                    onPressed: () {
                      if (pickedDate == null) {
                        setSheet(() => error = 'Please choose when you last took or had it.');
                        return;
                      }
                      final reason = reasonController.text.trim();
                      setState(() {
                        _recentMedProcedures.add(option);
                        _medProcedureDetails[option] = MedProcedureDetail(
                          date: pickedDate,
                          dosageOrReason: reason.isEmpty ? null : reason,
                        );
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const RQSectionLabel('When was your last dose?'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final q in quick)
                      _choiceChip(
                        label: q[0] as String,
                        selected: pickedDate != null &&
                            _sameDay(pickedDate!, today.subtract(Duration(days: q[1] as int))),
                        onTap: () => setSheet(() {
                          pickedDate = today.subtract(Duration(days: q[1] as int));
                          error = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _dateField(
                  label: 'Exact date',
                  value: pickedDate,
                  onTap: () async {
                    final initial = (pickedDate != null && !pickedDate!.isBefore(earliest)) ? pickedDate! : today;
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: initial,
                      firstDate: earliest,
                      lastDate: today,
                      builder: _datePickerTheme,
                    );
                    if (picked != null) {
                      setSheet(() {
                        pickedDate = picked;
                        error = null;
                      });
                    }
                  },
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C))),
                ],
                const SizedBox(height: 18),
                const RQSectionLabel('Dosage or reason (optional)'),
                const SizedBox(height: 10),
                RQTextField(controller: reasonController, label: 'e.g. 500mg twice a day / tooth extraction'),
                const SizedBox(height: 16),
                _noteBox(Icons.info_outline_rounded, 'We use this date to check the 4-week waiting window.'),
              ],
            ),
          );
        },
      ),
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
    if (_currentStep == 4 &&
        (_hasMajorMedicalHistory || _hasTransfusionOrSurgery || _hasTravelOrNeedleStick)) {
      // Toggled "yes" on at least one Medical History / Risk Factor
      // question — collect the follow-up details on a dedicated screen
      // before moving on, instead of proceeding straight to Final
      // Screening with no way to judge deferral windows against a date.
      _openMedicalHistoryDetails();
      return;
    }
    if (_currentStep < _totalSteps) {
      setState(() => _currentStep++);
    } else {
      _finishAssessment();
    }
  }

  Future<void> _openMedicalHistoryDetails() async {
    final result = await Navigator.of(context).push<MedicalHistoryFollowUpResult>(
      MaterialPageRoute(
        builder: (context) => MedicalHistoryDetailsView(
          needsMajorMedical: _hasMajorMedicalHistory,
          needsTransfusion: _hasTransfusionOrSurgery,
          needsTravel: _hasTravelOrNeedleStick,
          initialMajorMedicalDesc: _majorMedicalHistoryDesc,
          initialTransfusionDate: _transfusionOrSurgeryDate,
          initialTransfusionDesc: _transfusionOrSurgeryDesc,
          initialTravelDate: _travelOrNeedleDate,
          initialTravelDesc: _travelOrNeedleDesc,
        ),
      ),
    );
    if (result == null) return; // donor backed out — stay on Step 4
    setState(() {
      _majorMedicalHistoryDesc = result.majorMedicalHistoryDesc;
      _transfusionOrSurgeryDate = result.transfusionOrSurgeryDate;
      _transfusionOrSurgeryDesc = result.transfusionOrSurgeryDesc;
      _travelOrNeedleDate = result.travelOrNeedleDate;
      _travelOrNeedleDesc = result.travelOrNeedleDesc;
      _currentStep++;
    });
  }

  void _prevStep() {
    final int floor = widget.isRetake ? 2 : 1;
    if (_currentStep > floor) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _finishAssessment() async {
    setState(() => _isLoading = true);

    final double weight = double.tryParse(_weightController.text.trim()) ?? 52.0;
    int calculatedAge;
    if (widget.isRetake) {
      // Retake shows an editable Age field (see build(), Step 2) instead of
      // the DOB picker — use whatever the donor left it at, which starts
      // out prefilled with their real last-known age.
      final editedAge = int.tryParse(_ageController.text.trim());
      calculatedAge = (editedAge != null && editedAge > 0) ? editedAge : (_prefilledAge ?? 22);
    } else if (_dob != null) {
      final now = DateTime.now();
      calculatedAge = now.year - _dob!.year;
      if (now.month < _dob!.month || (now.month == _dob!.month && now.day < _dob!.day)) {
        calculatedAge--;
      }
    } else {
      calculatedAge = 22;
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
      tattooDate: _hasTattoosOrPiercings ? _tattooDate : null,
      hasAlcoholPast24hr: _hasAlcoholPast24hr,
      hasActiveInfectOrMeds: _hasActiveInfectOrMeds,
      recentMedProcedures: _recentMedProcedures,
      medProcedureDetails: _medProcedureDetails,
      hasMajorMedicalHistory: _hasMajorMedicalHistory,
      majorMedicalHistoryDesc: _hasMajorMedicalHistory ? _majorMedicalHistoryDesc : null,
      hasTransfusionOrSurgery: _hasTransfusionOrSurgery,
      transfusionOrSurgeryDate: _hasTransfusionOrSurgery ? _transfusionOrSurgeryDate : null,
      transfusionOrSurgeryDesc: _hasTransfusionOrSurgery ? _transfusionOrSurgeryDesc : null,
      hasTravelOrNeedleStick: _hasTravelOrNeedleStick,
      travelOrNeedleDate: _hasTravelOrNeedleStick ? _travelOrNeedleDate : null,
      travelOrNeedleDesc: _hasTravelOrNeedleStick ? _travelOrNeedleDesc : null,
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

    if (widget.isRetake) {
      // Persist for real — PATCH /api/donor/me — instead of only updating
      // in-memory state like every retake caller used to do. Without this,
      // a retake looked correct until the donor logged out: the answers
      // were never actually saved, so the next login re-evaluated
      // eligibility against the *original* registration answers again
      // (see eligibility_service.dart's classifyDonorFromProfile, which
      // reads healthScreening straight from the backend).
      try {
        await ApiService.updateMyProfile(widget.token, {
          'age': calculatedAge,
          'weightKg': weight,
          'gender': _gender.name,
          'healthScreening': {
            'isFirstTimeDonor': evaluatedParams.isFirstTimeDonor,
            'lastDonationDate': evaluatedParams.lastDonationDate?.toIso8601String(),
            'totalDonations': evaluatedParams.totalDonations,
            'feelsWellToday': evaluatedParams.feelsWellToday,
            'hasEatenRecently': evaluatedParams.hasEatenRecently,
            'hasTattsOrPierce': evaluatedParams.hasTattsOrPierce,
            'tattooDate': evaluatedParams.tattooDate?.toIso8601String(),
            'hasAlcoholPast24hr': evaluatedParams.hasAlcoholPast24hr,
            'hasActiveInfectOrMeds': evaluatedParams.hasActiveInfectOrMeds,
            'recentMedProcedures': evaluatedParams.recentMedProcedures.toList(),
            'medProcedureDetails': evaluatedParams.medProcedureDetails.map(
              (key, detail) => MapEntry(key, {
                'date': detail.date?.toIso8601String(),
                'dosageOrReason': detail.dosageOrReason,
              }),
            ),
            'hasMajorMedicalHistory': evaluatedParams.hasMajorMedicalHistory,
            'majorMedicalHistoryDesc': evaluatedParams.majorMedicalHistoryDesc,
            'hasTransfusionOrSurgery': evaluatedParams.hasTransfusionOrSurgery,
            'transfusionOrSurgeryDate': evaluatedParams.transfusionOrSurgeryDate?.toIso8601String(),
            'transfusionOrSurgeryDesc': evaluatedParams.transfusionOrSurgeryDesc,
            'hasTravelOrNeedleStick': evaluatedParams.hasTravelOrNeedleStick,
            'travelOrNeedleDate': evaluatedParams.travelOrNeedleDate?.toIso8601String(),
            'travelOrNeedleDesc': evaluatedParams.travelOrNeedleDesc,
            'isPregOrNursing': evaluatedParams.isPregOrNursing,
            'lastMensPeriodDate': evaluatedParams.lastMensPeriodDate?.toIso8601String(),
            'hasHighRiskExpo': evaluatedParams.hasHighRiskExpo,
            'classificationStatus': result.status.name,
          },
        });
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save your updated screening: ${e.message}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return; // stay on the wizard so the donor can retry, instead of
        // silently discarding what they just answered.
      } catch (_) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not reach the ResQ server. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
      widget.onRetakeCompleted?.call(finalModel, result);
      Navigator.pop(context);
    } else {
      // Cosmetic pacing only — no network call happens at this step for a
      // brand-new registration; the real save happens later via
      // completeProfile once the donor verifies their OTP (otp_ver_view.dart).
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _isLoading = false);

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

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RegistrationSummaryView(
            userModel: newUser,
            profileModel: newProfile,
            screeningModel: finalModel,
            classificationResult: result,
            rawPassword: _passwordController.text,
            isFirstTimeDonor: _isFirstTimeDonor,
            photoPath: _photoPath,
          ),
        ),
      );
    }
  }

  // ===========================================================================
  // LAYOUT: header with labelled stepper · scrolling step content · footer
  // ===========================================================================

  static const List<String> _stepNames = ['Account', 'Body', 'Health', 'Medical', 'Final'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RQColors.surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: RQColors.blood))
          : Column(
              children: [
                _buildStepHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.horizontalPadding(context),
                      vertical: 16,
                    ),
                    child: ResponsiveContentArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_currentStep == 1) _buildStep1AccountUI(),
                          if (_currentStep == 2) _buildStep2PhysicalMetricsUI(),
                          if (_currentStep == 3) _buildStep3HealthScreeningUI(),
                          if (_currentStep == 4) _buildStep4MedicalHistoryUI(),
                          if (_currentStep == 5) _buildStep5FinalScreeningUI(),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildFooter(),
              ],
            ),
    );
  }

  Widget _buildStepHeader() {
    final int floor = widget.isRetake ? 2 : 1;
    const titles = {
      1: 'Create your account',
      2: 'Physical metrics',
      3: 'How are you today?',
      4: 'Medical & risk factors',
      5: 'Final screening',
    };
    final subtitles = {
      1: 'Join donors answering urgent blood requests near you.',
      2: 'Basic details that decide if you can donate safely.',
      3: 'Quick checks so donating is safe for you and the patient.',
      4: 'Recent medicines, conditions and exposures.',
      5: 'A few private questions for ${_gender == BioSex.female ? 'female' : 'male'} donors.',
    };

    return Container(
      width: double.infinity,
      color: RQColors.blood,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: ResponsiveContentArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () {
                        if (_currentStep > floor) {
                          _prevStep();
                        } else {
                          Navigator.of(context).maybePop();
                        }
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0x29FFFFFF),
                        fixedSize: const Size(44, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.isRetake ? 'Update your health screening' : 'Create your donor profile',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                      ),
                    ),
                    Text(
                      '$_currentStep of $_totalSteps',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xE6FFFFFF)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStepper(),
                const SizedBox(height: 16),
                Text(
                  titles[_currentStep] ?? '',
                  style: const TextStyle(fontSize: 22, height: 1.35, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                Text(
                  subtitles[_currentStep] ?? '',
                  style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xE6FFFFFF)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Five labelled dots joined by a line — done steps get a check, the
  /// current one a white glow, upcoming ones an outline.
  Widget _buildStepper() {
    return LayoutBuilder(
      builder: (context, c) {
        final double colW = c.maxWidth / _totalSteps;
        final double span = c.maxWidth - colW;
        final double progress = ((_currentStep - 1) / (_totalSteps - 1)).clamp(0.0, 1.0);
        return SizedBox(
          height: 48,
          child: Stack(
            children: [
              Positioned(
                left: colW / 2,
                width: span,
                top: 11,
                child: Container(height: 2, color: const Color(0x4DFFFFFF)),
              ),
              Positioned(
                left: colW / 2,
                width: span * progress,
                top: 11,
                child: Container(height: 2, color: Colors.white),
              ),
              Row(
                children: [
                  for (int i = 1; i <= _totalSteps; i++)
                    Expanded(
                      child: Column(
                        children: [
                          _stepDot(i),
                          const SizedBox(height: 6),
                          Text(
                            _stepNames[i - 1],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: i == _currentStep ? FontWeight.w600 : FontWeight.w400,
                              color: i == _currentStep ? Colors.white : const Color(0xCCFFFFFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stepDot(int i) {
    if (i < _currentStep) {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 15, color: RQColors.blood),
      );
    }
    if (i == _currentStep) {
      return Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x4DFFFFFF), spreadRadius: 4)],
        ),
        child: Text('$i', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RQColors.blood)),
      );
    }
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: RQColors.blood,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x73FFFFFF), width: 2),
      ),
      child: Text('$i', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xD9FFFFFF))),
    );
  }

  Widget _buildFooter() {
    final bool showBack = _currentStep >= 3;
    String label;
    switch (_currentStep) {
      case 1:
        label = 'Continue to your details';
        break;
      case 2:
        label = 'Continue to health screening';
        break;
      case 5:
        label = widget.isRetake ? 'Save my answers' : 'Review my answers';
        break;
      default:
        label = 'Continue';
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: RQColors.card,
        border: Border(top: BorderSide(color: RQColors.hairline)),
      ),
      child: ResponsiveContentArea(
        child: Row(
          children: [
            if (showBack) ...[
              SizedBox(
                width: 54,
                height: 54,
                child: OutlinedButton(
                  onPressed: _prevStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: RQColors.ink,
                    side: const BorderSide(color: RQColors.hairline, width: 1.5),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, semanticLabel: 'Previous step'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(child: RQButton(label: label, height: 54, onPressed: _nextStep)),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // STEP 1 · Account
  // ===========================================================================
  Widget _buildStep1AccountUI() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _card(
            child: Row(
              children: [
                EditableAvatar(
                  localPhotoPath: _photoPath,
                  radius: 32,
                  onLocalFilePicked: (path) => setState(() => _photoPath = path),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Profile photo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: RQColors.ink)),
                      Text('Optional. Helps hospital staff recognize you.',
                          style: TextStyle(fontSize: 12, height: 1.4, color: RQColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cardTitle('Your details'),
                const SizedBox(height: 12),
                _formField(
                  controller: _nameController,
                  label: 'Full name',
                  capitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Please enter your full name';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _formField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Please enter your email';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _formField(
                  controller: _phoneController,
                  label: 'Mobile number',
                  hint: '9XX XXX XXXX',
                  prefixText: '+63',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.sms_outlined, size: 14, color: RQColors.navy),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text("We'll text a 6-digit code to verify this number.",
                          style: TextStyle(fontSize: 12, color: RQColors.muted)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cardTitle('Password'),
                const SizedBox(height: 12),
                _formField(
                  controller: _passwordController,
                  label: 'Create password',
                  obscure: _obscurePassword,
                  onChanged: (_) => setState(() {}),
                  suffix: IconButton(
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: RQColors.muted),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter a password';
                    if (value.length < 8) return 'Password must be at least 8 characters';
                    return null;
                  },
                ),
                if (_passwordController.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _strengthMeter(_passwordController.text),
                ],
                const SizedBox(height: 12),
                _formField(
                  controller: _confirmPasswordController,
                  label: 'Confirm password',
                  obscure: _obscureConfirmPassword,
                  suffix: IconButton(
                    tooltip: _obscureConfirmPassword ? 'Show password' : 'Hide password',
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: RQColors.muted),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please confirm your password';
                    if (value != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _noteBox(
            Icons.verified_user_outlined,
            'Your data is encrypted and only used to check if you can donate.',
            background: RQColors.successTint,
            iconColor: RQColors.success,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Already have an account?', style: TextStyle(fontSize: 14, color: Color(0xFF555555))),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginView()),
                  );
                },
                style: TextButton.styleFrom(foregroundColor: RQColors.blood),
                child: const Text('Log in', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _strengthMeter(String pw) {
    final int score = [
      pw.length >= 8,
      pw.contains(RegExp(r'[A-Z]')),
      pw.contains(RegExp(r'[0-9]')),
      pw.contains(RegExp(r'[^A-Za-z0-9]')),
    ].where((b) => b).length;
    const labels = ['Too weak', 'Weak', 'Fair', 'Good', 'Strong'];
    final Color color = score >= 3 ? RQColors.success : (score == 2 ? RQColors.warning : const Color(0xFFB91C1C));
    return Row(
      children: [
        for (int i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: i < score ? color : RQColors.hairline,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
        const SizedBox(width: 10),
        Text(labels[score], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  // ===========================================================================
  // STEP 2 · Physical metrics
  // ===========================================================================
  Widget _buildStep2PhysicalMetricsUI() {
    final double? weight = double.tryParse(_weightController.text.trim());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cardTitle('Blood type', subtitle: 'Pick yours, or choose "I\'m not sure".'),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.35,
                children: _bloodTypes.map(_bloodTypeTile).toList(),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: _selectableButton(
                  label: "I'm not sure",
                  icon: Icons.help_outline_rounded,
                  selected: _selectedBloodType == "I'm not sure",
                  onTap: () => setState(() => _selectedBloodType = "I'm not sure"),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cardTitle('About you'),
              const SizedBox(height: 12),
              if (!widget.isRetake)
                _dateField(
                  label: 'Date of birth',
                  value: _dob,
                  chip: _dob != null ? '${_ageFrom(_dob!)} yrs' : null,
                  onTap: () => _pickDate(
                    context: context,
                    initialDate: _dob ?? DateTime(2002),
                    firstDate: DateTime(1940),
                    lastDate: DateTime.now(),
                    onPicked: (d) => _dob = d,
                  ),
                )
              else
                // No real DOB is stored server-side (only a computed age), so a
                // retake shows the donor's last-known age instead, editable.
                RQTextField(controller: _ageController, label: 'Age', keyboardType: TextInputType.number),
              const SizedBox(height: 14),
              const Text('Biological sex', style: TextStyle(fontSize: 12, color: RQColors.muted)),
              const SizedBox(height: 6),
              _segmented(
                labels: const ['Female', 'Male'],
                selectedIndex: _gender == BioSex.female ? 0 : 1,
                onChanged: (i) => setState(() => _gender = i == 0 ? BioSex.female : BioSex.male),
              ),
              const SizedBox(height: 14),
              RQTextField(
                controller: _weightController,
                label: 'Weight',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                suffix: const Padding(
                  padding: EdgeInsets.only(right: 14),
                  child: Center(
                    widthFactor: 1,
                    child: Text('kg', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: RQColors.muted)),
                  ),
                ),
              ),
              if (weight != null && weight > 0) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      weight >= 50 ? Icons.check_rounded : Icons.info_outline_rounded,
                      size: 15,
                      color: weight >= 50 ? RQColors.success : RQColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        weight >= 50 ? 'Meets the 50 kg minimum' : 'Below the 50 kg minimum for donating',
                        style: TextStyle(fontSize: 12, color: weight >= 50 ? RQColors.success : RQColors.warning),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cardTitle('Donation history'),
              const SizedBox(height: 10),
              _optionCard(
                label: "I've donated before",
                selected: !_isFirstTimeDonor,
                onTap: () => setState(() => _isFirstTimeDonor = false),
                expanded: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _dateField(
                      label: 'Last donation',
                      value: _lastDonationDate,
                      onTap: () async {
                        await _pickDate(
                          context: context,
                          initialDate: _lastDonationDate ?? DateTime.now().subtract(const Duration(days: 90)),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                          onPicked: (d) {
                            _lastDonationDate = d;
                            _isFirstTimeDonor = false;
                          },
                        );
                        if (!mounted || _lastDonationDate == null) return;
                        await _promptForDonationCount(context);
                      },
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                      decoration: BoxDecoration(
                        color: RQColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: RQColors.hairline),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Lifetime donations', style: TextStyle(fontSize: 11, color: RQColors.muted)),
                                Text(
                                  _totalDonations > 0
                                      ? '$_totalDonations ${_totalDonations == 1 ? 'donation' : 'donations'}'
                                      : 'Not set yet',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: RQColors.ink),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _promptForDonationCount(context),
                            style: TextButton.styleFrom(foregroundColor: RQColors.navy),
                            child: Text(_totalDonations > 0 ? 'Edit' : 'Add',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _optionCard(
                label: 'This is my first time',
                selected: _isFirstTimeDonor,
                onTap: () => setState(() {
                  _isFirstTimeDonor = true;
                  _lastDonationDate = null;
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cardTitle('Tattoos or piercings', subtitle: 'In the last 12 months'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: _selectableButton(
                        label: 'None',
                        icon: !_hasTattoosOrPiercings ? Icons.check_rounded : null,
                        selected: !_hasTattoosOrPiercings,
                        onTap: () => setState(() => _hasTattoosOrPiercings = false),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: _selectableButton(
                        label: 'Yes, I have',
                        icon: _hasTattoosOrPiercings ? Icons.check_rounded : null,
                        selected: _hasTattoosOrPiercings,
                        onTap: () => setState(() => _hasTattoosOrPiercings = true),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_hasTattoosOrPiercings) ...[
                _noteBox(Icons.info_outline_rounded,
                    'A 6–12 month wait usually applies. Add the date of your most recent one.'),
                const SizedBox(height: 10),
                _dateField(
                  label: 'Date of last tattoo or piercing',
                  value: _tattooDate,
                  onTap: () => _pickDate(
                    context: context,
                    initialDate: _tattooDate ?? DateTime.now().subtract(const Duration(days: 180)),
                    firstDate: DateTime(2010),
                    lastDate: DateTime.now(),
                    onPicked: (d) => _tattooDate = d,
                  ),
                ),
              ] else
                const Text("If yes, we'll ask for the date. A 6–12 month wait usually applies.",
                    style: TextStyle(fontSize: 12, height: 1.4, color: RQColors.muted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bloodTypeTile(String type) {
    final bool selected = _selectedBloodType == type;
    return Material(
      color: selected ? RQColors.blood : RQColors.card,
      elevation: selected ? 3 : 0,
      shadowColor: const Color(0x669B1B20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: selected ? BorderSide.none : const BorderSide(color: RQColors.hairline, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _selectedBloodType = type),
        child: Center(
          child: Text(
            type.replaceAll('-', '−'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? Colors.white : RQColors.ink,
            ),
          ),
        ),
      ),
    );
  }

  int _ageFrom(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age--;
    return age;
  }

  // ===========================================================================
  // STEP 3 · Health screening
  // ===========================================================================
  Widget _buildStep3HealthScreeningUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _privacyLine('Private. Only used to check your eligibility.'),
        const SizedBox(height: 12),
        _questionCard(
          icon: Icons.sentiment_satisfied_alt_outlined,
          question: 'Are you feeling well and healthy today?',
          value: _feelsWellToday,
          onChanged: (val) => setState(() => _feelsWellToday = val),
        ),
        const SizedBox(height: 12),
        _questionCard(
          icon: Icons.restaurant_outlined,
          question: 'Had a full meal and fluids in the last 4–6 hours?',
          value: _hasEatenRecently,
          onChanged: (val) => setState(() => _hasEatenRecently = val),
        ),
        const SizedBox(height: 12),
        _questionCard(
          icon: Icons.local_bar_outlined,
          question: 'Had alcohol in the past 24 hours?',
          value: _hasAlcoholPast24hr,
          onChanged: (val) => setState(() => _hasAlcoholPast24hr = val),
        ),
      ],
    );
  }

  Widget _questionCard({
    required IconData icon,
    required String question,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              RQIconBox(icon: icon, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Text(question,
                    style: const TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w500, color: RQColors.ink)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _yesNo(value, onChanged),
        ],
      ),
    );
  }

  // ===========================================================================
  // STEP 4 · Medical & risk factors
  // ===========================================================================
  static const Map<String, String> _medHints = {
    'Antibiotics': 'Any course',
    'Aspirin': 'Pain relievers',
    'Vaccines': 'Any shot',
    'Dental Work': 'Extraction, cleaning',
  };

  IconData _medIcon(String option) {
    switch (option) {
      case 'Antibiotics':
        return Icons.medication_outlined;
      case 'Aspirin':
        return Icons.healing_outlined;
      case 'Vaccines':
        return Icons.vaccines_outlined;
      case 'Dental Work':
        return Icons.medical_services_outlined;
      default:
        return Icons.medication_outlined;
    }
  }

  Widget _buildStep4MedicalHistoryUI() {
    final bool followUp = _hasMajorMedicalHistory || _hasTransfusionOrSurgery || _hasTravelOrNeedleStick;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cardTitle('Medicines & procedures', subtitle: 'In the last 4 weeks. Tap all that apply.'),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.45,
                children: _medProcedureOptions.map(_medTile).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cardTitle('Medical history'),
              const SizedBox(height: 8),
              const Text('Heart disease, asthma, diabetes or another major condition?',
                  style: TextStyle(fontSize: 14, height: 1.45, color: RQColors.ink)),
              const SizedBox(height: 12),
              _yesNo(_hasMajorMedicalHistory, (val) => setState(() => _hasMajorMedicalHistory = val)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cardTitle('Risk factors', subtitle: 'In the last 12 months'),
              const SizedBox(height: 12),
              const Text('Blood transfusion or surgery?', style: TextStyle(fontSize: 14, height: 1.45, color: RQColors.ink)),
              const SizedBox(height: 10),
              _yesNo(_hasTransfusionOrSurgery, (val) => setState(() => _hasTransfusionOrSurgery = val)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, thickness: 1, color: RQColors.hairline),
              ),
              const Text('Travel abroad or an accidental needle-stick?',
                  style: TextStyle(fontSize: 14, height: 1.45, color: RQColors.ink)),
              const SizedBox(height: 10),
              _yesNo(_hasTravelOrNeedleStick, (val) => setState(() => _hasTravelOrNeedleStick = val)),
              if (followUp) ...[
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 15, color: RQColors.navy),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text("We'll ask a few details on the next screen.",
                          style: TextStyle(fontSize: 12, color: RQColors.navy)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _noteBox(
          Icons.favorite_border_rounded,
          'Not sure about an answer? Choose the closest one. Staff will go over it with you before you donate.',
          background: RQColors.navyTint,
        ),
      ],
    );
  }

  Widget _medTile(String option) {
    final bool selected = _recentMedProcedures.contains(option);
    final detail = _medProcedureDetails[option];
    String caption = _medHints[option] ?? '';
    if (selected && detail != null) {
      final parts = <String>[
        if (detail.date != null) _shortDate(detail.date!),
        if (detail.dosageOrReason != null && detail.dosageOrReason!.isNotEmpty) detail.dosageOrReason!,
      ];
      if (parts.isNotEmpty) caption = parts.join(' · ');
    }

    return Material(
      color: selected ? const Color(0xFFFDF5F5) : RQColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? RQColors.blood : RQColors.hairline, width: selected ? 2 : 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _promptMedProcedureDetail(option),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_medIcon(option), size: 22, color: selected ? RQColors.blood : RQColors.muted),
                  const SizedBox(height: 6),
                  Text(option,
                      style: TextStyle(
                          fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: RQColors.ink)),
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: selected ? RQColors.blood : RQColors.muted),
                  ),
                ],
              ),
              if (selected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(color: RQColors.blood, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // STEP 5 · Final screening (sex-specific)
  // ===========================================================================
  Widget _buildStep5FinalScreeningUI() {
    final bool female = _gender == BioSex.female;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _privacyLine('Confidential. Only clinical staff see these answers.'),
        const SizedBox(height: 12),
        if (female) ...[
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cardTitle('Menstrual cycle'),
                const SizedBox(height: 12),
                _dateField(
                  label: 'First day of your last period',
                  value: _lastMensDate,
                  onTap: () => _pickDate(
                    context: context,
                    initialDate: _lastMensDate ?? DateTime.now().subtract(const Duration(days: 14)),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    onPicked: (d) => _lastMensDate = d,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cardTitle('Pregnancy'),
                const SizedBox(height: 10),
                _optionCard(
                  label: 'Not currently pregnant',
                  selected: _pregnancyStatusIndex == 0,
                  onTap: () => setState(() => _pregnancyStatusIndex = 0),
                ),
                const SizedBox(height: 8),
                _optionCard(
                  label: 'Currently pregnant',
                  selected: _pregnancyStatusIndex == 1,
                  onTap: () => setState(() => _pregnancyStatusIndex = 1),
                ),
                const SizedBox(height: 8),
                _optionCard(
                  label: 'Gave birth in the last 6 weeks',
                  selected: _pregnancyStatusIndex == 2,
                  onTap: () => setState(() => _pregnancyStatusIndex = 2),
                ),
                const SizedBox(height: 4),
                const Divider(height: 20, thickness: 1, color: RQColors.hairline),
                RQToggleRow(
                  title: 'Currently breastfeeding',
                  subtitle: 'Nursing a child right now',
                  value: _isBreastfeeding,
                  showDivider: false,
                  onChanged: (val) => setState(() => _isBreastfeeding = val),
                ),
                const SizedBox(height: 4),
                const Text(
                  "If you're pregnant or nursing, donation is paused for now to protect you and your baby.",
                  style: TextStyle(fontSize: 12, height: 1.4, color: RQColors.muted),
                ),
              ],
            ),
          ),
        ] else ...[
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cardTitle('STI history', subtitle: 'Any sexually transmitted infection in the last 12 months?'),
                const SizedBox(height: 12),
                _yesNo(_hasStiHistory, (val) => setState(() => _hasStiHistory = val)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cardTitle('High-risk contact', subtitle: 'In the last 12 months'),
                const SizedBox(height: 8),
                const Text(
                  'Sexual contact with anyone who has tested positive for HIV or injected non-prescribed drugs?',
                  style: TextStyle(fontSize: 14, height: 1.45, color: RQColors.ink),
                ),
                const SizedBox(height: 12),
                _yesNo(_hasHighRiskContact, (val) => setState(() => _hasHighRiskContact = val)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cardTitle('Sexual contact with men'),
                const SizedBox(height: 10),
                _optionCard(
                  label: 'Never',
                  selected: _msmHistoryIndex == 0,
                  onTap: () => setState(() => _msmHistoryIndex = 0),
                ),
                const SizedBox(height: 8),
                _optionCard(
                  label: 'More than 3 months ago',
                  selected: _msmHistoryIndex == 1,
                  onTap: () => setState(() => _msmHistoryIndex = 1),
                ),
                const SizedBox(height: 8),
                _optionCard(
                  label: 'Within the last 3 months',
                  selected: _msmHistoryIndex == 2,
                  onTap: () => setState(() => _msmHistoryIndex = 2),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cardTitle('Recent sexual risk'),
              const SizedBox(height: 10),
              Material(
                color: _hasRecentSexualRisk ? const Color(0xFFFDF5F5) : RQColors.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: _hasRecentSexualRisk ? RQColors.blood : RQColors.hairline,
                    width: _hasRecentSexualRisk ? 2 : 1.5,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _hasRecentSexualRisk = !_hasRecentSexualRisk),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _hasRecentSexualRisk,
                          onChanged: (val) => setState(() => _hasRecentSexualRisk = val ?? false),
                          activeColor: RQColors.blood,
                        ),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: 12, bottom: 8),
                            child: Text(
                              "I've had a new partner or more than one partner in the last 3 months.",
                              style: TextStyle(fontSize: 14, height: 1.45, color: RQColors.ink),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text("Leave unchecked if this doesn't apply to you.",
                  style: TextStyle(fontSize: 12, color: RQColors.muted)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _card(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: RQColors.successTint, shape: BoxShape.circle),
                child: const Icon(Icons.verified_user_outlined, color: RQColors.success),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("You're almost done",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: RQColors.ink)),
                    Text(
                      widget.isRetake
                          ? "Next, we'll save your updated answers."
                          : 'Next, review your answers before we create your account.',
                      style: const TextStyle(fontSize: 12.5, height: 1.45, color: RQColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Shared building blocks
  // ===========================================================================

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: RQColors.card, borderRadius: BorderRadius.circular(20)),
      child: child,
    );
  }

  Widget _cardTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: RQColors.ink)),
        if (subtitle != null)
          Text(subtitle, style: const TextStyle(fontSize: 12, height: 1.4, color: RQColors.muted)),
      ],
    );
  }

  Widget _privacyLine(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, size: 15, color: RQColors.success),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF555555)))),
        ],
      ),
    );
  }

  Widget _noteBox(
    IconData icon,
    String text, {
    Color background = RQColors.surface,
    Color iconColor = RQColors.navy,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.45, color: RQColors.ink))),
        ],
      ),
    );
  }

  /// Yes / No pair — the chosen one is filled red.
  Widget _yesNo(bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: _selectableButton(label: 'Yes', selected: value, filled: true, onTap: () => onChanged(true)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 44,
            child: _selectableButton(label: 'No', selected: !value, filled: true, onTap: () => onChanged(false)),
          ),
        ),
      ],
    );
  }

  /// A button that shows a selected state. [filled] = solid red when
  /// selected (Yes/No); otherwise a red outline on a light tint.
  Widget _selectableButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
    bool filled = false,
  }) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 6)],
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
        ),
      ],
    );
    final Widget button;
    if (selected && filled) {
      button = ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: RQColors.blood,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: shape,
        ),
        child: content,
      );
    } else {
      button = OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? const Color(0xFFFDF5F5) : RQColors.card,
          foregroundColor: selected ? RQColors.blood : RQColors.ink,
          side: BorderSide(color: selected ? RQColors.blood : RQColors.hairline, width: selected ? 2 : 1.5),
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: shape,
        ),
        child: content,
      );
    }
    return Semantics(selected: selected, button: true, child: button);
  }

  Widget _choiceChip({required String label, required bool selected, required VoidCallback onTap}) {
    return SizedBox(
      height: 36,
      child: selected
          ? ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: RQColors.blood,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: const StadiumBorder(),
              ),
              child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: RQColors.ink,
                side: const BorderSide(color: RQColors.hairline, width: 1.5),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: const StadiumBorder(),
              ),
              child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ),
    );
  }

  /// Radio-style option card; [expanded] shows under the label when chosen.
  Widget _optionCard({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Widget? expanded,
  }) {
    return Material(
      color: selected ? const Color(0xFFFDF5F5) : RQColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? RQColors.blood : RQColors.hairline, width: selected ? 2 : 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                selected: selected,
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: selected ? RQColors.blood : RQColors.fieldBorder, width: 2),
                      ),
                      child: selected
                          ? Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(color: RQColors.blood, shape: BoxShape.circle),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          color: RQColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected && expanded != null) ...[const SizedBox(height: 12), expanded],
            ],
          ),
        ),
      ),
    );
  }

  /// Tappable field that shows a picked date, with a calendar icon.
  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    String? chip,
  }) {
    return Material(
      color: RQColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: RQColors.fieldBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 11, color: RQColors.muted)),
                    Text(
                      value != null ? _formatDate(value) : 'Select a date',
                      style: TextStyle(fontSize: 15, color: value != null ? RQColors.ink : const Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),
              if (chip != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: RQColors.surface, borderRadius: BorderRadius.circular(999)),
                  child: Text(chip, style: const TextStyle(fontSize: 12, color: RQColors.body)),
                ),
                const SizedBox(width: 10),
              ],
              const Icon(Icons.calendar_month_outlined, size: 20, color: RQColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  /// Two-option segmented control (Female / Male).
  Widget _segmented({
    required List<String> labels,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: RQColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                selected: i == selectedIndex,
                button: true,
                child: Material(
                  color: i == selectedIndex ? RQColors.card : Colors.transparent,
                  elevation: i == selectedIndex ? 1 : 0,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => onChanged(i),
                    child: SizedBox(
                      height: 40,
                      child: Center(
                        child: Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: i == selectedIndex ? FontWeight.w600 : FontWeight.w500,
                            color: i == selectedIndex ? RQColors.ink : RQColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Outlined form field with its label inside the box (Step 1).
  Widget _formField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? prefixText,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      onChanged: onChanged,
      textCapitalization: capitalization,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: const TextStyle(fontSize: 15, color: RQColors.ink),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 13, color: RQColors.muted),
        floatingLabelStyle: const TextStyle(fontSize: 13, color: RQColors.blood, fontWeight: FontWeight.w500),
        hintStyle: const TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
        prefixText: prefixText != null ? '$prefixText  ' : null,
        prefixStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: RQColors.ink),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        suffixIcon: suffix,
        border: border(RQColors.fieldBorder, 1),
        enabledBorder: border(RQColors.fieldBorder, 1),
        focusedBorder: border(RQColors.blood, 2),
        errorBorder: border(const Color(0xFFB91C1C), 1.5),
        focusedErrorBorder: border(const Color(0xFFB91C1C), 2),
      ),
    );
  }

  Widget _datePickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: RQColors.blood,
          onPrimary: Colors.white,
          onSurface: RQColors.ink,
        ),
      ),
      child: child!,
    );
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _shortDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }
}