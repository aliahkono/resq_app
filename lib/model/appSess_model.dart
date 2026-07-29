class AppSessModel {
  final String activeDonorId;
  final bool notifEnabled;
  final DateTime lastActiveTime;

  AppSessModel({
    required this.activeDonorId,
    this.notifEnabled = true,
    DateTime? lastActiveTime,
  }) : lastActiveTime = lastActiveTime ?? DateTime.now();

  /// Factory constructor to deserialize session state from local storage (e.g. SharedPreferences)
  factory AppSessModel.fromJson(Map<String, dynamic> json) {
    return AppSessModel(
      activeDonorId: json['active_donor_id'] as String,
      notifEnabled: json['notifications_enabled'] as bool? ?? true,
      lastActiveTime: DateTime.parse(json['last_active_time'] as String),
    );
  }

  /// Serialize session object into JSON for local persistence
  Map<String, dynamic> toJson() {
    return {
      'active_donor_id': activeDonorId,
      'notifications_enabled': notifEnabled,
      'last_active_time': lastActiveTime.toIso8601String(),
    };
  }
}