import 'package:resq/utils/algo/decision_tree_class.dart';

class DeferralRecModel {
  final String id;
  final String donorProfId;
  final EligibleStats stats;
  final String reasonDesc;
  final DateTime defOn;
  final DateTime eligibleOnDate;

  DeferralRecModel({
    required this.id,
    required this.donorProfId,
    required this.stats,
    required this.reasonDesc,
    required this.defOn,
    required this.eligibleOnDate,
  });

  factory DeferralRecModel.fromJson(Map<String, dynamic> json) {
    return DeferralRecModel(
      id: json['id'] as String,
      donorProfId: json['donor_profile_id'] as String,
      stats: EligibleStats.values.firstWhere(
            (e) => e.name == json['status'],
        orElse: () => EligibleStats.eligible,
      ),
      reasonDesc: json['reason_description'] as String,
      defOn: DateTime.parse(json['deferred_on'] as String),
      eligibleOnDate: DateTime.parse(json['eligible_on_date'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'donor_profile_id': donorProfId,
      'status': stats.name,
      'reason_description': reasonDesc,
      'deferred_on': defOn.toIso8601String(),
      'eligible_on_date': eligibleOnDate.toIso8601String(),
    };
  }
}