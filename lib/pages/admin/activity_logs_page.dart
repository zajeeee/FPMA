import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../../models/activity_log.dart';
import '../../services/activity_log_service.dart';

class ActivityLogsPage extends StatefulWidget {
  const ActivityLogsPage({super.key});

  @override
  State<ActivityLogsPage> createState() => _ActivityLogsPageState();
}

class _ActivityLogsPageState extends State<ActivityLogsPage> {
  List<ActivityLog> _activityLogs = [];
  bool _isLoading = true;
  String _selectedAction = 'All Actions';
  String _selectedRole = 'All Roles';
  int _currentPage = 0;
  final int _pageSize = 20;

  final List<String> _actionTypes = [
    'All Actions',
    'fish_product_created',
    'fish_product_updated',
    'fish_product_deleted',
    'order_created',
    'order_paid',
    'receipt_issued',
    'certificate_validated',
    'user_created',
    'user_updated',
    'user_deactivated',
    'login',
    'logout',
  ];

  final List<String> _roleTypes = [
    'All Roles',
    'admin',
    'inspector',
    'teller',
    'collector',
    'gateCollector',
  ];

  @override
  void initState() {
    super.initState();
    _loadActivityLogs();
  }

  Future<void> _loadActivityLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final logs = await ActivityLogService.getActivityLogs(
        limit: _pageSize,
        offset: _currentPage * _pageSize,
        action: _selectedAction == 'All Actions' ? null : _selectedAction,
        userRole: _selectedRole == 'All Roles' ? null : _selectedRole,
      );

      setState(() {
        _activityLogs = logs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showToast('Failed to load activity logs: $e', ToastificationType.error);
    }
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

  String _formatAction(String action) {
    switch (action) {
      case 'fish_product_created':
        return 'Fish Product Created';
      case 'fish_product_updated':
        return 'Fish Product Updated';
      case 'fish_product_deleted':
        return 'Fish Product Deleted';
      case 'order_created':
        return 'Order Created';
      case 'order_paid':
        return 'Order Paid';
      case 'receipt_issued':
        return 'Receipt Issued';
      case 'certificate_validated':
        return 'Certificate Validated';
      case 'user_created':
        return 'User Created';
      case 'user_updated':
        return 'User Updated';
      case 'user_deactivated':
        return 'User Deactivated';
      case 'login':
        return 'Login';
      case 'logout':
        return 'Logout';
      default:
        return action;
    }
  }

  String _formatRole(String role) {
    switch (role) {
      case 'admin':
        return 'Administrator';
      case 'inspector':
        return 'Inspector';
      case 'teller':
        return 'Teller';
      case 'collector':
        return 'Collector';
      case 'gateCollector':
        return 'Gate Collector';
      default:
        return role;
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'fish_product_created':
      case 'order_created':
      case 'receipt_issued':
      case 'user_created':
        return Colors.green;
      case 'fish_product_updated':
      case 'user_updated':
        return Colors.blue;
      case 'fish_product_deleted':
      case 'user_deactivated':
        return Colors.red;
      case 'order_paid':
      case 'certificate_validated':
        return Colors.orange;
      case 'login':
        return Colors.purple;
      case 'logout':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
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
                    'Activity Logs',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _loadActivityLogs,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

          // Filters
          Card(
            elevation: 4,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedAction,
                      decoration: InputDecoration(
                        labelText: 'Filter by Action',
                        prefixIcon: Icon(
                          Icons.filter_alt,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items:
                          _actionTypes.map((action) {
                            return DropdownMenuItem<String>(
                              value: action,
                              child: Text(
                                action == 'All Actions'
                                    ? action
                                    : _formatAction(action),
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedAction = value!;
                          _currentPage = 0;
                        });
                        _loadActivityLogs();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: InputDecoration(
                        labelText: 'Filter by Role',
                        prefixIcon: Icon(
                          Icons.group,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items:
                          _roleTypes.map((role) {
                            return DropdownMenuItem<String>(
                              value: role,
                              child: Text(
                                role == 'All Roles' ? role : _formatRole(role),
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedRole = value!;
                          _currentPage = 0;
                        });
                        _loadActivityLogs();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Activity Logs List
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _activityLogs.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No activity logs found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Activity logs will appear here as users perform actions',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _activityLogs.length,
                      itemBuilder: (context, index) {
                        final log = _activityLogs[index];
                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getActionColor(
                                          log.action,
                                        ).withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _getActionColor(log.action),
                                        ),
                                      ),
                                      child: Text(
                                        _formatAction(log.action),
                                        style: TextStyle(
                                          color: _getActionColor(log.action),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatDateTime(log.createdAt),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatRole(log.userRole),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                if (log.description != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    log.description!,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                                if (log.referenceId != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.link,
                                        size: 16,
                                        color: Colors.blue.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Reference: ${log.referenceId}',
                                        style: TextStyle(
                                          color: Colors.blue.shade600,
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
