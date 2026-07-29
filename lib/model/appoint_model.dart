enum AppointmentStatus { pending, confirmed, completed, cancelled }

class AppointModel {
  final String appointId;
  final String donorProfId;
  final String hospiName;
  final String locationAddress;
  final DateTime scheduledDateTime;
  final AppointmentStatus stats;
  final String? qrCodePayload;

  AppointModel({
    required this.appointId,
    required this.donorProfId,
    required this.hospiName,
    required this.locationAddress,
    required this.scheduledDateTime,
    this.stats = AppointmentStatus.pending,
    this.qrCodePayload,
  });

  factory AppointModel.fromJson(Map<String, dynamic> json) {
    return AppointModel(
      appointId: json['appointment_id'] as String,
      donorProfId: json['donor_profile_id'] as String,
      hospiName: json['hospital_name'] as String,
      locationAddress: json['location_address'] as String,
      scheduledDateTime: DateTime.parse(json['scheduled_date_time'] as String),
      stats: AppointmentStatus.values.firstWhere(
            (e) => e.name == json['status'],
        orElse: () => AppointmentStatus.pending,
      ),
      qrCodePayload: json['qr_code_payload'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appointment_id': appointId,
      'donor_profile_id': donorProfId,
      'hospital_name': hospiName,
      'location_address': locationAddress,
      'scheduled_date_time': scheduledDateTime.toIso8601String(),
      'status': stats.name,
      'qr_code_payload': qrCodePayload,
    };
  }
}