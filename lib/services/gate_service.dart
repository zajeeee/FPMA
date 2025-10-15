import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment_models.dart';
import '../models/activity_log.dart';

class GateService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Get recent certificates
  static Future<List<ClearingCertificate>> getRecentCertificates({
    int limit = 10,
  }) async {
    final response = await _supabase
        .from('clearing_certificates')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(
      response,
    ).map(ClearingCertificate.fromJson).toList();
  }

  // Get recent activity logs
  static Future<List<ActivityLog>> getRecentActivity({int limit = 10}) async {
    final response = await _supabase
        .from('activity_logs')
        .select()
        .order('timestamp', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(
      response,
    ).map(ActivityLog.fromJson).toList();
  }

  // Validate certificate by QR code
  static Future<Map<String, dynamic>> validateCertificateByQr({
    required String qrCode,
    required String gateCollectorId,
    required String gateCollectorName,
  }) async {
    try {
      // Find certificate by QR code
      final certificateResponse =
          await _supabase
              .from('clearing_certificates')
              .select()
              .eq('qr_code', qrCode)
              .single();

      final certificate = ClearingCertificate.fromJson(certificateResponse);

      // Check if certificate is valid
      bool isValid = false;
      String message = '';

      if (certificate.status == 'generated') {
        // Certificate is newly generated and ready for validation
        // Check if certificate is not expired (valid for 24 hours from creation)
        final now = DateTime.now();
        final certificateAge = now.difference(certificate.createdAt);

        if (certificateAge.inHours <= 24) {
          isValid = true;
          message = 'Certificate is valid and ready for gate clearance';

          // Update certificate status to validated
          await _supabase
              .from('clearing_certificates')
              .update({
                'status': 'validated',
                'validated_at': now.toIso8601String(),
                'validated_by': gateCollectorId,
              })
              .eq('id', certificate.id);
        } else {
          isValid = false;
          message = 'Certificate has expired (older than 24 hours)';

          // Update certificate status to expired
          await _supabase
              .from('clearing_certificates')
              .update({'status': 'expired'})
              .eq('id', certificate.id);
        }
      } else if (certificate.status == 'validated') {
        // Certificate was already validated, check if still within grace period
        final now = DateTime.now();
        final validationAge = now.difference(certificate.validatedAt!);

        if (validationAge.inHours <= 1) {
          // 1 hour grace period for already validated certificates
          isValid = true;
          message =
              'Certificate was already validated and is still within grace period';
        } else {
          isValid = false;
          message =
              'Certificate validation has expired (grace period exceeded)';
        }
      } else if (certificate.status == 'expired') {
        isValid = false;
        message = 'Certificate has expired and cannot be used';
      } else {
        isValid = false;
        message = 'Certificate status is invalid';
      }

      // Log the validation activity
      await _logActivity(
        certificateId: certificate.id,
        gateCollectorId: gateCollectorId,
        gateCollectorName: gateCollectorName,
        validationResult: isValid ? 'success' : 'fail',
        message: message,
      );

      return {
        'success': isValid,
        'message': message,
        'certificate': certificate,
      };
    } catch (e) {
      // Log failed validation attempt
      await _logActivity(
        certificateId: 'unknown',
        gateCollectorId: gateCollectorId,
        gateCollectorName: gateCollectorName,
        validationResult: 'fail',
        message: 'QR code not found or invalid: $e',
      );

      return {
        'success': false,
        'message': 'QR code not found or invalid',
        'error': e.toString(),
      };
    }
  }

  // Log gate activity
  static Future<void> _logActivity({
    required String certificateId,
    required String gateCollectorId,
    required String gateCollectorName,
    required String validationResult,
    required String message,
  }) async {
    await _supabase.from('activity_logs').insert({
      'certificate_id': certificateId,
      'gate_collector_id': gateCollectorId,
      'gate_collector_name': gateCollectorName,
      'validation_result': validationResult,
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Get certificate details with related data
  static Future<Map<String, dynamic>?> getCertificateDetails(
    String certificateId,
  ) async {
    try {
      final response =
          await _supabase
              .from('clearing_certificates')
              .select('''
            *,
            receipts:official_receipt_id (
              *,
              orders:order_id (
                *,
                fish_products:fish_product_id (
                  *
                )
              )
            )
          ''')
              .eq('id', certificateId)
              .single();

      return response;
    } catch (e) {
      return null;
    }
  }

  // Get activity logs for a specific certificate
  static Future<List<ActivityLog>> getCertificateActivity(
    String certificateId,
  ) async {
    final response = await _supabase
        .from('activity_logs')
        .select()
        .eq('certificate_id', certificateId)
        .order('timestamp', ascending: false);

    return List<Map<String, dynamic>>.from(
      response,
    ).map(ActivityLog.fromJson).toList();
  }
}
