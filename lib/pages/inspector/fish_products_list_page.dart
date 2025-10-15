import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../../models/fish_product.dart';
import '../../services/fish_product_service.dart';
import '../../widgets/qr_code_widget.dart';

class FishProductsListPage extends StatefulWidget {
  const FishProductsListPage({super.key});

  @override
  State<FishProductsListPage> createState() => _FishProductsListPageState();
}

class _FishProductsListPageState extends State<FishProductsListPage> {
  List<FishProduct> _fishProducts = [];
  List<FishProduct> _filteredProducts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  FishSpecies? _selectedSpecies;
  FishProductStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadFishProducts();
  }

  Future<void> _loadFishProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await FishProductService.getAllFishProducts();
      setState(() {
        _fishProducts = products;
        _filteredProducts = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showToast('Failed to load fish products: $e', ToastificationType.error);
    }
  }

  void _filterProducts() {
    setState(() {
      _filteredProducts =
          _fishProducts.where((product) {
            // Search filter
            final matchesSearch =
                _searchQuery.isEmpty ||
                product.species.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                product.inspectorName.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                (product.vesselName?.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false);

            // Species filter
            final matchesSpecies =
                _selectedSpecies == null ||
                product.species == _selectedSpecies!.name;

            // Status filter
            final matchesStatus =
                _selectedStatus == null ||
                product.status == _selectedStatus!.name;

            return matchesSearch && matchesSpecies && matchesStatus;
          }).toList();
    });
  }

  void _showToast(String message, ToastificationType type) {
    toastification.show(
      context: context,
      type: type,
      style: ToastificationStyle.flat,
      title: Text(message),
      autoCloseDuration: const Duration(seconds: 4),
    );
  }

  void _showProductDetails(FishProduct product) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Fish Product Details'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (product.imageUrl != null) ...[
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.image_not_supported,
                                size: 48,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildDetailRow(
                    'Species',
                    FishSpecies.fromString(product.species).displayName,
                  ),
                  _buildDetailRow('Size', product.size ?? 'Not specified'),
                  _buildDetailRow(
                    'Weight',
                    product.weight != null
                        ? '${product.weight} kg'
                        : 'Not specified',
                  ),
                  _buildDetailRow(
                    'Vessel Name',
                    product.vesselName ?? 'Not specified',
                  ),
                  _buildDetailRow(
                    'Vessel Registration',
                    product.vesselRegistration ?? 'Not specified',
                  ),
                  _buildDetailRow('Inspector', product.inspectorName),
                  _buildDetailRow('Status', _getStatusBadge(product.status)),
                  _buildDetailRow(
                    'QR Code',
                    product.qrCode != null
                        ? product.qrCode!.length > 30
                            ? '${product.qrCode!.substring(0, 30)}...'
                            : product.qrCode!
                        : 'Not generated yet (will be created by Collector)',
                  ),
                  _buildDetailRow('Created', _formatDate(product.createdAt)),
                ],
              ),
            ),
            actions: [
              if (product.qrCode != null)
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showQRCode(product.qrCode!);
                  },
                  icon: const Icon(Icons.qr_code),
                  label: const Text('View QR Code'),
                ),
              if (product.status != 'pending')
                TextButton.icon(
                  onPressed: () => _updateProductStatus(product, 'pending'),
                  icon: Icon(
                    Icons.hourglass_bottom,
                    color: Colors.orange.shade700,
                  ),
                  label: const Text('Set Pending'),
                ),
              if (product.status != 'rejected')
                TextButton.icon(
                  onPressed: () => _updateProductStatus(product, 'rejected'),
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  label: const Text('Reject'),
                ),
              if (product.status != 'approved')
                FilledButton.icon(
                  onPressed: () => _updateProductStatus(product, 'approved'),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Approve'),
                ),
              if (product.status != 'cleared')
                TextButton.icon(
                  onPressed: () => _updateProductStatus(product, 'cleared'),
                  icon: const Icon(Icons.verified, color: Colors.blue),
                  label: const Text('Mark Cleared'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Future<void> _updateProductStatus(
    FishProduct product,
    String newStatus,
  ) async {
    try {
      final updated = await FishProductService.updateFishProduct(
        id: product.id,
        status: newStatus,
      );
      if (!mounted) return;
      if (updated) {
        Navigator.pop(context);
        String msg;
        switch (newStatus) {
          case 'approved':
            msg = 'Product approved successfully';
            break;
          case 'rejected':
            msg = 'Product rejected';
            break;
          case 'cleared':
            msg = 'Product marked as cleared';
            break;
          default:
            msg = 'Product set to pending';
        }
        _showToast(msg, ToastificationType.success);
        await _loadFishProducts();
      } else {
        _showToast('Failed to update status', ToastificationType.error);
      }
    } catch (e) {
      if (!mounted) return;
      _showToast('Error updating status: $e', ToastificationType.error);
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _getStatusBadge(String status) {
    switch (status) {
      case 'pending':
        return '⏳ Pending';
      case 'approved':
        return '✅ Approved';
      case 'rejected':
        return '❌ Rejected';
      case 'cleared':
        return '🎯 Cleared';
      default:
        return status;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showQRCode(String qrCode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QRCodePage(title: 'QR Code', data: qrCode),
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
                    'Fish Products',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _loadFishProducts,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          // Search and Filter Section
          Container(
            color: Colors.blue.shade50,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by species, inspector, or vessel...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    _filterProducts();
                  },
                ),
                const SizedBox(height: 12),

                // Filter Row
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 600) {
                      // Horizontal layout for wide screens
                      return Row(
                        children: [
                          Expanded(child: _buildSpeciesFilter()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildStatusFilter()),
                        ],
                      );
                    } else {
                      // Vertical layout for narrow screens
                      return Column(
                        children: [
                          _buildSpeciesFilter(),
                          const SizedBox(height: 12),
                          _buildStatusFilter(),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          // Products List
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredProducts.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _fishProducts.isEmpty
                                ? 'No fish products found'
                                : 'No products match your filters',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _fishProducts.isEmpty
                                ? 'Start by scanning your first fish product'
                                : 'Try adjusting your search or filters',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                    : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 800) {
                          return _buildDesktopTable();
                        } else {
                          return _buildMobileList();
                        }
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeciesFilter() {
    return DropdownButtonFormField<FishSpecies?>(
      value: _selectedSpecies,
      decoration: InputDecoration(
        labelText: 'Filter by Species',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem<FishSpecies?>(
          value: null,
          child: Text('All Species'),
        ),
        ...FishSpecies.values.map((species) {
          return DropdownMenuItem<FishSpecies?>(
            value: species,
            child: Text(species.displayName),
          );
        }),
      ],
      onChanged: (FishSpecies? newValue) {
        setState(() {
          _selectedSpecies = newValue;
        });
        _filterProducts();
      },
    );
  }

  Widget _buildStatusFilter() {
    return DropdownButtonFormField<FishProductStatus?>(
      value: _selectedStatus,
      decoration: InputDecoration(
        labelText: 'Filter by Status',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem<FishProductStatus?>(
          value: null,
          child: Text('All Status'),
        ),
        ...FishProductStatus.values.map((status) {
          return DropdownMenuItem<FishProductStatus?>(
            value: status,
            child: Text(status.displayName),
          );
        }),
      ],
      onChanged: (FishProductStatus? newValue) {
        setState(() {
          _selectedStatus = newValue;
        });
        _filterProducts();
      },
    );
  }

  Widget _buildDesktopTable() {
    return SingleChildScrollView(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Species')),
          DataColumn(label: Text('Vessel')),
          DataColumn(label: Text('Inspector')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Created')),
          DataColumn(label: Text('Actions')),
        ],
        rows:
            _filteredProducts.map((product) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(FishSpecies.fromString(product.species).displayName),
                  ),
                  DataCell(Text(product.vesselName ?? 'N/A')),
                  DataCell(Text(product.inspectorName)),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          product.status,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getStatusColor(product.status),
                        ),
                      ),
                      child: Text(
                        _getStatusBadge(product.status),
                        style: TextStyle(
                          color: _getStatusColor(product.status),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  DataCell(Text(_formatDate(product.createdAt))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility),
                          onPressed: () => _showProductDetails(product),
                          tooltip: 'View Details',
                        ),
                        if (product.qrCode != null)
                          IconButton(
                            icon: const Icon(Icons.qr_code),
                            onPressed: () => _showQRCode(product.qrCode!),
                            tooltip: 'View QR Code',
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
      ),
    );
  }

  Widget _buildMobileList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _showProductDetails(product),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              FishSpecies.fromString(
                                product.species,
                              ).displayName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Vessel: ${product.vesselName ?? 'N/A'}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
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
                          color: _getStatusColor(
                            product.status,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getStatusColor(product.status),
                          ),
                        ),
                        child: Text(
                          _getStatusBadge(product.status),
                          style: TextStyle(
                            color: _getStatusColor(product.status),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        product.inspectorName,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(product.createdAt),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.qr_code,
                        size: 16,
                        color:
                            product.qrCode != null
                                ? Colors.blue.shade600
                                : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          product.qrCode != null
                              ? product.qrCode!.length > 20
                                  ? 'QR: ${product.qrCode!.substring(0, 20)}...'
                                  : 'QR: ${product.qrCode!}'
                              : 'QR: Not generated yet (will be created by Collector)',
                          style: TextStyle(
                            color:
                                product.qrCode != null
                                    ? Colors.blue.shade600
                                    : Colors.grey.shade500,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (product.qrCode != null)
                        TextButton(
                          onPressed: () => _showQRCode(product.qrCode!),
                          child: const Text('View'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cleared':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
