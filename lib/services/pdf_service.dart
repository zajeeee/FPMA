import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import '../models/payment_models.dart';
import '../models/fish_product.dart';

class PdfService {
  static Future<void> printOrderOfPayment({
    required OrderOfPayment order,
    required FishProduct? product,
  }) async {
    final bytes = await _buildOrderPdf(order: order, product: product);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> printOfficialReceipt({
    required OfficialReceipt receipt,
  }) async {
    final bytes = await _buildReceiptPdf(receipt: receipt);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<void> printClearingCertificate({
    required ClearingCertificate certificate,
  }) async {
    final bytes = await _buildCertificatePdf(certificate: certificate);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<Uint8List> _buildOrderPdf({
    required OrderOfPayment order,
    required FishProduct? product,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Order of Payment',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Divider(),
                pw.SizedBox(height: 8),
                pw.Text('Order Number: ${order.orderNumber}'),
                pw.Text('Collector: ${order.collectorName}'),
                if (order.qrCode != null) pw.Text('QR: ${order.qrCode}'),
                pw.Text('Amount: ₱${order.amount.toStringAsFixed(2)}'),
                pw.Text('Status: ${order.status}'),
                pw.SizedBox(height: 16),
                pw.Text(
                  'Fish Product',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Species: ${FishSpecies.fromString(product?.species ?? '').displayName}',
                ),
                pw.Text(
                  'Weight: ${product?.weight != null ? '${product!.weight} kg' : '—'}',
                ),
                pw.Text('Size: ${product?.size ?? '—'}'),
              ],
            ),
          );
        },
      ),
    );
    return doc.save();
  }

  static Future<Uint8List> _buildReceiptPdf({
    required OfficialReceipt receipt,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Official Receipt',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Divider(),
                pw.SizedBox(height: 8),
                pw.Text('Receipt No.: ${receipt.receiptNumber}'),
                pw.Text(
                  'Amount Paid: ₱${receipt.amountPaid.toStringAsFixed(2)}',
                ),
                pw.Text('Teller: ${receipt.tellerName}'),
                pw.Text('Payment Date: ${receipt.paymentDate}'),
              ],
            ),
          );
        },
      ),
    );
    return doc.save();
  }

  static Future<Uint8List> _buildCertificatePdf({
    required ClearingCertificate certificate,
  }) async {
    // Try to fetch QR image bytes if the QR code is a URL
    Uint8List? qrBytes;
    if (certificate.qrCode != null && certificate.qrCode!.startsWith('http')) {
      try {
        final response = await http.get(Uri.parse(certificate.qrCode!));
        if (response.statusCode == 200) {
          qrBytes = response.bodyBytes;
        }
      } catch (_) {
        // Ignore errors and fall back to showing the QR text
        qrBytes = null;
      }
    }

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Clearing Certificate',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Divider(),
                pw.SizedBox(height: 8),
                pw.Text('Certificate No.: ${certificate.certificateNumber}'),
                if (qrBytes != null) ...[
                  pw.SizedBox(height: 12),
                  pw.Center(
                    child: pw.Image(
                      pw.MemoryImage(qrBytes),
                      width: 180,
                      height: 180,
                    ),
                  ),
                ] else if (certificate.qrCode != null) ...[
                  pw.SizedBox(height: 4),
                  pw.Text('QR: ${certificate.qrCode}'),
                ],
                pw.Text('Status: ${certificate.status}'),
                pw.Text('Validated By: ${certificate.validatedBy ?? '—'}'),
                pw.Text('Validated At: ${certificate.validatedAt ?? '—'}'),
              ],
            ),
          );
        },
      ),
    );
    return doc.save();
  }
}
