import 'package:resq/utils/algo/decision_tree_class.dart';

class ScreenNPTModel {
  final String? id;
  final String donorProfId;
  final DonorScreensNPT screensNPT;
  final DateTime submissionDate;

  ScreenNPTModel({
    this.id,
    required this.donorProfId,
    required this.screensNPT,
    required this.submissionDate,
  });

  /// Evaluates this screening instance against the Decision Tree Engine
  ClassificationResult evaluateEligibility() {
    final classifier = DecisionTreeClassifier();
    return classifier.classify(screensNPT);
  }

  static Map<String, MedProcedureDetail> _parseMedProcedureDetails(dynamic raw) {
    if (raw is! Map) return const {};
    final result = <String, MedProcedureDetail>{};
    raw.forEach((key, value) {
      if (value is Map) {
        result[key.toString()] = MedProcedureDetail(
          date: value['date'] != null ? DateTime.tryParse(value['date'] as String) : null,
          dosageOrReason: value['dosage_or_reason'] as String?,
        );
      }
    });
    return result;
  }

  static Map<String, dynamic> _medProcedureDetailsToJson(Map<String, MedProcedureDetail> details) {
    return details.map((key, value) => MapEntry(key, {
          'date': value.date?.toIso8601String(),
          'dosage_or_reason': value.dosageOrReason,
        }));
  }

  factory ScreenNPTModel.fromJson(Map<String, dynamic> json) {
    return ScreenNPTModel(
      id: json['id'] as String?,
      donorProfId: json['donor_profile_id'] as String,
      screensNPT: DonorScreensNPT(
        gender: json['gender'] == 'female' ? BioSex.female : BioSex.male,
        weight: (json['weight'] as num).toDouble(),
        age: json['age'] as int,
        isFirstTimeDonor: json['is_first_time_donor'] as bool? ?? true,
        lastDonationDate: json['last_donation_date'] != null
            ? DateTime.parse(json['last_donation_date'] as String)
            : null,
        totalDonations: json['total_donations'] as int? ?? 0,
        feelsWellToday: json['feels_well_today'] as bool? ?? true,
        hasEatenRecently: json['has_eaten_recently'] as bool? ?? true,
        hasTattsOrPierce: json['has_tatts_or_pierce'] as bool,
        tattooDate: json['tattoo_date'] != null
            ? DateTime.parse(json['tattoo_date'] as String)
            : null,
        hasAlcoholPast24hr: json['has_alcohol_past_24hr'] as bool,
        hasActiveInfectOrMeds: json['has_active_infect_or_meds'] as bool,
        recentMedProcedures: (json['recent_med_procedures'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toSet() ??
            const {},
        medProcedureDetails: _parseMedProcedureDetails(json['med_procedure_details']),
        hasMajorMedicalHistory: json['has_major_medical_history'] as bool? ?? false,
        majorMedicalHistoryDesc: json['major_medical_history_desc'] as String?,
        hasTransfusionOrSurgery: json['has_transfusion_or_surgery'] as bool? ?? false,
        transfusionOrSurgeryDate: json['transfusion_or_surgery_date'] != null
            ? DateTime.tryParse(json['transfusion_or_surgery_date'] as String)
            : null,
        transfusionOrSurgeryDesc: json['transfusion_or_surgery_desc'] as String?,
        hasTravelOrNeedleStick: json['has_travel_or_needle_stick'] as bool? ?? false,
        travelOrNeedleDate: json['travel_or_needle_date'] != null
            ? DateTime.tryParse(json['travel_or_needle_date'] as String)
            : null,
        travelOrNeedleDesc: json['travel_or_needle_desc'] as String?,
        isPregOrNursing: json['is_preg_or_nursing'] as bool?,
        lastMensPeriodDate: json['last_menstrual_period_date'] != null
            ? DateTime.parse(json['last_menstrual_period_date'] as String)
            : null,
        hasHighRiskExpo: json['has_high_risk_exposure_past_12mos'] as bool?,
      ),
      submissionDate: DateTime.parse(json['submission_date'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'donor_profile_id': donorProfId,
      'gender': screensNPT.gender.name,
      'weight': screensNPT.weight,
      'age': screensNPT.age,
      'is_first_time_donor': screensNPT.isFirstTimeDonor,
      'last_donation_date': screensNPT.lastDonationDate?.toIso8601String(),
      'total_donations': screensNPT.totalDonations,
      'feels_well_today': screensNPT.feelsWellToday,
      'has_eaten_recently': screensNPT.hasEatenRecently,
      'has_tatts_or_pierce': screensNPT.hasTattsOrPierce,
      'tattoo_date': screensNPT.tattooDate?.toIso8601String(),
      'has_alcohol_past_24hr': screensNPT.hasAlcoholPast24hr,
      'has_active_infect_or_meds': screensNPT.hasActiveInfectOrMeds,
      'recent_med_procedures': screensNPT.recentMedProcedures.toList(),
      'med_procedure_details': _medProcedureDetailsToJson(screensNPT.medProcedureDetails),
      'has_major_medical_history': screensNPT.hasMajorMedicalHistory,
      'major_medical_history_desc': screensNPT.majorMedicalHistoryDesc,
      'has_transfusion_or_surgery': screensNPT.hasTransfusionOrSurgery,
      'transfusion_or_surgery_date': screensNPT.transfusionOrSurgeryDate?.toIso8601String(),
      'transfusion_or_surgery_desc': screensNPT.transfusionOrSurgeryDesc,
      'has_travel_or_needle_stick': screensNPT.hasTravelOrNeedleStick,
      'travel_or_needle_date': screensNPT.travelOrNeedleDate?.toIso8601String(),
      'travel_or_needle_desc': screensNPT.travelOrNeedleDesc,
      'is_preg_or_nursing': screensNPT.isPregOrNursing,
      'last_menstrual_period_date':
      screensNPT.lastMensPeriodDate?.toIso8601String(),
      'has_high_risk_exposure_past_12mos': screensNPT.hasHighRiskExpo,
      'submission_date': submissionDate.toIso8601String(),
    };
  }
}