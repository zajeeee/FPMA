import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toastification/toastification.dart';
import '../../models/user_role.dart';
import '../../services/user_service.dart';
import '../../services/analytics_service.dart';
import '../auth/login_page.dart';
import 'widgets/system_stats_card.dart';
import 'add_user_page.dart';
import 'user_list_page.dart';
import 'activity_logs_page.dart';
import 'reports_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  UserRole? _userRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _verifyAdminAccess();
  }

  Future<void> _verifyAdminAccess() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        await _signOut();
        return;
      }
      final role = await UserService.getUserRole(user.id);
      if (!mounted) return;
      setState(() {
        _userRole = role;
        _isLoading = false;
      });
      if (role != UserRole.admin) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          title: const Text('Access Denied'),
          description: const Text('You do not have admin permissions.'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 3),
        );
        await _signOut();
      } else {
        // Load analytics data for admin
        _loadAnalyticsData();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      toastification.show(
        context: context,
        type: ToastificationType.error,
        style: ToastificationStyle.flat,
        title: const Text('Error'),
        description: const Text('Failed to verify permissions'),
        alignment: Alignment.topRight,
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder:
              (context, animation, secondaryAnimation) => const LoginPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  Future<void> _loadAnalyticsData() async {
    try {
      await AnalyticsService.getDashboardStats();
      // Analytics data is loaded but not currently displayed in the UI
      // This method is kept for future use when analytics are displayed
    } catch (e) {
      // Handle error silently for now
    }
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.admin_panel_settings,
                      color: Theme.of(context).colorScheme.primary,
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, Administrator',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Manage users, monitor system activity, and view analytics',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: _signOut,
                      icon: Icon(Icons.logout, color: Colors.red.shade600),
                      tooltip: 'Sign Out',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // System Stats
          const SystemStatsCard(),
          const SizedBox(height: 24),

          // Quick Actions
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
                      Icon(
                        Icons.flash_on,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Quick Actions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 800) {
                        // Desktop layout - 3 columns
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildQuickActionButton(
                                    icon: Icons.person_add,
                                    label: 'Add User',
                                    description: 'Create new user account',
                                    onTap: () => _navigateToAddUser(),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildQuickActionButton(
                                    icon: Icons.people,
                                    label: 'Manage Users',
                                    description: 'View and edit users',
                                    onTap: () => _navigateToUserList(),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildQuickActionButton(
                                    icon: Icons.history,
                                    label: 'Activity Logs',
                                    description: 'View system activity',
                                    onTap: () => _navigateToActivityLogs(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildQuickActionButton(
                                    icon: Icons.assessment,
                                    label: 'Reports',
                                    description: 'Generate reports',
                                    onTap: () => _navigateToReports(),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildQuickActionButton(
                                    icon: Icons.refresh,
                                    label: 'Refresh Data',
                                    description: 'Update dashboard data',
                                    onTap: () => _refreshData(),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildQuickActionButton(
                                    icon: Icons.settings,
                                    label: 'System Settings',
                                    description: 'Configure system',
                                    onTap: () => _showSettingsDialog(),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      } else {
                        // Mobile/Tablet layout - 2 columns
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildQuickActionButton(
                                    icon: Icons.person_add,
                                    label: 'Add User',
                                    description: 'Create new user account',
                                    onTap: () => _navigateToAddUser(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildQuickActionButton(
                                    icon: Icons.people,
                                    label: 'Manage Users',
                                    description: 'View and edit users',
                                    onTap: () => _navigateToUserList(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildQuickActionButton(
                                    icon: Icons.history,
                                    label: 'Activity Logs',
                                    description: 'View system activity',
                                    onTap: () => _navigateToActivityLogs(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildQuickActionButton(
                                    icon: Icons.assessment,
                                    label: 'Reports',
                                    description: 'Generate reports',
                                    onTap: () => _navigateToReports(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildQuickActionButton(
                                    icon: Icons.refresh,
                                    label: 'Refresh Data',
                                    description: 'Update dashboard data',
                                    onTap: () => _refreshData(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildQuickActionButton(
                                    icon: Icons.settings,
                                    label: 'System Settings',
                                    description: 'Configure system',
                                    onTap: () => _showSettingsDialog(),
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
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required String description,
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
          mainAxisAlignment: MainAxisAlignment.center,
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
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToAddUser() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AddUserPage()));
  }

  void _navigateToUserList() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const UserListPage()));
  }

  void _navigateToActivityLogs() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const ActivityLogsPage()));
  }

  void _navigateToReports() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const ReportsPage()));
  }

  void _refreshData() async {
    await _loadAnalyticsData();
    if (mounted) {
      toastification.show(
        context: context,
        type: ToastificationType.success,
        style: ToastificationStyle.flat,
        title: const Text('Data Refreshed'),
        description: const Text('Dashboard data has been updated'),
        alignment: Alignment.topRight,
        autoCloseDuration: const Duration(seconds: 3),
      );
    }
  }

  void _showSettingsDialog() {
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.flat,
      title: const Text('System Settings'),
      description: const Text('Settings panel coming soon'),
      alignment: Alignment.topRight,
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                Colors.white,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Loading Admin Dashboard',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Verifying permissions and loading data...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_userRole != UserRole.admin) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Unauthorized',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text('This page is restricted to administrators only.'),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _signOut,
                  child: const Text('Return to Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
            'Admin Dashboard',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // Dashboard Content
        Expanded(child: _buildDashboard()),
      ],
    );
  }
}
