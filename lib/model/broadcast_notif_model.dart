enum UrgencyLevel { critical, urgent, normal }

class BloodBroadcastNotification {
  final String id;
  final String hospitalName;
  final String bloodType;
  final int unitsNeeded;
  final UrgencyLevel urgency;
  final String location;
  final DateTime timestamp;
  bool isRead;
  final bool smsDispatched;

  BloodBroadcastNotification({
    required this.id,
    required this.hospitalName,
    required this.bloodType,
    required this.unitsNeeded,
    required this.urgency,
    required this.location,
    required this.timestamp,
    this.isRead = false,
    this.smsDispatched = true,
  });

  String get urgencyLabel {
    switch (urgency) {
      case UrgencyLevel.critical:
        return 'EMERGENCY (CRITICAL)';
      case UrgencyLevel.urgent:
        return 'URGENT';
      case UrgencyLevel.normal:
        return 'NORMAL ROUTINE';
    }
  }

  factory BloodBroadcastNotification.fromJson(Map<String, dynamic> json) {
    return BloodBroadcastNotification(
      id: json['id'] ?? '',
      hospitalName: json['hospital_name'] ?? 'Medical Center',
      bloodType: json['blood_type'] ?? 'O+',
      unitsNeeded: json['units_needed'] ?? 1,
      urgency: _parseUrgency(json['urgency']),
      location: json['location'] ?? 'Lucena City',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isRead: json['is_read'] ?? false,
      smsDispatched: json['sms_dispatched'] ?? true,
    );
  }

  static UrgencyLevel _parseUrgency(dynamic val) {
    final str = val.toString().toLowerCase();
    if (str.contains('crit') || str.contains('emerg')) return UrgencyLevel.critical;
    if (str.contains('urg')) return UrgencyLevel.urgent;
    return UrgencyLevel.normal;
  }
}