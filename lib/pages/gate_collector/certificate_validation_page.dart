import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:toastification/toastification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/gate_service.dart';
import '../../services/user_service.dart';

class CertificateValidationPage extends StatefulWidget {
  const CertificateValidationPage({super.key});

  @override
  State<CertificateValidationPage> createState() =>
      _CertificateValidationPageState();
}

class _CertificateValidationPageState extends State<CertificateValidationPage> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanning = true;
  bool _isValidating = false;
  Map<String, dynamic>? _lastValidationResult;

  @override
  void initState() {
    super.initState();
    // Start scanning immediately
    _isScanning = true;
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _validateCertificateByQr(String qrCode) async {
    if (_isValidating) return;

    setState(() {
      _isValidating = true;
      _isScanning = false;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser!;

      // Get user profile to get the actual name
      final userProfile = await UserService.getUserProfile(user.id);
      String gateCollectorName;
      if (userProfile != null) {
        gateCollectorName = userProfile.fullName;
      } else {
        // Create user profile if it doesn't exist
        await Supabase.instance.client.from('user_profiles').upsert({
          'user_id': user.id,
          'email': user.email ?? '',
          'full_name': user.userMetadata?['full_name'] ?? 'Gate Collector User',
          'role': 'gate_collector',
          'is_active': true,
        }, onConflict: 'user_id');
        gateCollectorName =
            user.userMetadata?['full_name'] ?? 'Gate Collector User';
      }

      final result = await GateService.validateCertificateByQr(
        qrCode: qrCode,
        gateCollectorId: user.id,
        gateCollectorName: gateCollectorName,
      );

      if (mounted) {
        setState(() {
          _lastValidationResult = result;
          _isValidating = false;
        });

        if (result['success'] == true) {
          toastification.show(
            context: context,
            type: ToastificationType.success,
            style: ToastificationStyle.flat,
            title: const Text('✅ Certificate Valid'),
            description: Text('${result['message']}'),
            alignment: Alignment.topRight,
            autoCloseDuration: const Duration(seconds: 4),
          );
        } else {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            style: ToastificationStyle.flat,
            title: const Text('❌ Certificate Invalid'),
            description: Text('${result['message']}'),
            alignment: Alignment.topRight,
            autoCloseDuration: const Duration(seconds: 4),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isValidating = false);
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          title: const Text('Validation Error'),
          description: Text('Failed to validate certificate: $e'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null && _isScanning && !_isValidating) {
        _validateCertificateByQr(barcode.rawValue!);
        break;
      }
    }
  }

  void _resumeScanning() {
    setState(() {
      _isScanning = true;
      _lastValidationResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Blue Header Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                Expanded(
                  child: Text(
                    'Certificate Validation',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  onPressed: _resumeScanning,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Resume Scanning',
                ),
              ],
            ),
          ),
          // Scanner Content
          Expanded(
            child: Stack(
              children: [
                // Camera Scanner
                if (_isScanning && !_isValidating)
                  MobileScanner(
                    controller: cameraController,
                    onDetect: _onDetect,
                  ),

                // Scanning Overlay
                if (_isScanning && !_isValidating)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Stack(
                              children: [
                                // Corner indicators
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                          color: Colors.green,
                                          width: 4,
                                        ),
                                        left: BorderSide(
                                          color: Colors.green,
                                          width: 4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                          color: Colors.green,
                                          width: 4,
                                        ),
                                        right: BorderSide(
                                          color: Colors.green,
                                          width: 4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.green,
                                          width: 4,
                                        ),
                                        left: BorderSide(
                                          color: Colors.green,
                                          width: 4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.green,
                                          width: 4,
                                        ),
                                        right: BorderSide(
                                          color: Colors.green,
                                          width: 4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Point camera at QR code',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Automatically scanning for QR codes...',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Loading Overlay
                if (_isValidating)
                  Container(
                    color: Colors.black.withValues(alpha: 0.7),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                          SizedBox(height: 24),
                          Text(
                            'Validating Certificate...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Validation Result Overlay
                if (_lastValidationResult != null && !_isValidating)
                  Container(
                    color: Colors.black.withValues(alpha: 0.8),
                    child: Center(
                      child: Card(
                        margin: const EdgeInsets.all(24),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _lastValidationResult!['success'] == true
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color:
                                    _lastValidationResult!['success'] == true
                                        ? Colors.green
                                        : Colors.red,
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _lastValidationResult!['success'] == true
                                    ? 'Certificate Valid'
                                    : 'Certificate Invalid',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      _lastValidationResult!['success'] == true
                                          ? Colors.green
                                          : Colors.red,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _lastValidationResult!['message'] ??
                                    'No message',
                                style: Theme.of(context).textTheme.bodyLarge,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed:
                                          () => Navigator.of(context).pop(),
                                      child: const Text('Close'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: _resumeScanning,
                                      child: const Text('Scan Another'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
