import 'package:flutter/material.dart';
import '../../../services/analytics_service.dart';

class SystemStatsCard extends StatefulWidget {
  const SystemStatsCard({super.key});

  @override
  State<SystemStatsCard> createState() => _SystemStatsCardState();
}

class _SystemStatsCardState extends State<SystemStatsCard> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final data = await AnalyticsService.getDashboardStats();
    if (mounted) {
      setState(() {
        _stats = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'System Statistics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: _isLoading ? null : _load,
                    icon: Icon(
                      Icons.refresh,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    tooltip: 'Refresh Statistics',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              Container(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading statistics...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 800) {
                    // Desktop layout - 4 columns
                    return Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            context,
                            'Total Users',
                            (_stats['total_users'] ?? 0).toString(),
                            Icons.people,
                            Colors.blue,
                            'Active users',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatItem(
                            context,
                            'Fish Products',
                            (_stats['total_inspections'] ?? 0).toString(),
                            Icons.pets,
                            Colors.green,
                            'Inspected items',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatItem(
                            context,
                            'Orders Paid',
                            (_stats['total_orders'] ?? 0).toString(),
                            Icons.receipt_long,
                            Colors.orange,
                            'Completed orders',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatItem(
                            context,
                            'Revenue',
                            '₱${(_stats['total_payments_collected'] ?? 0).toString()}',
                            Icons.payment,
                            Colors.purple,
                            'Year to date',
                          ),
                        ),
                      ],
                    );
                  } else if (constraints.maxWidth > 600) {
                    // Tablet layout - 2x2 grid
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatItem(
                                context,
                                'Total Users',
                                (_stats['total_users'] ?? 0).toString(),
                                Icons.people,
                                Colors.blue,
                                'Active users',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatItem(
                                context,
                                'Fish Products',
                                (_stats['total_inspections'] ?? 0).toString(),
                                Icons.pets,
                                Colors.green,
                                'Inspected items',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatItem(
                                context,
                                'Orders Paid',
                                (_stats['total_orders'] ?? 0).toString(),
                                Icons.receipt_long,
                                Colors.orange,
                                'Completed orders',
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatItem(
                                context,
                                'Revenue',
                                '₱${(_stats['total_payments_collected'] ?? 0).toString()}',
                                Icons.payment,
                                Colors.purple,
                                'Year to date',
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  } else {
                    // Mobile layout - single column
                    return Column(
                      children: [
                        _buildStatItem(
                          context,
                          'Total Users',
                          (_stats['total_users'] ?? 0).toString(),
                          Icons.people,
                          Colors.blue,
                          'Active users',
                        ),
                        const SizedBox(height: 12),
                        _buildStatItem(
                          context,
                          'Fish Products',
                          (_stats['total_inspections'] ?? 0).toString(),
                          Icons.pets,
                          Colors.green,
                          'Inspected items',
                        ),
                        const SizedBox(height: 12),
                        _buildStatItem(
                          context,
                          'Orders Paid',
                          (_stats['total_orders'] ?? 0).toString(),
                          Icons.receipt_long,
                          Colors.orange,
                          'Completed orders',
                        ),
                        const SizedBox(height: 12),
                        _buildStatItem(
                          context,
                          'Revenue',
                          '₱${(_stats['total_payments_collected'] ?? 0).toString()}',
                          Icons.payment,
                          Colors.purple,
                          'Year to date',
                        ),
                      ],
                    );
                  }
                },
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildActivityItem(
              context,
              'Data synced from Supabase views',
              'moments ago',
              Icons.sync,
              Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.trending_up, color: Colors.green, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    BuildContext context,
    String title,
    String time,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
