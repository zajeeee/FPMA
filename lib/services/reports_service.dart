import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/fish_product.dart';
import '../models/payment_models.dart';
import '../models/activity_log.dart';

class ReportsService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Export fish products to CSV
  static Future<String> exportFishProductsCSV() async {
    try {
      final response = await _supabase
          .from('fish_products')
          .select()
          .order('created_at', ascending: false);

      final products =
          (response as List).map((json) => FishProduct.fromJson(json)).toList();

      final csv = StringBuffer();

      // CSV Header
      csv.writeln(
        'ID,Species,Size,Weight,Vessel Name,Vessel Registration,Inspector,Status,QR Code,Created At',
      );

      // CSV Data
      for (final product in products) {
        csv.writeln(
          [
                product.id,
                product.species,
                product.size ?? '',
                product.weight?.toString() ?? '',
                product.vesselName ?? '',
                product.vesselRegistration ?? '',
                product.inspectorName,
                product.status,
                product.qrCode ?? '',
                product.createdAt.toIso8601String(),
              ]
              .map((field) => '"${field.toString().replaceAll('"', '""')}"')
              .join(','),
        );
      }

      return csv.toString();
    } catch (e) {
      return 'Error generating CSV: $e';
    }
  }

  /// Export orders to CSV
  static Future<String> exportOrdersCSV() async {
    try {
      final response = await _supabase
          .from('orders')
          .select()
          .order('created_at', ascending: false);

      final orders =
          (response as List)
              .map((json) => OrderOfPayment.fromJson(json))
              .toList();

      final csv = StringBuffer();

      // CSV Header
      csv.writeln('ID,Order Number,Amount,Collector Name,Status,Created At');

      // CSV Data
      for (final order in orders) {
        csv.writeln(
          [
                order.id,
                order.orderNumber,
                order.amount,
                order.collectorName,
                order.status,
                order.createdAt.toIso8601String(),
              ]
              .map((field) => '"${field.toString().replaceAll('"', '""')}"')
              .join(','),
        );
      }

      return csv.toString();
    } catch (e) {
      return 'Error generating CSV: $e';
    }
  }

  /// Export receipts to CSV
  static Future<String> exportReceiptsCSV() async {
    try {
      final response = await _supabase
          .from('receipts')
          .select()
          .order('created_at', ascending: false);

      final receipts =
          (response as List)
              .map((json) => OfficialReceipt.fromJson(json))
              .toList();

      final csv = StringBuffer();

      // CSV Header
      csv.writeln(
        'ID,Receipt Number,Amount Paid,Teller Name,Payment Date,Created At',
      );

      // CSV Data
      for (final receipt in receipts) {
        csv.writeln(
          [
                receipt.id,
                receipt.receiptNumber,
                receipt.amountPaid,
                receipt.tellerName,
                receipt.paymentDate,
                receipt.createdAt.toIso8601String(),
              ]
              .map((field) => '"${field.toString().replaceAll('"', '""')}"')
              .join(','),
        );
      }

      return csv.toString();
    } catch (e) {
      return 'Error generating CSV: $e';
    }
  }

  /// Export activity logs to CSV
  static Future<String> exportActivityLogsCSV() async {
    try {
      final response = await _supabase
          .from('activity_logs')
          .select()
          .order('created_at', ascending: false);

      final logs =
          (response as List).map((json) => ActivityLog.fromJson(json)).toList();

      final csv = StringBuffer();

      // CSV Header
      csv.writeln(
        'ID,User Role,Action,Description,Reference ID,Reference Type,Created At',
      );

      // CSV Data
      for (final log in logs) {
        csv.writeln(
          [
                log.id,
                log.userRole,
                log.action,
                log.description ?? '',
                log.referenceId ?? '',
                log.referenceType ?? '',
                log.createdAt.toIso8601String(),
              ]
              .map((field) => '"${field.toString().replaceAll('"', '""')}"')
              .join(','),
        );
      }

      return csv.toString();
    } catch (e) {
      return 'Error generating CSV: $e';
    }
  }

  /// Generate comprehensive PDF report
  static Future<void> generateComprehensivePDF() async {
    try {
      // Fetch data
      final fishProducts = await _getFishProducts();
      final orders = await _getOrders();
      final receipts = await _getReceipts();
      final activityLogs = await _getActivityLogs();

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              _buildPDFHeader(),
              pw.SizedBox(height: 20),
              _buildSummarySection(
                fishProducts,
                orders,
                receipts,
                activityLogs,
              ),
              pw.SizedBox(height: 20),
              _buildFishProductsSection(fishProducts),
              pw.SizedBox(height: 20),
              _buildOrdersSection(orders),
              pw.SizedBox(height: 20),
              _buildReceiptsSection(receipts),
              pw.SizedBox(height: 20),
              _buildActivityLogsSection(activityLogs),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'FPMS_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      throw Exception('Failed to generate PDF: $e');
    }
  }

  static pw.Widget _buildPDFHeader() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Fish Product Monitoring System',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Comprehensive System Report',
            style: pw.TextStyle(fontSize: 16, color: PdfColors.blue700),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated on: ${DateTime.now().toString()}',
            style: pw.TextStyle(fontSize: 12, color: PdfColors.blue600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummarySection(
    List<FishProduct> fishProducts,
    List<OrderOfPayment> orders,
    List<OfficialReceipt> receipts,
    List<ActivityLog> activityLogs,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'System Summary',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                'Fish Products',
                fishProducts.length.toString(),
              ),
              _buildSummaryItem('Orders', orders.length.toString()),
              _buildSummaryItem('Receipts', receipts.length.toString()),
              _buildSummaryItem('Activities', activityLogs.length.toString()),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue800,
          ),
        ),
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
        ),
      ],
    );
  }

  static pw.Widget _buildFishProductsSection(List<FishProduct> products) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Fish Products (${products.length})',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Species',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Weight',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Status',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Created',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
            ...products
                .take(10)
                .map(
                  (product) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(product.species),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(product.weight?.toString() ?? 'N/A'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(product.status),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          product.createdAt.toString().split(' ')[0],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildOrdersSection(List<OrderOfPayment> orders) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Orders of Payment (${orders.length})',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Order #',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Amount',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Collector',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Status',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
            ...orders
                .take(10)
                .map(
                  (order) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(order.orderNumber),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('₱${order.amount.toStringAsFixed(2)}'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(order.collectorName),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(order.status),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildReceiptsSection(List<OfficialReceipt> receipts) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Official Receipts (${receipts.length})',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Receipt #',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Amount',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Teller',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Date',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
            ...receipts
                .take(10)
                .map(
                  (receipt) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(receipt.receiptNumber),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '₱${receipt.amountPaid.toStringAsFixed(2)}',
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(receipt.tellerName),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          receipt.paymentDate.toString().split(' ')[0],
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildActivityLogsSection(List<ActivityLog> logs) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Recent Activities (${logs.length})',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Role',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Action',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Description',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    'Time',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
            ...logs
                .take(10)
                .map(
                  (log) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(log.userRole),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(log.action),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(log.description ?? ''),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(log.createdAt.toString().split(' ')[1]),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ],
    );
  }

  // Helper methods to fetch data
  static Future<List<FishProduct>> _getFishProducts() async {
    try {
      final response = await _supabase
          .from('fish_products')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      return (response as List)
          .map((json) => FishProduct.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<List<OrderOfPayment>> _getOrders() async {
    try {
      final response = await _supabase
          .from('orders')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      return (response as List)
          .map((json) => OrderOfPayment.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<List<OfficialReceipt>> _getReceipts() async {
    try {
      final response = await _supabase
          .from('receipts')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      return (response as List)
          .map((json) => OfficialReceipt.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<List<ActivityLog>> _getActivityLogs() async {
    try {
      final response = await _supabase
          .from('activity_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      return (response as List)
          .map((json) => ActivityLog.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }
}
