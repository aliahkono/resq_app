class ClinicalVitalsRecord {
  final double hemoglobin;
  final String bloodPressure;
  final int pulseRate;
  final double bodyTemp;
  final DateTime recordedDate;
  final String medTechName;
  final String facility;

  const ClinicalVitalsRecord({
    required this.hemoglobin,
    required this.bloodPressure,
    required this.pulseRate,
    required this.bodyTemp,
    required this.recordedDate,
    this.medTechName = 'Clinical Staff',
    this.facility = 'ResQ Partner Facility',
  });

  String get hemoglobinStatus {
    if (hemoglobin < 12.5) return 'Low';
    if (hemoglobin > 17.5) return 'High';
    return 'Normal';
  }

  factory ClinicalVitalsRecord.fromJson(Map<String, dynamic> json) {
    return ClinicalVitalsRecord(
      hemoglobin: (json['hemoglobin'] as num?)?.toDouble() ?? 13.5,
      bloodPressure: json['blood_pressure']?.toString() ?? '120/80',
      pulseRate: (json['pulse_rate'] as num?)?.toInt() ?? 72,
      bodyTemp: (json['body_temp'] as num?)?.toDouble() ?? 36.6,
      recordedDate: json['recorded_date'] != null
          ? DateTime.parse(json['recorded_date'])
          : DateTime.now(),
      medTechName: json['medtech_name'] ?? 'Clinical Staff',
      facility: json['facility'] ?? 'ResQ Center',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hemoglobin': hemoglobin,
      'blood_pressure': bloodPressure,
      'pulse_rate': pulseRate,
      'body_temp': bodyTemp,
      'recorded_date': recordedDate.toIso8601String(),
      'medtech_name': medTechName,
      'facility': facility,
    };
  }
}