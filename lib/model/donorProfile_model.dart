import 'package:resq/utils/algo/decisionTree_class.dart';

class DonorProfModel {
  final String profId;
  final String userId;
  final String bloodType;
  final BioSex gender;
  final double weight;
  final int age;
  final EligibleStats eligibilityStats;

  //Dashboard Impact Metrics
  final double ltrDonated;
  final int livesImpacted;
  final int completedDonations;
  final DateTime? lastDonationDate;
  final DateTime? nextEligibleDate;

  DonorProfModel({
    required this.profId,
    required this.userId,
    required this.bloodType,
    required this.gender,
    required this.weight,
    required this.age,
    required this.eligibilityStats,
    this.ltrDonated = 0.0,
    this.livesImpacted = 0,
    this.completedDonations = 0,
    this.lastDonationDate,
    this.nextEligibleDate,
  });

  factory DonorProfModel.fromJson(Map<String, dynamic> json) {
    return DonorProfModel(
        profId: json['profile_id'] as String,
        userId: json['user_id'] as String,
        bloodType: json['blood_type'] as String,
        gender: json['gender'] == 'female' ? BioSex.female : BioSex.male,
        weight: (json['weight_kg'] as num).toDouble(),
        age: json['age'] as int,
        eligibilityStats: EligibleStats.values.firstWhere(
              (e) => e.name == json['eligibility_status'],
          orElse: () => EligibleStats.eligible,
        ),
        ltrDonated: (json['liters_donated'] as num?)?.toDouble() ?? 0.0,
        livesImpacted: json['lives_impacted'] as int? ?? 0,
        completedDonations: json['completed_donations'] as int? ?? 0,
        lastDonationDate: json['last_donation_date'] != null
            ? DateTime.parse(json['last_donation_date'] as String)
            : null,
        nextEligibleDate: json['next_eligible_date'] != null
            ? DateTime.parse(json['next_eligible_date'] as String)
            : null
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile_id': profId,
      'user_id': userId,
      'blood_type': bloodType,
      'gender': gender.name,
      'weight_kg': weight,
      'age': age,
      'eligibility_status': eligibilityStats.name,
      'liters_donated': ltrDonated,
      'lives_impacted': livesImpacted,
      'completed_donations': completedDonations,
      'last_donation_date': lastDonationDate?.toIso8601String(),
      'next_eligible_date': nextEligibleDate?.toIso8601String(),
    };
  }
}