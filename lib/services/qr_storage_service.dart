import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRStorageService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Generate QR code image and upload to Supabase Storage
  static Future<String> generateAndUploadQRCode({
    required String data,
    required String fileName,
    int size = 200,
  }) async {
    try {
      // Generate QR code image
      final qrImage = await _generateQRImage(data, size);

      // Upload to Supabase Storage
      final filePath = 'qr-codes/$fileName.png';
      final uploadResponse = await _supabase.storage
          .from('public')
          .uploadBinary(
            filePath,
            qrImage,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: true,
            ),
          );

      if (uploadResponse.isNotEmpty) {
        // Get public URL
        final publicUrl = _supabase.storage
            .from('public')
            .getPublicUrl(filePath);

        return publicUrl;
      } else {
        throw Exception('Failed to upload QR code to storage');
      }
    } catch (e) {
      // Fallback to string token if upload fails
      return 'QR-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Generate QR code as PNG image bytes
  static Future<Uint8List> _generateQRImage(String data, int size) async {
    try {
      // Use QrPainter directly for better control
      final qrPainter = QrPainter(
        data: data,
        version: QrVersions.auto,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      );

      final picData = await qrPainter.toImageData(size.toDouble());
      return picData!.buffer.asUint8List();
    } catch (e) {
      throw Exception('Failed to generate QR code image: $e');
    }
  }

  /// Delete QR code from storage
  static Future<void> deleteQRCode(String filePath) async {
    try {
      await _supabase.storage.from('public').remove([filePath]);
    } catch (e) {
      // Ignore errors for cleanup operations
    }
  }

  /// Get QR code URL from storage path
  static String getQRCodeUrl(String filePath) {
    return _supabase.storage.from('public').getPublicUrl(filePath);
  }
}
