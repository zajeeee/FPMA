import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toastification/toastification.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../models/payment_models.dart';
import '../../widgets/qr_code_widget.dart';

class CollectorReportsPage extends StatefulWidget {
  const CollectorReportsPage({super.key});

  @override
  State<CollectorReportsPage> createState() => _CollectorReportsPageState();
}

class _CollectorReportsPageState extends State<CollectorReportsPage> {
  List<OrderOfPayment> _orders = [];
  List<OrderOfPayment> _filteredOrders = [];
  bool _isLoading = true;
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;
  String _selectedStatus = 'all';
  // Filter options
  final List<String> _statusOptions = ['all', 'pending', 'issued', 'paid'];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      // Fetch orders belonging to the signed-in collector
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            style: ToastificationStyle.flat,
            title: const Text('Not signed in'),
            description: const Text('Please log in again to view reports.'),
            alignment: Alignment.topRight,
            autoCloseDuration: const Duration(seconds: 4),
          );
        }
        return;
      }
      final response = await client
          .from('orders')
          .select('''
            id,
            order_number,
            amount,
            status,
            qr_code,
            created_at,
            updated_at,
            fish_product_id,
            collector_id,
            collector_name
          ''')
          .eq('collector_id', currentUser.id)
          .order('created_at', ascending: false);

      final orders =
          (response as List)
              .map((json) => OrderOfPayment.fromJson(json))
              .toList();

      // Debug logging removed to satisfy lints

      setState(() {
        _orders = orders;
        _filteredOrders = orders;
        _isLoading = false;
      });

      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.flat,
          title: const Text('Reports Loaded'),
          description: const Text('Order reports loaded successfully'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      debugPrint('Error loading collector reports: $e');
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          title: const Text('Error'),
          description: Text('Failed to load reports: $e'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
      setState(() => _isLoading = false);
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          title: const Text('Error'),
          description: const Text('Failed to load reports'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredOrders =
          _orders.where((order) {
            // Search filter
            final matchesSearch =
                _searchQuery.isEmpty ||
                order.orderNumber.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                order.collectorName.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );

            // Status filter
            final matchesStatus =
                _selectedStatus == 'all' || order.status == _selectedStatus;

            // Date range filter
            final matchesDate =
                _selectedDateRange == null ||
                (order.createdAt.isAfter(
                      _selectedDateRange!.start.subtract(
                        const Duration(days: 1),
                      ),
                    ) &&
                    order.createdAt.isBefore(
                      _selectedDateRange!.end.add(const Duration(days: 1)),
                    ));

            return matchesSearch && matchesStatus && matchesDate;
          }).toList();
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final last30 = now.subtract(const Duration(days: 30));
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: now,
      initialDateRange:
          _selectedDateRange ?? DateTimeRange(start: last30, end: now),
    );
    if (range != null) {
      setState(() {
        _selectedDateRange = range;
        _applyFilters();
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedDateRange = null;
      _selectedStatus = 'all';
      _filteredOrders = _orders;
    });
  }

  Future<void> _exportToCSV() async {
    try {
      final csvData = <List<dynamic>>[
        [
          'Order No',
          'Vessel Name',
          'Product Type',
          'Amount',
          'Date Issued',
          'Inspector Name',
          'Status',
          'QR Code',
        ],
      ];

      for (final order in _filteredOrders) {
        // Get fish product details
        String vesselName = 'Unknown';
        String productType = 'Unknown';
        String inspectorName = 'Unknown';

        try {
          final fishProductResponse =
              await Supabase.instance.client
                  .from('fish_products')
                  .select('vessel_name, species, inspector_name')
                  .eq('id', order.fishProductId)
                  .single();

          vesselName = fishProductResponse['vessel_name'] ?? 'Unknown';
          productType = fishProductResponse['species'] ?? 'Unknown';
          inspectorName = fishProductResponse['inspector_name'] ?? 'Unknown';
        } catch (e) {
          // Use defaults if fish product not found
        }

        csvData.add([
          order.orderNumber,
          vesselName,
          productType,
          order.amount.toStringAsFixed(2),
          order.createdAt.toIso8601String().split('T')[0],
          inspectorName,
          order.status.toUpperCase(),
          order.qrCode ?? 'N/A',
        ]);
      }

      final csvString = const ListToCsvConverter().convert(csvData);
      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/collector_reports_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(csvString);

      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.flat,
          title: const Text('Export Successful'),
          description: Text('CSV exported to: ${file.path}'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          title: const Text('Export Failed'),
          description: const Text('Failed to export CSV file'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    }
  }

  void _showQRCode(String qrCode) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('QR Code'),
            content: Center(
              child: QRCodeWidget(
                data: qrCode,
                size: 200,
                isUrl: qrCode.startsWith('http'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
              Expanded(
                child: Text(
                  'Collector Reports',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                onPressed: _loadOrders,
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        // Page Content
        Expanded(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Filters Card
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.filter_list,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Filters',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_searchQuery.isNotEmpty ||
                                        _selectedDateRange != null ||
                                        _selectedStatus != 'all')
                                      TextButton.icon(
                                        onPressed: _clearFilters,
                                        icon: const Icon(Icons.clear, size: 16),
                                        label: const Text('Clear'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Search and filters
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (constraints.maxWidth > 800) {
                                      return Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: TextField(
                                              decoration: InputDecoration(
                                                hintText:
                                                    'Search by order number or collector name',
                                                prefixIcon: const Icon(
                                                  Icons.search,
                                                ),
                                                filled: true,
                                                fillColor: Colors.grey.shade50,
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  borderSide: BorderSide(
                                                    color: Colors.grey.shade300,
                                                  ),
                                                ),
                                              ),
                                              onChanged: (value) {
                                                setState(() {
                                                  _searchQuery = value.trim();
                                                  _applyFilters();
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: DropdownButtonFormField<
                                              String
                                            >(
                                              value: _selectedStatus,
                                              decoration: InputDecoration(
                                                labelText: 'Status',
                                                filled: true,
                                                fillColor: Colors.grey.shade50,
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  borderSide: BorderSide(
                                                    color: Colors.grey.shade300,
                                                  ),
                                                ),
                                              ),
                                              items:
                                                  _statusOptions.map((status) {
                                                    return DropdownMenuItem(
                                                      value: status,
                                                      child: Text(
                                                        status == 'all'
                                                            ? 'All Status'
                                                            : status
                                                                .toUpperCase(),
                                                      ),
                                                    );
                                                  }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  _selectedStatus = value!;
                                                  _applyFilters();
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: _pickDateRange,
                                              icon: const Icon(
                                                Icons.date_range,
                                              ),
                                              label: Text(
                                                _selectedDateRange == null
                                                    ? 'Filter by Date'
                                                    : '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month}/${_selectedDateRange!.start.year} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}/${_selectedDateRange!.end.year}',
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    } else {
                                      return Column(
                                        children: [
                                          TextField(
                                            decoration: InputDecoration(
                                              hintText:
                                                  'Search by order number or collector name',
                                              prefixIcon: const Icon(
                                                Icons.search,
                                              ),
                                              filled: true,
                                              fillColor: Colors.grey.shade50,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                  color: Colors.grey.shade300,
                                                ),
                                              ),
                                            ),
                                            onChanged: (value) {
                                              setState(() {
                                                _searchQuery = value.trim();
                                                _applyFilters();
                                              });
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: DropdownButtonFormField<
                                                  String
                                                >(
                                                  value: _selectedStatus,
                                                  decoration: InputDecoration(
                                                    labelText: 'Status',
                                                    filled: true,
                                                    fillColor:
                                                        Colors.grey.shade50,
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      borderSide: BorderSide(
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade300,
                                                      ),
                                                    ),
                                                  ),
                                                  items:
                                                      _statusOptions.map((
                                                        status,
                                                      ) {
                                                        return DropdownMenuItem(
                                                          value: status,
                                                          child: Text(
                                                            status == 'all'
                                                                ? 'All Status'
                                                                : status
                                                                    .toUpperCase(),
                                                          ),
                                                        );
                                                      }).toList(),
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _selectedStatus = value!;
                                                      _applyFilters();
                                                    });
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: _pickDateRange,
                                                  icon: const Icon(
                                                    Icons.date_range,
                                                  ),
                                                  label: const Text('Date'),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Export and Stats Card
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Total Orders: ${_filteredOrders.length}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Total Amount: ₱${_filteredOrders.fold(0.0, (sum, order) => sum + order.amount).toStringAsFixed(2)}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.copyWith(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: _exportToCSV,
                                  icon: const Icon(Icons.download),
                                  label: const Text('Export CSV'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Orders List
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.receipt_long,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Orders of Payment',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (_filteredOrders.isEmpty)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text('No orders found'),
                                    ),
                                  )
                                else
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      if (constraints.maxWidth > 800) {
                                        // Desktop table view
                                        return SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: DataTable(
                                            columns: const [
                                              DataColumn(
                                                label: Text('🧾 Order No'),
                                              ),
                                              DataColumn(
                                                label: Text('🚢 Vessel Name'),
                                              ),
                                              DataColumn(
                                                label: Text('🐟 Product Type'),
                                              ),
                                              DataColumn(
                                                label: Text('💰 Amount'),
                                              ),
                                              DataColumn(
                                                label: Text('📅 Date Issued'),
                                              ),
                                              DataColumn(
                                                label: Text(
                                                  '👷 Inspector Name',
                                                ),
                                              ),
                                              DataColumn(label: Text('Status')),
                                              DataColumn(
                                                label: Text('Actions'),
                                              ),
                                            ],
                                            rows:
                                                _filteredOrders.map((order) {
                                                  return DataRow(
                                                    cells: [
                                                      DataCell(
                                                        Text(order.orderNumber),
                                                      ),
                                                      DataCell(
                                                        Text('Loading...'),
                                                      ), // Will be updated
                                                      DataCell(
                                                        Text('Loading...'),
                                                      ), // Will be updated
                                                      DataCell(
                                                        Text(
                                                          '₱${order.amount.toStringAsFixed(2)}',
                                                        ),
                                                      ),
                                                      DataCell(
                                                        Text(
                                                          order.createdAt
                                                              .toIso8601String()
                                                              .split('T')[0],
                                                        ),
                                                      ),
                                                      DataCell(
                                                        Text('Loading...'),
                                                      ), // Will be updated
                                                      DataCell(
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 4,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color:
                                                                order.status ==
                                                                        'paid'
                                                                    ? Colors
                                                                        .green
                                                                        .withValues(
                                                                          alpha:
                                                                              0.1,
                                                                        )
                                                                    : order.status ==
                                                                        'issued'
                                                                    ? Colors
                                                                        .blue
                                                                        .withValues(
                                                                          alpha:
                                                                              0.1,
                                                                        )
                                                                    : Colors
                                                                        .orange
                                                                        .withValues(
                                                                          alpha:
                                                                              0.1,
                                                                        ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  12,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            order.status
                                                                .toUpperCase(),
                                                            style: TextStyle(
                                                              color:
                                                                  order.status ==
                                                                          'paid'
                                                                      ? Colors
                                                                          .green
                                                                          .shade700
                                                                      : order.status ==
                                                                          'issued'
                                                                      ? Colors
                                                                          .blue
                                                                          .shade700
                                                                      : Colors
                                                                          .orange
                                                                          .shade700,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            if (order.qrCode !=
                                                                null)
                                                              IconButton(
                                                                onPressed:
                                                                    () => _showQRCode(
                                                                      order
                                                                          .qrCode!,
                                                                    ),
                                                                icon: const Icon(
                                                                  Icons.qr_code,
                                                                ),
                                                                tooltip:
                                                                    'View QR Code',
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                }).toList(),
                                          ),
                                        );
                                      } else {
                                        // Mobile card view
                                        return Column(
                                          children:
                                              _filteredOrders
                                                  .map(
                                                    (order) =>
                                                        _buildOrderCard(order),
                                                  )
                                                  .toList(),
                                        );
                                      }
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(OrderOfPayment order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        order.status == 'paid'
                            ? Colors.green.withValues(alpha: 0.1)
                            : order.status == 'issued'
                            ? Colors.blue.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.receipt,
                    color:
                        order.status == 'paid'
                            ? Colors.green
                            : order.status == 'issued'
                            ? Colors.blue
                            : Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderNumber,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₱${order.amount.toStringAsFixed(2)} • ${order.status.toUpperCase()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (order.qrCode != null)
                  IconButton(
                    onPressed: () => _showQRCode(order.qrCode!),
                    icon: const Icon(Icons.qr_code),
                    tooltip: 'View QR Code',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Date: ${order.createdAt.toIso8601String().split('T')[0]}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (order.quantity != null) ...[
              const SizedBox(height: 4),
              Text(
                'Quantity: ${order.quantity} pieces',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
