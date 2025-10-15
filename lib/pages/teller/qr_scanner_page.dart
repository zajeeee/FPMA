import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:toastification/toastification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/payment_models.dart';
import '../../services/payment_service.dart';
import '../../services/user_service.dart';
import '../../widgets/qr_code_widget.dart';
import '../../services/activity_log_service.dart';

class TellerQRScannerPage extends StatefulWidget {
  const TellerQRScannerPage({super.key});

  @override
  State<TellerQRScannerPage> createState() => _TellerQRScannerPageState();
}

class _TellerQRScannerPageState extends State<TellerQRScannerPage> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanning = true;
  bool _isProcessing = false;
  final TextEditingController _manualQRController = TextEditingController();
  bool _showManualInput = false;

  @override
  void dispose() {
    cameraController.dispose();
    _manualQRController.dispose();
    super.dispose();
  }

  Future<void> _processScannedQR(String qrCode) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _isScanning = false;
    });

    try {
      // Find order by QR code
      final order = await PaymentService.getOrderByQRCode(qrCode);

      if (order == null) {
        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            style: ToastificationStyle.flat,
            title: const Text('❌ Order Not Found'),
            description: const Text(
              'This QR code does not match any Order of Payment',
            ),
            alignment: Alignment.topRight,
            autoCloseDuration: const Duration(seconds: 4),
          );
        }
        return;
      }

      if (order.status != 'pending') {
        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.warning,
            style: ToastificationStyle.flat,
            title: const Text('⚠️ Order Already Processed'),
            description: Text('This order is already ${order.status}'),
            alignment: Alignment.topRight,
            autoCloseDuration: const Duration(seconds: 4),
          );
        }
        return;
      }

      // Order found and ready for processing

      if (mounted) {
        _showOrderDetailsDialog(order);
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          title: const Text('Processing Error'),
          description: Text('Failed to process QR code: $e'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showOrderDetailsDialog(OrderOfPayment order) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Order of Payment Details')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Payment Summary Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Summary',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow('Order Number', order.orderNumber),
                        _buildDetailRow(
                          'Amount Due',
                          '₱${order.amount.toStringAsFixed(2)}',
                          isHighlighted: true,
                        ),
                        _buildDetailRow(
                          'Quantity',
                          '${order.quantity ?? 'N/A'} pieces',
                        ),
                        _buildDetailRow('Collector', order.collectorName),
                        _buildDetailRow('Status', order.status.toUpperCase()),
                        if (order.dueDate != null)
                          _buildDetailRow(
                            'Due Date',
                            _formatDate(order.dueDate!),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Vessel and Fish Information
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _getOrderDetails(order.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (snapshot.hasError || snapshot.data == null) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.orange.shade600,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Vessel and fish details not available',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final details = snapshot.data!;
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vessel & Fish Information',
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (details['vessel_name'] != null)
                              _buildDetailRow(
                                'Vessel Name',
                                details['vessel_name'],
                              ),
                            if (details['fish_type'] != null)
                              _buildDetailRow(
                                'Fish Type',
                                details['fish_type'],
                              ),
                            if (details['vessel_registration'] != null)
                              _buildDetailRow(
                                'Vessel Registration',
                                details['vessel_registration'],
                              ),
                            if (details['weight'] != null)
                              _buildDetailRow(
                                'Weight',
                                '${details['weight']} kg',
                              ),
                            if (details['size'] != null)
                              _buildDetailRow('Size', details['size']),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                  _buildDetailRow('Created', _formatDate(order.createdAt)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _resetScanner();
                },
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _processPayment(order);
                },
                icon: const Icon(Icons.payment),
                label: const Text('Confirm Payment'),
              ),
            ],
          ),
    );
  }

  Future<void> _processPayment(OrderOfPayment order) async {
    setState(() => _isProcessing = true);

    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final userProfile = await UserService.getUserProfile(user.id);

      String tellerName;
      if (userProfile != null) {
        tellerName = userProfile.fullName;
      } else {
        // Create user profile if it doesn't exist
        await Supabase.instance.client.from('user_profiles').upsert({
          'user_id': user.id,
          'email': user.email ?? '',
          'full_name': user.userMetadata?['full_name'] ?? 'Teller User',
          'role': 'teller',
          'is_active': true,
        }, onConflict: 'user_id');

        // Get the updated profile
        final updatedProfile = await UserService.getUserProfile(user.id);
        tellerName = updatedProfile?.fullName ?? 'Teller User';
      }

      // Log activity: Payment processing started
      await ActivityLogService.logActivity(
        userId: user.id,
        userRole: 'teller',
        action: 'payment_processing_started',
        description:
            'Started processing payment for Order ${order.orderNumber}',
        referenceId: order.id,
        referenceType: 'order',
        metadata: {
          'order_number': order.orderNumber,
          'amount': order.amount,
          'collector_name': order.collectorName,
        },
      );

      final receipt = await PaymentService.createOfficialReceipt(
        orderId: order.id,
        tellerId: user.id,
        tellerName: tellerName,
        amountPaid: order.amount,
      );

      // Create clearing certificate with QR code
      final clearingCertificate =
          await PaymentService.createClearingCertificate(
            officialReceiptId: receipt.id,
            validatedByUserId: user.id,
          );

      // Mark order as paid
      await PaymentService.markOrderPaid(order.id);

      // Log activity: Payment completed successfully
      await ActivityLogService.logActivity(
        userId: user.id,
        userRole: 'teller',
        action: 'payment_completed',
        description:
            'Successfully processed payment and generated clearing certificate',
        referenceId: receipt.id,
        referenceType: 'receipt',
        metadata: {
          'receipt_number': receipt.receiptNumber,
          'certificate_number': clearingCertificate.certificateNumber,
          'amount_paid': receipt.amountPaid,
        },
      );

      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.flat,
          title: const Text('✅ Payment Confirmed — Certificate Generated'),
          description: Text(
            'Official Receipt: ${receipt.receiptNumber}\nClearing Certificate: ${clearingCertificate.certificateNumber}',
          ),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 5),
        );
        _showSuccessDialog(receipt, order, clearingCertificate);
      }
    } catch (e) {
      // Log activity: Payment processing failed
      try {
        await ActivityLogService.logActivity(
          userId: Supabase.instance.client.auth.currentUser!.id,
          userRole: 'teller',
          action: 'payment_processing_failed',
          description:
              'Failed to process payment for Order ${order.orderNumber}',
          referenceId: order.id,
          referenceType: 'order',
          metadata: {'error': e.toString(), 'order_number': order.orderNumber},
        );
      } catch (_) {
        // Ignore logging errors
      }

      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          title: const Text('❌ Payment Processing Failed'),
          description: Text('Failed to process payment: $e'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSuccessDialog(
    OfficialReceipt receipt,
    OrderOfPayment order,
    ClearingCertificate clearingCertificate,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 28),
                const SizedBox(width: 12),
                const Expanded(child: Text('Payment Processed Successfully')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success message
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Payment confirmed and clearing certificate generated!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Receipt details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Official Receipt',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          'Receipt Number',
                          receipt.receiptNumber,
                        ),
                        _buildDetailRow(
                          'Amount Paid',
                          '₱${receipt.amountPaid.toStringAsFixed(2)}',
                        ),
                        _buildDetailRow(
                          'Payment Date',
                          _formatDate(receipt.paymentDate),
                        ),
                        _buildDetailRow('Teller', receipt.tellerName),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Certificate details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Clearing Certificate',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          'Certificate Number',
                          clearingCertificate.certificateNumber,
                        ),
                        _buildDetailRow(
                          'Status',
                          clearingCertificate.status.toUpperCase(),
                        ),
                        if (clearingCertificate.qrCode != null) ...[
                          const SizedBox(height: 16),
                          Center(
                            child: QRCodeWidget(
                              data: clearingCertificate.qrCode!,
                              size: 150,
                              isUrl: clearingCertificate.qrCode!.startsWith(
                                'http',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                'Gate Collector will scan this QR code for validation',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _resetScanner();
                },
                child: const Text('Scan Another'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _resetScanner();
                },
                icon: const Icon(Icons.done),
                label: const Text('Done'),
              ),
            ],
          ),
    );
  }

  Future<Map<String, dynamic>?> _getOrderDetails(String orderId) async {
    try {
      final response =
          await Supabase.instance.client
              .from('orders')
              .select('''
            *,
            fish_products!fish_product_id(
              species,
              vessel_name,
              vessel_registration,
              weight,
              size,
              vessel_info
            )
          ''')
              .eq('id', orderId)
              .single();

      if (response['fish_products'] != null) {
        final fishProduct = response['fish_products'];
        return {
          'vessel_name': fishProduct['vessel_name'],
          'fish_type': fishProduct['species'],
          'vessel_registration': fishProduct['vessel_registration'],
          'weight': fishProduct['weight'],
          'size': fishProduct['size'],
          'vessel_info': fishProduct['vessel_info'],
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color:
                    isHighlighted
                        ? Theme.of(context).colorScheme.primary
                        : null,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                color:
                    isHighlighted
                        ? Theme.of(context).colorScheme.primary
                        : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _resetScanner() {
    setState(() {
      _isScanning = true;
      _isProcessing = false;
      _showManualInput = false;
      _manualQRController.clear();
    });
  }

  void _toggleManualInput() {
    setState(() {
      _showManualInput = !_showManualInput;
      if (!_showManualInput) {
        _manualQRController.clear();
      }
    });
  }

  void _processManualQR() {
    final qrCode = _manualQRController.text.trim();
    if (qrCode.isEmpty) {
      toastification.show(
        context: context,
        type: ToastificationType.warning,
        style: ToastificationStyle.flat,
        title: const Text('⚠️ Empty QR Code'),
        description: const Text('Please enter a valid QR code'),
        alignment: Alignment.topRight,
        autoCloseDuration: const Duration(seconds: 3),
      );
      return;
    }
    _processScannedQR(qrCode);
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        _processScannedQR(barcode.rawValue!);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Back',
                ),
                Expanded(
                  child: Text(
                    'Scan Order of Payment QR',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _showManualInput ? Icons.camera_alt : Icons.keyboard,
                    color: Colors.white,
                  ),
                  onPressed: _toggleManualInput,
                  tooltip: _showManualInput ? 'Use Camera' : 'Manual Input',
                ),
                IconButton(
                  icon: Icon(
                    _isScanning ? Icons.stop : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _isScanning = !_isScanning;
                    });
                  },
                  tooltip: _isScanning ? 'Stop Scanning' : 'Start Scanning',
                ),
              ],
            ),
          ),
          // Scanner or Manual Input
          Expanded(
            child:
                _showManualInput
                    ? _buildManualInputView()
                    : _isScanning
                    ? Stack(
                      children: [
                        MobileScanner(
                          controller: cameraController,
                          onDetect: _onDetect,
                        ),
                        if (_isProcessing)
                          Container(
                            color: Colors.black.withValues(alpha: 0.7),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Processing QR Code...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    )
                    : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Scanner Stopped',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the play button to start scanning',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _resetScanner,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reset Scanner'),
                          ),
                        ],
                      ),
                    ),
          ),
          // Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 24),
                const SizedBox(height: 8),
                const Text(
                  'Instructions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  _showManualInput
                      ? '1. Enter the Order of Payment QR code manually\n'
                          '2. Click "Process QR Code" to verify\n'
                          '3. Confirm payment details\n'
                          '4. Generate the Clearing Certificate QR code'
                      : '1. Ask the client to present their Order of Payment QR code\n'
                          '2. Point the camera at the QR code\n'
                          '3. The system will automatically process the payment\n'
                          '4. Generate the Clearing Certificate QR code for the client',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualInputView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Manual Input Icon
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.keyboard,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Manual QR Code Input',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the Order of Payment QR code manually',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // QR Code Input Field
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QR Code',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _manualQRController,
                    decoration: InputDecoration(
                      hintText: 'Enter Order of Payment QR code...',
                      prefixIcon: const Icon(Icons.qr_code),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _processManualQR(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _toggleManualInput,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Use Camera'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isProcessing ? null : _processManualQR,
                          icon:
                              _isProcessing
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.search),
                          label: Text(
                            _isProcessing ? 'Processing...' : 'Process QR Code',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Help Text
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.amber.shade700),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Tip: You can also copy and paste QR codes from other sources',
                    style: TextStyle(fontSize: 14),
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
