import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../../models/payment_models.dart';
import '../../models/activity_log.dart';
import '../../services/gate_service.dart';

class GateCollectorReportsPage extends StatefulWidget {
  const GateCollectorReportsPage({super.key});

  @override
  State<GateCollectorReportsPage> createState() =>
      _GateCollectorReportsPageState();
}

class _GateCollectorReportsPageState extends State<GateCollectorReportsPage> {
  List<ClearingCertificate> _certificates = [];
  List<ActivityLog> _activityLogs = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load certificates with error handling
      List<ClearingCertificate> certificates = [];
      try {
        certificates = await GateService.getRecentCertificates(limit: 100);
      } catch (e) {
        certificates = [];
      }

      // Load activity logs with error handling
      List<ActivityLog> activityLogs = [];
      try {
        activityLogs = await GateService.getRecentActivity(limit: 100);
      } catch (e) {
        activityLogs = [];
      }

      setState(() {
        _certificates = certificates;
        _activityLogs = activityLogs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          title: const Text('Error'),
          description: const Text('Failed to load reports data'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
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
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedFilter = 'all';
      _selectedDateRange = null;
      _searchQuery = '';
    });
  }

  List<ClearingCertificate> get _filteredCertificates {
    return _certificates.where((cert) {
      final matchesFilter =
          _selectedFilter == 'all' ||
          (_selectedFilter == 'generated' && cert.status == 'generated') ||
          (_selectedFilter == 'validated' && cert.status == 'validated') ||
          (_selectedFilter == 'expired' && cert.status == 'expired');

      final matchesSearch =
          _searchQuery.isEmpty ||
          cert.certificateNumber.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          (cert.qrCode?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false);

      final matchesDate =
          _selectedDateRange == null ||
          (cert.createdAt.isAfter(
                _selectedDateRange!.start.subtract(const Duration(days: 1)),
              ) &&
              cert.createdAt.isBefore(
                _selectedDateRange!.end.add(const Duration(days: 1)),
              ));

      return matchesFilter && matchesSearch && matchesDate;
    }).toList();
  }

