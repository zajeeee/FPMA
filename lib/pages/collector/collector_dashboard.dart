import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toastification/toastification.dart';
import '../../models/fish_product.dart';
import '../../models/payment_models.dart';
import '../../services/fish_product_service.dart';
import '../../services/payment_service.dart';
import '../../services/user_service.dart';
import '../../widgets/qr_code_widget.dart';
import 'order_payment_page.dart';

class CollectorDashboard extends StatefulWidget {
  const CollectorDashboard({super.key});

  @override
  State<CollectorDashboard> createState() => _CollectorDashboardState();
}

class _CollectorDashboardState extends State<CollectorDashboard> {
  List<FishProduct> _pendingInspections = [];
  List<OrderOfPayment> _recentOrders = [];
  List<FishProduct> _filteredPending = [];
  List<OrderOfPayment> _filteredOrders = [];
  bool _isLoading = true;
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _loadData();
    _fixExistingOrders();
  }

  Future<void> _fixExistingOrders() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final userProfile = await UserService.getUserProfile(user.id);
      if (userProfile == null) return;

      // Update existing orders with "Unknown Collector" to show correct name
      await Supabase.instance.client
          .from('orders')
          .update({'collector_name': userProfile.fullName})
          .eq('collector_id', user.id)
          .eq('collector_name', 'Unknown Collector');

      // Reload data to show updated orders
      if (mounted) {
        _loadData();
      }
    } catch (e) {
      // Silently handle errors
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load pending inspections (fish products that need O.P. generation)
      final allProducts = await FishProductService.getAllFishProducts();

      // Debug: Log all products and their statuses (removed for production)

      final pendingProducts =
          allProducts
              .where((p) => p.status == 'pending')
              .take(5) // Show latest 5
              .toList();

      // Load recent orders
      final recentOrders = await PaymentService.getUnpaidOrders();

      // If no fish products found, try to create them from inspections
      if (allProducts.isEmpty) {
        await _createFishProductsFromInspections();
        // Reload after creating
        final updatedProducts = await FishProductService.getAllFishProducts();
        final updatedPendingProducts =
            updatedProducts
                .where((p) => p.status == 'pending')
                .take(5)
                .toList();

        setState(() {
          _pendingInspections = updatedPendingProducts;
          _recentOrders = recentOrders.take(3).toList();
          _filteredPending = _pendingInspections;
          _filteredOrders = _recentOrders;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _pendingInspections = pendingProducts;
        _recentOrders = recentOrders.take(3).toList(); // Show latest 3
        _filteredPending = _pendingInspections;
        _filteredOrders = _recentOrders;
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
          description: const Text('Failed to load dashboard data'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _createFishProductsFromInspections() async {
    try {
      // Get inspections from the database
      final response = await Supabase.instance.client
          .from('inspections')
          .select()
          .order('created_at', ascending: false);

      final inspections = response as List;

      for (var inspection in inspections) {
        // Check if fish product already exists
        final existingProducts = await Supabase.instance.client
            .from('fish_products')
            .select()
            .eq('inspector_id', inspection['inspector_id'])
            .eq('created_at', inspection['inspection_date']);

        if (existingProducts.isEmpty) {
          // Create fish product from inspection
          await Supabase.instance.client.from('fish_products').insert({
            'inspection_id': inspection['id'],
            'species': 'bangus', // Default species
            'inspector_id': inspection['inspector_id'],
            'inspector_name': inspection['inspector_name'],
            'status': 'pending',
            'created_at': inspection['inspection_date'],
            'updated_at': inspection['inspection_date'],
          });
        }
      }
    } catch (e) {
      // Silently handle errors in production
    }
  }

  void _applyFilters() {
    setState(() {
      // Pending inspections filter (search only)
      _filteredPending =
          _pendingInspections.where((p) {
            final q = _searchQuery.toLowerCase();
            if (q.isEmpty) return true;
            final vessel = (p.vesselName ?? '').toLowerCase();
            final species = p.species.toLowerCase();
            return vessel.contains(q) || species.contains(q);
          }).toList();

      // Orders filter (search + date range)
      _filteredOrders =
          _recentOrders.where((o) {
            final matchesSearch =
                _searchQuery.isEmpty ||
                o.orderNumber.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );
            final matchesDate =
                _selectedDateRange == null ||
                (o.createdAt.isAfter(
                      _selectedDateRange!.start.subtract(
                        const Duration(days: 1),
                      ),
                    ) &&
                    o.createdAt.isBefore(
                      _selectedDateRange!.end.add(const Duration(days: 1)),
                    ));
            return matchesSearch && matchesDate;
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
      _selectedDateRange = range;
      _applyFilters();
    }
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedDateRange = null;
      _filteredPending = _pendingInspections;
      _filteredOrders = _recentOrders;
    });
  }

  void _navigateToOrders() {
    // Navigate to the Orders page (index 1 in collector navigation)
    // This will be handled by the parent navigation wrapper
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const OrderPaymentPage()));
  }

  // Keep this method for potential future use or other parts of the app
  // ignore: unused_element
  Future<void> _createOrderOfPayment(FishProduct product) async {
    try {
      final user = Supabase.instance.client.auth.currentUser!;

      // Get user profile to get the actual name
      final userProfile = await UserService.getUserProfile(user.id);
      String collectorName;
      if (userProfile != null) {
        collectorName = userProfile.fullName;
      } else {
        // Create user profile if it doesn't exist
        await Supabase.instance.client.from('user_profiles').upsert({
          'user_id': user.id,
          'email': user.email ?? '',
          'full_name': user.userMetadata?['full_name'] ?? 'Collector User',
          'role': 'collector',
          'is_active': true,
        }, onConflict: 'user_id');
        collectorName = user.userMetadata?['full_name'] ?? 'Collector User';
      }

      // Create order of payment
      final order = await PaymentService.createOrderOfPayment(
        fishProductId: product.id,
        collectorId: user.id,
        collectorName: collectorName,
        amount: _calculateUnloadingFee(
          product,
        ), // Calculate fee based on weight/species
        quantity: 1, // Default quantity for quick generation
        dueDate: DateTime.now().add(const Duration(days: 7)), // Default 7 days
      );

      // Mark product as cleared after order creation
      await FishProductService.updateFishProduct(
        id: product.id,
        status: 'cleared',
      );

      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          style: ToastificationStyle.flat,
          title: const Text('Order Created'),
          description: const Text('Order of Payment issued successfully'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 3),
        );
        _showOrderDialog(order, product);
        _loadData(); // Refresh data
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          title: const Text('Error'),
          description: Text('Failed to create order: $e'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    }
  }

  double _calculateUnloadingFee(FishProduct product) {
    // Simple fee calculation based on weight
    // In a real implementation, this would be more sophisticated
    final weight = product.weight ?? 0;
    return weight * 5.0; // ₱5 per kg as base rate
  }

  void _showOrderDialog(OrderOfPayment order, FishProduct product) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Order of Payment Created'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Species: ${FishSpecies.fromString(product.species).displayName}',
                ),
                const SizedBox(height: 8),
                Text('Vessel: ${product.vesselName ?? 'Unknown'}'),
                const SizedBox(height: 8),
                Text('Weight: ${product.weight ?? 0} kg'),
                if (order.quantity != null) ...[
                  const SizedBox(height: 8),
                  Text('Quantity: ${order.quantity} pieces'),
                ],
                const SizedBox(height: 8),
                Text('Order Number: ${order.orderNumber}'),
                const SizedBox(height: 8),
                Text('Amount: ₱${order.amount.toStringAsFixed(2)}'),
                if (order.qrCode != null) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: QRCodeWidget(
                      data: order.qrCode!,
                      size: 150,
                      isUrl: order.qrCode!.startsWith('http'),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
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
                  'Collector Dashboard',
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
                        // Welcome Card
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.05),
                                  Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.02),
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.receipt_long,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome, Collector',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Generate Orders of Payment for pending inspections',
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
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Quick Actions (responsive, user-friendly tiles)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quick Actions',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    const double spacing = 12;
                                    int columns = 4;
                                    if (constraints.maxWidth < 380) {
                                      columns = 1;
                                    } else if (constraints.maxWidth < 720) {
                                      columns = 2;
                                    } else if (constraints.maxWidth < 1024) {
                                      columns = 3;
                                    }

                                    final double itemWidth =
                                        (constraints.maxWidth -
                                            spacing * (columns - 1)) /
                                        columns;

                                    Widget buildItem(Widget child) => SizedBox(
                                      width: itemWidth,
                                      child: child,
                                    );

                                    return Wrap(
                                      spacing: spacing,
                                      runSpacing: spacing,
                                      children: [
                                        buildItem(
                                          _buildQuickActionButton(
                                            context,
                                            icon: Icons.receipt_long,
                                            label: 'Issue O.P.',
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) =>
                                                          const OrderPaymentPage(),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Find Records (Search & Filters)
                        Card(
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
                                        Icons.search,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Find Records',
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
                                    if (_selectedDateRange != null ||
                                        _searchQuery.isNotEmpty)
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
                                const SizedBox(height: 12),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (constraints.maxWidth > 700) {
                                      return Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: TextField(
                                              decoration: InputDecoration(
                                                hintText:
                                                    'Search by vessel/species or O.P. number',
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
                                              onChanged: (v) {
                                                _searchQuery = v.trim();
                                                _applyFilters();
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
                                    }
                                    return Column(
                                      children: [
                                        TextField(
                                          decoration: InputDecoration(
                                            hintText:
                                                'Search by vessel/species or O.P. number',
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
                                          onChanged: (v) {
                                            _searchQuery = v.trim();
                                            _applyFilters();
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: _pickDateRange,
                                            icon: const Icon(Icons.date_range),
                                            label: Text(
                                              _selectedDateRange == null
                                                  ? 'Filter by Date'
                                                  : '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month}/${_selectedDateRange!.start.year} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}/${_selectedDateRange!.end.year}',
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Pending Inspections
                        Card(
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
                                        Icons.inventory_2,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Pending Inspections',
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
                                    Text(
                                      '${_pendingInspections.length} items',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.copyWith(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (_filteredPending.isEmpty)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text('No pending inspections'),
                                    ),
                                  )
                                else
                                  ..._filteredPending.map(
                                    (product) => _buildInspectionCard(product),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Recent Orders
                        Card(
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
                                        color: Colors.green.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.receipt_long,
                                        color: Colors.green,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Recent Orders',
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
                                      child: Text('No recent orders'),
                                    ),
                                  )
                                else
                                  ..._filteredOrders.map(
                                    (order) => _buildOrderCard(order),
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

  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 28,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInspectionCard(FishProduct product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.inventory_2,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    FishSpecies.fromString(product.species).displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Vessel: ${product.vesselName ?? 'Unknown'} • ${product.weight ?? 0} kg',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () => _navigateToOrders(),
              child: const Text('Generate O.P.'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderOfPayment order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    order.status == 'paid'
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.receipt,
                color: order.status == 'paid' ? Colors.green : Colors.orange,
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '₱${order.amount.toStringAsFixed(2)} • ${order.status.toUpperCase()}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
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
}
