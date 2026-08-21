enum UrgencyLevel { critical, urgent, normal }

class BloodBroadcastNotification {
  final String id;
  // The specific hospital this broadcast came from — null only for
  // notifications that predate this field (shouldn't happen in practice,
  // every row comes from a real hospital-scoped blood_requests join, see
  // listMyNotifications). Needed so "accept slot" can pre-select the right
  // hospital instead of dropping the donor into a blank picker.
  final String? hospitalId;
  final String hospitalName;
  final String bloodType;
  final int unitsNeeded;
  final int unitsFulfilled;
  // OPEN / PARTIALLY_FULFILLED / FULFILLED / CANCELLED (blood_requests.status)
  // — lets the UI grey out "accept" once a request the donor was notified
  // about has already been closed out by someone else.
  final String requestStatus;
  final UrgencyLevel urgency;
  final String location;
  final DateTime timestamp;
  bool isRead;
  final bool smsDispatched;

  BloodBroadcastNotification({
    required this.id,
    this.hospitalId,
    required this.hospitalName,
    required this.bloodType,
    required this.unitsNeeded,
    this.unitsFulfilled = 0,
    this.requestStatus = 'OPEN',
    required this.urgency,
    required this.location,
    required this.timestamp,
    this.isRead = false,
    this.smsDispatched = true,
  });

  bool get isStillOpen => requestStatus == 'OPEN' || requestStatus == 'PARTIALLY_FULFILLED';

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

  /// Maps GET /api/donor/notifications' actual response shape
  /// (listMyNotifications, donorPortal.controller.js) — camelCase keys
  /// keyed off requestId, not the snake_case placeholder shape this used to
  /// expect (which never matched anything real, since nothing ever called
  /// this before now).
  factory BloodBroadcastNotification.fromJson(Map<String, dynamic> json) {
    final unitsNeeded = json['unitsNeeded'] is num ? (json['unitsNeeded'] as num).toInt() : 1;
    final unitsFulfilled = json['unitsFulfilled'] is num ? (json['unitsFulfilled'] as num).toInt() : 0;
    return BloodBroadcastNotification(
      id: (json['requestId'] ?? '').toString(),
      hospitalId: json['hospitalId'] as String?,
      hospitalName: (json['hospitalName'] as String?) ?? 'Medical Center',
      bloodType: (json['bloodType'] as String?) ?? 'O+',
      unitsNeeded: unitsNeeded,
      unitsFulfilled: unitsFulfilled,
      requestStatus: (json['status'] as String?) ?? 'OPEN',
      urgency: _parseUrgency(json['priority']),
      location: (json['ward'] as String?)?.trim().isNotEmpty == true ? json['ward'] as String : 'General Ward',
      timestamp: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      // The backend only ever creates a notification row as part of
      // notifyDonorsForRequest actually attempting SMS/email dispatch — if
      // this row exists at all, dispatch was attempted for real.
      smsDispatched: true,
    );
  }

  static UrgencyLevel _parseUrgency(dynamic val) {
    final str = val.toString().toLowerCase();
    if (str.contains('crit') || str.contains('emerg')) return UrgencyLevel.critical;
    if (str.contains('urg')) return UrgencyLevel.urgent;
    return UrgencyLevel.normal;
  }
}