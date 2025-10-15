import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toastification/toastification.dart';
import '../../models/payment_models.dart';
import '../../models/activity_log.dart';
import '../../models/user_profile.dart';
import '../../services/gate_service.dart';
import '../../services/user_service.dart';
import '../../widgets/qr_code_widget.dart';
import 'qr_scanner_page.dart';

class GateCollectorDashboard extends StatefulWidget {
  const GateCollectorDashboard({super.key});

  @override
  State<GateCollectorDashboard> createState() => _GateCollectorDashboardState();
}

class _GateCollectorDashboardState extends State<GateCollectorDashboard> {
  List<ClearingCertificate> _recentCertificates = [];
  List<ActivityLog> _recentActivity = [];
  UserProfile? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _fixExistingActivityLogs();
  }

  Future<void> _fixExistingActivityLogs() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final userProfile = await UserService.getUserProfile(user.id);
      if (userProfile == null) return;

      // Update existing activity logs with "Unknown Gate Collector" to show correct name
      await Supabase.instance.client
          .from('activity_logs')
          .update({'gate_collector_name': userProfile.fullName})
          .eq('gate_collector_id', user.id)
          .eq('gate_collector_name', 'Unknown Gate Collector');

      // Reload data to show updated activity logs
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
      // Load user profile
      UserProfile? userProfile;
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          userProfile = await UserService.getUserProfile(user.id);
        }
      } catch (e) {
        // If user profile loading fails, continue without it
        userProfile = null;
      }

      // Load recent certificates with error handling
      List<ClearingCertificate> recentCertificates = [];
      try {
        recentCertificates = await GateService.getRecentCertificates(limit: 5);
      } catch (e) {
        // If certificates table doesn't exist or has issues, use empty list
        recentCertificates = [];
      }

      // Load recent activity logs with error handling
      List<ActivityLog> recentActivity = [];
      try {
        recentActivity = await GateService.getRecentActivity(limit: 5);
      } catch (e) {
        // If activity_logs table doesn't exist or has issues, use empty list
        recentActivity = [];
      }

      setState(() {
        _userProfile = userProfile;
        _recentCertificates = recentCertificates;
        _recentActivity = recentActivity;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _userProfile = null;
        _recentCertificates = [];
        _recentActivity = [];
        _isLoading = false;
      });
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
                  'Gate Collector Dashboard',
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
                        // Welcome Header
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
                                  ).colorScheme.primary.withValues(alpha: 0.1),
                                  Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.05),
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
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.security,
                                    size: 32,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome, ${_userProfile?.fullName ?? 'Gate Collector'}',
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
                                      const SizedBox(height: 6),
                                      Text(
                                        'Validate certificates and manage gate access',
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
                        // Quick Actions
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quick Actions',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  const QrScannerPage(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.qr_code_scanner),
                                    label: const Text('Scan QR Code'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Recent Certificates
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Recent Certificates',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${_recentCertificates.length} items',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.copyWith(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (_recentCertificates.isEmpty)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text('No recent certificates'),
                                    ),
                                  )
                                else
                                  ..._recentCertificates.map(
                                    (cert) => _buildCertificateCard(cert),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Recent Activity
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Recent Activity',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                if (_recentActivity.isEmpty)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text('No recent activity'),
                                    ),
                                  )
                                else
                                  ..._recentActivity.map(
                                    (activity) => _buildActivityCard(activity),
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

  Widget _buildCertificateCard(ClearingCertificate certificate) {
    Color statusColor;
    IconData statusIcon;

    switch (certificate.status) {
      case 'validated':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'expired':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    certificate.certificateNumber,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Status: ${certificate.status} • ${certificate.validatedBy ?? 'Not validated'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _showCertificateDetails(certificate),
              icon: const Icon(Icons.visibility),
              tooltip: 'View Details',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(ActivityLog activity) {
    Color resultColor =
        activity.validationResult == 'success' ? Colors.green : Colors.red;
    IconData resultIcon =
        activity.validationResult == 'success'
            ? Icons.check_circle
            : Icons.cancel;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: resultColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(resultIcon, color: resultColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Certificate: ${activity.certificateId.substring(0, 8)}...',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${activity.validationResult.toUpperCase()} • ${activity.timestamp}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCertificateDetails(ClearingCertificate certificate) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Certificate Details'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Certificate Number: ${certificate.certificateNumber}'),
                const SizedBox(height: 8),
                Text('Status: ${certificate.status}'),
                const SizedBox(height: 8),
                Text(
                  'Validated By: ${certificate.validatedBy ?? 'Not validated'}',
                ),
                const SizedBox(height: 8),
                Text(
                  'Validated At: ${certificate.validatedAt ?? 'Not validated'}',
                ),
                const SizedBox(height: 8),
                Text('Created: ${certificate.createdAt}'),
                if (certificate.qrCode != null) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: QRCodeWidget(
                      data: certificate.qrCode!,
                      size: 150,
                      isUrl: certificate.qrCode!.startsWith('http'),
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
            ],
          ),
    );
  }
}