  List<ActivityLog> get _filteredActivityLogs {
    return _activityLogs.where((log) {
      final matchesFilter =
          _selectedFilter == 'all' ||
          (_selectedFilter == 'success' && log.validationResult == 'success') ||
          (_selectedFilter == 'fail' && log.validationResult == 'fail');

      final matchesSearch =
          _searchQuery.isEmpty ||
          log.message.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          log.gateCollectorName.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );

      final matchesDate =
          _selectedDateRange == null ||
          (log.timestamp.isAfter(
                _selectedDateRange!.start.subtract(const Duration(days: 1)),
              ) &&
              log.timestamp.isBefore(
                _selectedDateRange!.end.add(const Duration(days: 1)),
              ));

      return matchesFilter && matchesSearch && matchesDate;
    }).toList();
  }

  Map<String, int> get _certificateStats {
    return {
      'total': _certificates.length,
      'generated': _certificates.where((c) => c.status == 'generated').length,
      'validated': _certificates.where((c) => c.status == 'validated').length,
      'expired': _certificates.where((c) => c.status == 'expired').length,
    };
  }

  Map<String, int> get _activityStats {
    return {
      'total': _activityLogs.length,
      'success':
          _activityLogs.where((a) => a.validationResult == 'success').length,
      'fail': _activityLogs.where((a) => a.validationResult == 'fail').length,
    };
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
                  'Gate Collector Reports',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        // Dashboard Content
        Expanded(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Statistics Cards
                        _buildStatisticsCards(),
                        const SizedBox(height: 16),

                        // Filters
                        _buildFiltersCard(),
                        const SizedBox(height: 16),

                        // Certificates Report
                        _buildCertificatesReport(),
                        const SizedBox(height: 16),

                        // Activity Logs Report
                        _buildActivityLogsReport(),
                      ],
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildStatisticsCards() {
    final certStats = _certificateStats;
    final activityStats = _activityStats;

    return LayoutBuilder(
      builder: (context, constraints) {
        int columns = 2;
        if (constraints.maxWidth > 600) {
          columns = 4;
        } else if (constraints.maxWidth > 400) {
          columns = 2;
        }

        final double spacing = 12.0;
        final double itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _buildStatCard(
              'Total Certificates',
              certStats['total']!.toString(),
              Icons.receipt_long,
              Colors.blue,
              itemWidth,
            ),
            _buildStatCard(
              'Validated',
              certStats['validated']!.toString(),
              Icons.check_circle,
              Colors.green,
              itemWidth,
            ),
            _buildStatCard(
              'Expired',
              certStats['expired']!.toString(),
              Icons.cancel,
              Colors.red,
              itemWidth,
            ),
            _buildStatCard(
              'Total Validations',
              activityStats['total']!.toString(),
              Icons.qr_code_scanner,
              Colors.orange,
              itemWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    double width,
  ) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.filter_list,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Filters',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_selectedFilter != 'all' ||
                    _selectedDateRange != null ||
                    _searchQuery.isNotEmpty)
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Search certificates or activity...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged:
                              (value) => setState(() => _searchQuery = value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedFilter,
                          decoration: const InputDecoration(
                            labelText: 'Filter',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All')),
                            DropdownMenuItem(
                              value: 'generated',
                              child: Text('Generated'),
                            ),
                            DropdownMenuItem(
                              value: 'validated',
                              child: Text('Validated'),
                            ),
                            DropdownMenuItem(
                              value: 'expired',
                              child: Text('Expired'),
                            ),
                            DropdownMenuItem(
                              value: 'success',
                              child: Text('Success'),
                            ),
                            DropdownMenuItem(
                              value: 'fail',
                              child: Text('Failed'),
                            ),
                          ],
                          onChanged:
                              (value) =>
                                  setState(() => _selectedFilter = value!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDateRange,
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            _selectedDateRange == null
                                ? 'Select Date Range'
                                : '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}',
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search certificates or activity...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged:
                            (value) => setState(() => _searchQuery = value),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedFilter,
                              decoration: const InputDecoration(
                                labelText: 'Filter',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('All'),
                                ),
                                DropdownMenuItem(
                                  value: 'generated',
                                  child: Text('Generated'),
                                ),
                                DropdownMenuItem(
                                  value: 'validated',
                                  child: Text('Validated'),
                                ),
                                DropdownMenuItem(
                                  value: 'expired',
                                  child: Text('Expired'),
                                ),
                                DropdownMenuItem(
                                  value: 'success',
                                  child: Text('Success'),
                                ),
                                DropdownMenuItem(
                                  value: 'fail',
                                  child: Text('Failed'),
                                ),
                              ],
                              onChanged:
                                  (value) =>
                                      setState(() => _selectedFilter = value!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDateRange,
                              icon: const Icon(Icons.date_range),
                              label: Text(
                                _selectedDateRange == null
                                    ? 'Date Range'
                                    : '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month}',
                              ),
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
    );
  }

  Widget _buildCertificatesReport() {
    final filteredCertificates = _filteredCertificates;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Certificates Report',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${filteredCertificates.length} certificates',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (filteredCertificates.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No certificates found'),
                ),
              )
            else
              ...filteredCertificates.map(
                (cert) => _buildCertificateCard(cert),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateCard(ClearingCertificate cert) {
    Color statusColor;
    IconData statusIcon;
    switch (cert.status) {
      case 'generated':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'validated':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'expired':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cert.certificateNumber,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Status: ${cert.status.toUpperCase()}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Created: ${cert.createdAt.day}/${cert.createdAt.month}/${cert.createdAt.year} ${cert.createdAt.hour}:${cert.createdAt.minute.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (cert.qrCode != null)
              IconButton(
                onPressed: () => _showQRCode(cert.qrCode!),
                icon: const Icon(Icons.qr_code),
                tooltip: 'View QR Code',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityLogsReport() {
    final filteredLogs = _filteredActivityLogs;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Activity Logs Report',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${filteredLogs.length} activities',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (filteredLogs.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No activity logs found'),
                ),
              )
            else
              ...filteredLogs.map((log) => _buildActivityLogCard(log)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityLogCard(ActivityLog log) {
    final isSuccess = log.validationResult == 'success';
    final statusColor = isSuccess ? Colors.green : Colors.red;
    final statusIcon = isSuccess ? Icons.check_circle : Icons.cancel;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.message,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'By: ${log.gateCollectorName}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${log.timestamp.day}/${log.timestamp.month}/${log.timestamp.year} ${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                log.validationResult.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQRCode(String qrCode) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('QR Code'),
            content: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      qrCode,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Scan this QR code at the gate',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
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
}
