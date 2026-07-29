class BloodReqModel {
  final String reqId;
  final String hospiName;
  final String bloodType;
  final int unitsRequire;
  final double urgencyPrio; // this is for the priority score for min-heap
  final String locationAddress;
  final double latitude;
  final double longitude;
  final DateTime requestedAt;

  BloodReqModel({
    required this.reqId,
    required this.hospiName,
    required this.bloodType,
    required this.unitsRequire,
    required this.urgencyPrio,
    required this.locationAddress,
    required this.latitude,
    required this.longitude,
    required this.requestedAt,
  });

  factory BloodReqModel.fromJson(Map<String, dynamic> json) {
    return BloodReqModel(
      reqId: json['request_id'] as String,
      hospiName: json['hospital_name'] as String,
      bloodType: json['blood_type'] as String,
      unitsRequire: json['units_required'] as int,
      urgencyPrio: (json['urgency_priority'] as num).toDouble(),
      locationAddress: json['location_address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      requestedAt: DateTime.parse(json['requested_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'request_id': reqId,
      'hospital_name': hospiName,
      'blood_type': bloodType,
      'units_required': unitsRequire,
      'urgency_priority': urgencyPrio,
      'location_address': locationAddress,
      'latitude': latitude,
      'longitude': longitude,
      'requested_at': requestedAt.toIso8601String(),
    };
  }
}