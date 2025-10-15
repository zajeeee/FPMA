class ActivityLog {
  final String id;
  final String certificateId;
  final String gateCollectorId;
  final String gateCollectorName;
  final String validationResult; // success | fail
  final String message;
  final DateTime timestamp;

  ActivityLog({
    required this.id,
    required this.certificateId,
    required this.gateCollectorId,
    required this.gateCollectorName,
    required this.validationResult,
    required this.message,
    required this.timestamp,
  });

  // Compatibility getters for reports service
  String get userRole => 'gate_collector'; // Gate collector role
  String get action => 'certificate_validation'; // Action type
  String? get description => message; // Use message as description
  String? get referenceId => certificateId; // Use certificate ID as reference
  String? get referenceType => 'clearing_certificate'; // Reference type
  DateTime get createdAt => timestamp; // Use timestamp as createdAt

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'],
      certificateId: json['certificate_id'],
      gateCollectorId: json['gate_collector_id'],
      gateCollectorName: json['gate_collector_name'],
      validationResult: json['validation_result'],
      message: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'certificate_id': certificateId,
      'gate_collector_id': gateCollectorId,
      'gate_collector_name': gateCollectorName,
      'validation_result': validationResult,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
