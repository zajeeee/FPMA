import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toastification/toastification.dart';
import '../../models/fish_product.dart';
import '../../models/payment_models.dart';
import '../../services/fish_product_service.dart';
import '../../services/payment_service.dart';
import '../../services/user_service.dart';
import '../../widgets/qr_code_widget.dart';

class OrderPaymentPage extends StatefulWidget {
  const OrderPaymentPage({super.key});

  @override
  State<OrderPaymentPage> createState() => _OrderPaymentPageState();
}

class _OrderPaymentPageState extends State<OrderPaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _quantityController = TextEditingController();
  DateTime? _dueDate;
  FishProduct? _selectedProduct;
  List<FishProduct> _products = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      // Load all pending fish products for collectors to create orders
      final products = await FishProductService.getAllFishProducts();
      setState(() {
        // Only allow products with pending status (not yet processed)
        _products = products.where((p) => p.status == 'pending').toList();
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
          description: const Text('Failed to load fish products'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    }
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      initialDate: _dueDate ?? now.add(const Duration(days: 7)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      toastification.show(
        context: context,
        type: ToastificationType.warning,
        style: ToastificationStyle.flat,
        title: const Text('Validation'),
        description: const Text('Please select a fish product'),
        alignment: Alignment.topRight,
        autoCloseDuration: const Duration(seconds: 3),
      );
      return;
    }

    setState(() => _isSubmitting = true);
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

      final order = await PaymentService.createOrderOfPayment(
        fishProductId: _selectedProduct!.id,
        collectorId: user.id,
        collectorName: collectorName,
        amount: double.parse(_amountController.text),
        quantity: int.parse(_quantityController.text),
        dueDate: _dueDate,
      );

      // Mark product as cleared after order creation
      await FishProductService.updateFishProduct(
        id: _selectedProduct!.id,
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
        _showOrderDialog(order);
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
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showOrderDialog(OrderOfPayment order) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Order of Payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Species: ${FishSpecies.fromString(_selectedProduct?.species ?? '').displayName}',
                ),
                const SizedBox(height: 8),
                Text('Quantity: ${_quantityController.text} pieces'),
                const SizedBox(height: 8),
                Text('Order Number: ${order.orderNumber}'),
                const SizedBox(height: 8),
                Text('Amount: ₱${order.amount.toStringAsFixed(2)}'),
                if (order.qrCode != null) ...[
                  const SizedBox(height: 16),
                  QRCodeWidget(
                    data: order.qrCode!,
                    size: 180,
                    isUrl: order.qrCode!.startsWith('http'),
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
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Back',
                ),
                Expanded(
                  child: Text(
                    'Issue Order of Payment',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48),
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
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fish Product',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<FishProduct>(
                                  value: _selectedProduct,
                                  items:
                                      _products.map((p) {
                                        return DropdownMenuItem(
                                          value: p,
                                          child: Text(
                                            '${FishSpecies.fromString(p.species).displayName} • ${p.weight != null ? '${p.weight} kg' : 'No weight'}',
                                          ),
                                        );
                                      }).toList(),
                                  onChanged:
                                      (v) =>
                                          setState(() => _selectedProduct = v),
                                  decoration: const InputDecoration(
                                    labelText: 'Select Product',
                                    prefixIcon: Icon(Icons.inventory_2),
                                  ),
                                  validator:
                                      (v) =>
                                          v == null
                                              ? 'Please select a product'
                                              : null,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Quantity',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _quantityController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Quantity (pieces)',
                                    hintText: 'Enter number of fish pieces',
                                    prefixIcon: Icon(Icons.numbers),
                                  ),
                                  validator: (v) {
                                    final qty = int.tryParse(v ?? '');
                                    if (qty == null || qty <= 0) {
                                      return 'Enter valid quantity';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Payment Details',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _amountController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Amount (₱)',
                                    prefixIcon: Icon(Icons.payments),
                                  ),
                                  validator: (v) {
                                    final amount = double.tryParse(v ?? '');
                                    if (amount == null || amount <= 0) {
                                      return 'Enter valid amount';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _dueDate == null
                                            ? 'No due date selected'
                                            : 'Due: ${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: _pickDueDate,
                                      icon: const Icon(Icons.date_range),
                                      label: const Text('Pick Due Date'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _isSubmitting ? null : _submit,
                                    style: FilledButton.styleFrom(
                                      backgroundColor:
                                          Theme.of(context).colorScheme.primary,
                                      foregroundColor: Colors.white,
                                    ),
                                    child:
                                        _isSubmitting
                                            ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                            : const Text(
                                              'Issue Order of Payment',
                                            ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
