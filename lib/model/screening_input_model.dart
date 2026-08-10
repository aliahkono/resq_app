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
        hasTattsOrPierce: json['has_tatts_or_pierce'] as bool,
        hasAlcoholPast24hr: json['has_alcohol_past_24hr'] as bool,
        hasActiveInfectOrMeds: json['has_active_infect_or_meds'] as bool,
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
      'has_tatts_or_pierce': screensNPT.hasTattsOrPierce,
      'has_alcohol_past_24hr': screensNPT.hasAlcoholPast24hr,
      'has_active_infect_or_meds': screensNPT.hasActiveInfectOrMeds,
      'is_preg_or_nursing': screensNPT.isPregOrNursing,
      'last_menstrual_period_date':
      screensNPT.lastMensPeriodDate?.toIso8601String(),
      'has_high_risk_exposure_past_12mos': screensNPT.hasHighRiskExpo,
      'submission_date': submissionDate.toIso8601String(),
    };
  }
}