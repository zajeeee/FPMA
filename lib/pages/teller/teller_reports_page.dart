import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/payment_models.dart';
import '../../services/payment_service.dart';

class TellerReportsPage extends StatefulWidget {
  const TellerReportsPage({super.key});

  @override
  State<TellerReportsPage> createState() => _TellerReportsPageState();
}

class _TellerReportsPageState extends State<TellerReportsPage>
    with TickerProviderStateMixin {
  List<OfficialReceipt> _allReceipts = [];
  List<OrderOfPayment> _allOrders = [];
  bool _isLoading = true;
  String _selectedPeriod = '7days';
  DateTimeRange? _customDateRange;
  String _searchQuery = '';
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  List<Map<String, dynamic>> _dailyPayments = [];
  List<Map<String, dynamic>> _topCollectors = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load all receipts and orders
      final receipts = await PaymentService.getRecentReceipts(limit: 100);
      final orders = await PaymentService.getUnpaidOrders();

      setState(() {
        _allReceipts = receipts;
        _allOrders = orders;
        _isLoading = false;
      });

      _generateDailyPayments();
      _generateTopCollectors();
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
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    }
  }

  void _generateDailyPayments() {
    final now = DateTime.now();
    final days =
        _selectedPeriod == '7days'
            ? 7
            : _selectedPeriod == '30days'
            ? 30
            : 90;

    _dailyPayments = List.generate(days, (index) {
      final date = now.subtract(Duration(days: days - 1 - index));
      final dayReceipts =
          _allReceipts.where((receipt) {
            final receiptDate = DateTime.parse(
              receipt.paymentDate.toIso8601String().split('T')[0],
            );
            return receiptDate.isAtSameMomentAs(
              DateTime(date.year, date.month, date.day),
            );
          }).toList();

      return {
        'date': date,
        'amount': dayReceipts.fold<double>(
          0,
          (sum, receipt) => sum + receipt.amountPaid,
        ),
        'count': dayReceipts.length,
      };
    });
  }

  void _generateTopCollectors() {
    final collectorMap = <String, Map<String, dynamic>>{};

    for (final order in _allOrders) {
      if (collectorMap.containsKey(order.collectorName)) {
        collectorMap[order.collectorName]!['amount'] += order.amount;
        collectorMap[order.collectorName]!['count'] += 1;
      } else {
        collectorMap[order.collectorName] = {
          'name': order.collectorName,
          'amount': order.amount,
          'count': 1,
        };
      }
    }

    _topCollectors =
        collectorMap.values.toList()..sort(
          (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
        );
  }

  List<OfficialReceipt> get _filteredReceipts {
    var filtered = _allReceipts;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered
              .where(
                (receipt) =>
                    receipt.receiptNumber.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    receipt.tellerName.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
              )
              .toList();
    }

    // Filter by date range
    if (_customDateRange != null) {
      filtered =
          filtered.where((receipt) {
            final receiptDate = receipt.paymentDate;
            return receiptDate.isAfter(_customDateRange!.start) &&
                receiptDate.isBefore(
                  _customDateRange!.end.add(const Duration(days: 1)),
                );
          }).toList();
    }

    return filtered;
  }

  double get _totalRevenue {
    return _filteredReceipts.fold<double>(
      0,
      (sum, receipt) => sum + receipt.amountPaid,
    );
  }

  int get _totalTransactions {
    return _filteredReceipts.length;
  }

  double get _averageTransaction {
    return _totalTransactions > 0 ? _totalRevenue / _totalTransactions : 0;
  }

  Widget _buildOverviewCards() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount;
          double childAspectRatio;

          if (constraints.maxWidth > 1200) {
            crossAxisCount = 4;
            childAspectRatio = 1.8;
          } else if (constraints.maxWidth > 800) {
            crossAxisCount = 3;
            childAspectRatio = 1.6;
          } else if (constraints.maxWidth > 600) {
            crossAxisCount = 2;
            childAspectRatio = 1.4;
          } else {
            crossAxisCount = 2;
            childAspectRatio = 1.2;
          }

          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
            children: [
              _buildStatCard(
                'Total Revenue',
                '₱${_totalRevenue.toStringAsFixed(2)}',
                Icons.attach_money,
                Colors.green,
                'Revenue collected',
              ),
              _buildStatCard(
                'Transactions',
                '$_totalTransactions',
                Icons.receipt_long,
                Colors.blue,
                'Receipts issued',
              ),
              _buildStatCard(
                'Avg. Transaction',
                '₱${_averageTransaction.toStringAsFixed(2)}',
                Icons.trending_up,
                Colors.orange,
                'Per receipt',
              ),
              _buildStatCard(
                'Pending Orders',
                '${_allOrders.length}',
                Icons.pending_actions,
                Colors.red,
                'Awaiting payment',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.1),
              color.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Icon(Icons.more_vert, color: Colors.grey.shade400, size: 16),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentChart() {
    if (_dailyPayments.isEmpty) {
      return Card(
        child: Container(
          height: 300,
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'No payment data available',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Revenue Trend',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final chartHeight = constraints.maxWidth > 600 ? 200.0 : 150.0;
                return SizedBox(
                  height: chartHeight,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              if (value >= 1000) {
                                return Text(
                                  '₱${(value / 1000).toStringAsFixed(0)}k',
                                  style: const TextStyle(fontSize: 10),
                                );
                              } else {
                                return Text(
                                  '₱${value.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 10),
                                );
                              }
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() % 2 == 0) {
                                final date =
                                    _dailyPayments[value.toInt()]['date']
                                        as DateTime;
                                return Text(
                                  '${date.day}/${date.month}',
                                  style: const TextStyle(fontSize: 10),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots:
                              _dailyPayments.asMap().entries.map((entry) {
                                return FlSpot(
                                  entry.key.toDouble(),
                                  entry.value['amount'] as double,
                                );
                              }).toList(),
                          isCurved: true,
                          color: Theme.of(context).colorScheme.primary,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCollectors() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Collectors',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_topCollectors.isEmpty)
              Center(
                child: Text(
                  'No collector data available',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                ),
              )
            else
              ..._topCollectors.take(5).map((collector) {
                final amount = collector['amount'] as double;
                final count = collector['count'] as int;
                final name = collector['name'] as String;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'C',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '$count orders • ₱${amount.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '₱${amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptsList() {
    final filteredReceipts = _filteredReceipts;

    if (filteredReceipts.isEmpty) {
      return Card(
        child: Container(
          height: 200,
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No receipts found',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try adjusting your filters',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'Recent Receipts',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${filteredReceipts.length} receipts',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          ...filteredReceipts.take(10).map((receipt) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receipt.receiptNumber,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Teller: ${receipt.tellerName}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₱${receipt.amountPaid.toStringAsFixed(2)}',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        _formatDate(receipt.paymentDate),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildFilters() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;

            if (isWide) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Search receipts',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            setState(() => _searchQuery = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<String>(
                        value: _selectedPeriod,
                        items: const [
                          DropdownMenuItem(
                            value: '7days',
                            child: Text('Last 7 days'),
                          ),
                          DropdownMenuItem(
                            value: '30days',
                            child: Text('Last 30 days'),
                          ),
                          DropdownMenuItem(
                            value: '90days',
                            child: Text('Last 90 days'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedPeriod = value!);
                          _generateDailyPayments();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDateRange,
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            _customDateRange == null
                                ? 'Select date range'
                                : '${_formatDate(_customDateRange!.start)} - ${_formatDate(_customDateRange!.end)}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_customDateRange != null)
                        OutlinedButton(
                          onPressed: () {
                            setState(() => _customDateRange = null);
                          },
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search receipts',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String>(
                          value: _selectedPeriod,
                          items: const [
                            DropdownMenuItem(
                              value: '7days',
                              child: Text('Last 7 days'),
                            ),
                            DropdownMenuItem(
                              value: '30days',
                              child: Text('Last 30 days'),
                            ),
                            DropdownMenuItem(
                              value: '90days',
                              child: Text('Last 90 days'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedPeriod = value!);
                            _generateDailyPayments();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickDateRange,
                          icon: const Icon(Icons.date_range),
                          label: Text(
                            _customDateRange == null ? 'Date Range' : 'Range',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_customDateRange != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() => _customDateRange = null);
                        },
                        child: const Text('Clear Date Range'),
                      ),
                    ),
                  ],
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _customDateRange,
    );
    if (range != null) {
      setState(() => _customDateRange = range);
    }
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
          child: Text(
            'Teller Reports',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
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
                      children: [
                        // Filters
                        _buildFilters(),
                        const SizedBox(height: 20),

                        // Overview Cards
                        _buildOverviewCards(),
                        const SizedBox(height: 20),

                        // Tabs
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth > 600;
                                  return Column(
                                    children: [
                                      TabBar(
                                        controller: _tabController,
                                        labelColor:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                        unselectedLabelColor: Colors.grey,
                                        indicatorColor:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                        isScrollable: !isWide,
                                        tabs: [
                                          Tab(
                                            text:
                                                isWide
                                                    ? 'Analytics'
                                                    : 'Analytics',
                                            icon: const Icon(Icons.analytics),
                                          ),
                                          Tab(
                                            text:
                                                isWide
                                                    ? 'Collectors'
                                                    : 'Collectors',
                                            icon: const Icon(Icons.people),
                                          ),
                                          Tab(
                                            text:
                                                isWide
                                                    ? 'Receipts'
                                                    : 'Receipts',
                                            icon: const Icon(
                                              Icons.receipt_long,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                        height: isWide ? 400 : 300,
                                        child: TabBarView(
                                          controller: _tabController,
                                          children: [
                                            _buildPaymentChart(),
                                            _buildTopCollectors(),
                                            _buildReceiptsList(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
        ),
      ],
    );
  }
}
