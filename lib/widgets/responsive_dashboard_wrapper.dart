import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toastification/toastification.dart';
import '../models/user_role.dart';
import '../services/user_service.dart';
import '../services/analytics_service.dart';
import '../pages/auth/login_page.dart';
import 'responsive_navigation.dart';
import '../pages/admin/admin_dashboard.dart';
import '../pages/admin/admin_profile_page.dart';
import '../pages/admin/user_list_page.dart';
import '../pages/admin/widgets/analytics_card.dart';
import '../pages/inspector/inspector_dashboard.dart';
import '../pages/inspector/inspector_profile_page.dart';
import '../pages/inspector/fish_scanning_page.dart';
import '../pages/inspector/fish_products_list_page.dart';
import '../pages/inspector/inspector_reports_page.dart';
import '../pages/collector/collector_dashboard.dart';
import '../pages/collector/order_payment_page.dart';
import '../pages/collector/collector_profile_page.dart';
// ignore: unused_import
import '../pages/collector/collector_reports_page.dart';
import '../pages/teller/teller_dashboard.dart';
import '../pages/teller/teller_profile_page.dart';
import '../pages/teller/official_receipt_page.dart';
import '../pages/teller/teller_reports_page.dart';
import '../pages/gate_collector/gate_collector_dashboard.dart';
import '../pages/gate_collector/gate_collector_profile_page.dart';
import '../pages/gate_collector/certificate_validation_page.dart';
import '../pages/gate_collector/gate_collector_reports_page.dart';

class RoleGuard extends StatefulWidget {
  const RoleGuard({super.key, required this.requiredRole, required this.child});

  final UserRole requiredRole;
  final Widget child;

  @override
  State<RoleGuard> createState() => _RoleGuardState();
}

class _RoleGuardState extends State<RoleGuard> {
  bool _isLoading = true;
  UserRole? _userRole;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _switchAccount() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    if (!mounted) return;
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

  Future<void> _checkRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _userRole = null;
        });
        return;
      }
      final role = await UserService.getUserRole(user.id);
      if (!mounted) return;
      setState(() {
        _userRole = role;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _userRole = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_userRole != widget.requiredRole) {
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
                const Text('You do not have permission to view this page.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _switchAccount,
                  child: const Text('Switch account'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return widget.child;
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final String route;

  const NavigationItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}

class ResponsiveDashboardWrapper extends StatefulWidget {
  const ResponsiveDashboardWrapper({super.key});

  @override
  State<ResponsiveDashboardWrapper> createState() =>
      _ResponsiveDashboardWrapperState();
}

class _ResponsiveDashboardWrapperState
    extends State<ResponsiveDashboardWrapper> {
  UserRole? _userRole;
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final role = await UserService.getUserRole(user.id);
        setState(() {
          _userRole = role;
          _isLoading = false;
        });
      } else {
        _signOut();
      }
    } catch (error) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          title: const Text('Error'),
          description: const Text('Failed to load user role'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
      _signOut();
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

  Future<void> _showLogoutConfirmation() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      _signOut();
    }
  }

  void _onDestinationSelected(int index) {
    // If role not yet loaded, ignore taps
    if (_userRole == null) return;

    final items = _getNavigationItems(_userRole!);
    final isLogout = index == items.length - 1;

    if (isLogout) {
      // Show confirmation dialog instead of changing the selected tab
      _showLogoutConfirmation();
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _getPageForIndex(int index, UserRole role) {
    // Get navigation items to determine the total count
    final navigationItems = _getNavigationItems(role);

    // Check if this is the logout index (last item)
    if (index == navigationItems.length - 1) {
      // This is the logout button, show confirmation dialog
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLogoutConfirmation();
      });
      // Return current page while logout confirmation is showing
      return _getCurrentPage(role);
    }

    switch (role) {
      case UserRole.admin:
        switch (index) {
          case 0:
            return RoleGuard(
              requiredRole: UserRole.admin,
              child: const AdminDashboard(),
            );
          case 1:
            return RoleGuard(
              requiredRole: UserRole.admin,
              child: const UserListPage(),
            );
          case 2:
            return RoleGuard(
              requiredRole: UserRole.admin,
              child: const AdminAnalyticsPage(),
            );
          case 3:
            return RoleGuard(
              requiredRole: UserRole.admin,
              child: const AdminProfilePage(),
            );
          default:
            return RoleGuard(
              requiredRole: UserRole.admin,
              child: const AdminDashboard(),
            );
        }
      case UserRole.inspector:
        switch (index) {
          case 0:
            return RoleGuard(
              requiredRole: UserRole.inspector,
              child: const InspectorDashboard(),
            );
          case 1:
            return RoleGuard(
              requiredRole: UserRole.inspector,
              child: const FishScanningPage(),
            );
          case 2:
            return RoleGuard(
              requiredRole: UserRole.inspector,
              child: const FishProductsListPage(),
            );
          case 3:
            return RoleGuard(
              requiredRole: UserRole.inspector,
              child: const InspectorReportsPage(),
            );
          case 4:
            return RoleGuard(
              requiredRole: UserRole.inspector,
              child: const InspectorProfilePage(),
            );
          default:
            return RoleGuard(
              requiredRole: UserRole.inspector,
              child: const InspectorDashboard(),
            );
        }
      case UserRole.collector:
        switch (index) {
          case 0:
            return RoleGuard(
              requiredRole: UserRole.collector,
              child: const CollectorDashboard(),
            );
          case 1:
            return RoleGuard(
              requiredRole: UserRole.collector,
              child: const OrderPaymentPage(),
            );
          case 2:
            return RoleGuard(
              requiredRole: UserRole.collector,
              child: const CollectorReportsPage(),
            );
          case 3:
            return RoleGuard(
              requiredRole: UserRole.collector,
              child: const CollectorProfilePage(),
            );
          default:
            return RoleGuard(
              requiredRole: UserRole.collector,
              child: const CollectorDashboard(),
            );
        }
      case UserRole.teller:
        switch (index) {
          case 0:
            return RoleGuard(
              requiredRole: UserRole.teller,
              child: const TellerDashboard(),
            );
          case 1:
            return RoleGuard(
              requiredRole: UserRole.teller,
              child: const OfficialReceiptPage(),
            );
          case 2:
            return RoleGuard(
              requiredRole: UserRole.teller,
              child: const TellerReportsPage(),
            );
          case 3:
            return RoleGuard(
              requiredRole: UserRole.teller,
              child: const TellerProfilePage(),
            );
          default:
            return RoleGuard(
              requiredRole: UserRole.teller,
              child: const TellerDashboard(),
            );
        }
      case UserRole.gateCollector:
        switch (index) {
          case 0:
            return RoleGuard(
              requiredRole: UserRole.gateCollector,
              child: const GateCollectorDashboard(),
            );
          case 1:
            return RoleGuard(
              requiredRole: UserRole.gateCollector,
              child: const CertificateValidationPage(),
            );
          case 2:
            return RoleGuard(
              requiredRole: UserRole.gateCollector,
              child: const GateReportsPage(),
            );
          case 3:
            return RoleGuard(
              requiredRole: UserRole.gateCollector,
              child: const GateCollectorProfilePage(),
            );
          default:
            return RoleGuard(
              requiredRole: UserRole.gateCollector,
              child: const GateCollectorDashboard(),
            );
        }
    }
  }

  Widget _getCurrentPage(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return RoleGuard(
          requiredRole: UserRole.admin,
          child: const AdminDashboard(),
        );
      case UserRole.inspector:
        return RoleGuard(
          requiredRole: UserRole.inspector,
          child: const InspectorDashboard(),
        );
      case UserRole.collector:
        return RoleGuard(
          requiredRole: UserRole.collector,
          child: const CollectorDashboard(),
        );
      case UserRole.teller:
        return RoleGuard(
          requiredRole: UserRole.teller,
          child: const TellerDashboard(),
        );
      case UserRole.gateCollector:
        return RoleGuard(
          requiredRole: UserRole.gateCollector,
          child: const GateCollectorDashboard(),
        );
    }
  }

  List<NavigationItem> _getNavigationItems(UserRole userRole) {
    switch (userRole) {
      case UserRole.admin:
        return const [
          NavigationItem(
            icon: Icons.dashboard,
            label: 'Dashboard',
            route: '/admin',
          ),
          NavigationItem(
            icon: Icons.people,
            label: 'Users',
            route: '/admin/users',
          ),
          NavigationItem(
            icon: Icons.analytics,
            label: 'Analytics',
            route: '/admin/analytics',
          ),
          NavigationItem(
            icon: Icons.person,
            label: 'Profile',
            route: '/profile',
          ),
          NavigationItem(icon: Icons.logout, label: 'Logout', route: '/logout'),
        ];
      case UserRole.inspector:
        return const [
          NavigationItem(icon: Icons.home, label: 'Home', route: '/inspector'),
          NavigationItem(
            icon: Icons.qr_code_scanner,
            label: 'Scan',
            route: '/inspector/scan',
          ),
          NavigationItem(
            icon: Icons.list,
            label: 'Products',
            route: '/inspector/products',
          ),
          NavigationItem(
            icon: Icons.analytics,
            label: 'Reports',
            route: '/inspector/reports',
          ),
          NavigationItem(
            icon: Icons.person,
            label: 'Profile',
            route: '/profile',
          ),
          NavigationItem(icon: Icons.logout, label: 'Logout', route: '/logout'),
        ];
      case UserRole.collector:
        return const [
          NavigationItem(icon: Icons.home, label: 'Home', route: '/collector'),
          NavigationItem(
            icon: Icons.receipt_long,
            label: 'Orders',
            route: '/collector/orders',
          ),
          NavigationItem(
            icon: Icons.analytics,
            label: 'Reports',
            route: '/collector/reports',
          ),
          NavigationItem(
            icon: Icons.person,
            label: 'Profile',
            route: '/collector/profile',
          ),
          NavigationItem(icon: Icons.logout, label: 'Logout', route: '/logout'),
        ];
      case UserRole.teller:
        return const [
          NavigationItem(icon: Icons.home, label: 'Home', route: '/teller'),
          NavigationItem(
            icon: Icons.payment,
            label: 'Receipts',
            route: '/teller/receipts',
          ),
          NavigationItem(
            icon: Icons.analytics,
            label: 'Reports',
            route: '/teller/reports',
          ),
          NavigationItem(
            icon: Icons.person,
            label: 'Profile',
            route: '/profile',
          ),
          NavigationItem(icon: Icons.logout, label: 'Logout', route: '/logout'),
        ];
      case UserRole.gateCollector:
        return const [
          NavigationItem(icon: Icons.home, label: 'Home', route: '/gate'),
          NavigationItem(
            icon: Icons.qr_code_scanner,
            label: 'Validate',
            route: '/gate/validate',
          ),
          NavigationItem(
            icon: Icons.analytics,
            label: 'Reports',
            route: '/gate/reports',
          ),
          NavigationItem(
            icon: Icons.person,
            label: 'Profile',
            route: '/profile',
          ),
          NavigationItem(icon: Icons.logout, label: 'Logout', route: '/logout'),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading your dashboard...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    if (_userRole == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to determine user role',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Please contact your administrator',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _signOut, child: const Text('Sign Out')),
            ],
          ),
        ),
      );
    }

    return ResponsiveNavigation(
      userRole: _userRole!,
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onDestinationSelected,
      child: _getPageForIndex(_selectedIndex, _userRole!),
    );
  }
}

// Placeholder pages for navigation items that don't exist yet
class AdminUsersPage extends StatelessWidget {
  const AdminUsersPage({super.key});

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
            'User Management',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // Page Content
        Expanded(
          child: const Center(
            child: Text('User Management Page - Coming Soon'),
          ),
        ),
      ],
    );
  }
}

class AdminAnalyticsPage extends StatelessWidget {
  const AdminAnalyticsPage({super.key});

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
            'Analytics',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // Page Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Analytics Overview Card
                const AnalyticsCard(),
                const SizedBox(height: 16),
                // Additional analytics widgets can be added here
                _buildAdditionalStats(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalStats(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: AnalyticsService.getDashboardStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Error loading statistics: ${snapshot.error}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.red),
                ),
              ),
            ),
          );
        }

        final stats = snapshot.data ?? {};
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Statistics',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2.5,
                  children: [
                    _buildStatCard(
                      context,
                      'Total Inspections',
                      '${stats['total_inspections'] ?? 0}',
                      Icons.assignment,
                      Colors.blue,
                    ),
                    _buildStatCard(
                      context,
                      'Total Orders',
                      '${stats['total_orders'] ?? 0}',
                      Icons.shopping_cart,
                      Colors.green,
                    ),
                    _buildStatCard(
                      context,
                      'Total Receipts',
                      '${stats['total_receipts'] ?? 0}',
                      Icons.receipt,
                      Colors.orange,
                    ),
                    _buildStatCard(
                      context,
                      'Total Users',
                      '${stats['total_users'] ?? 0}',
                      Icons.people,
                      Colors.purple,
                    ),
                    _buildStatCard(
                      context,
                      'Today\'s Inspections',
                      '${stats['today_inspections'] ?? 0}',
                      Icons.today,
                      Colors.teal,
                    ),
                    _buildStatCard(
                      context,
                      'Active Vessels Today',
                      '${stats['active_vessels_today'] ?? 0}',
                      Icons.directions_boat,
                      Colors.indigo,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

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
            'Settings',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        // Page Content
        Expanded(
          child: const Center(child: Text('Settings Page - Coming Soon')),
        ),
      ],
    );
  }
}

class GateReportsPage extends StatelessWidget {
  const GateReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const GateCollectorReportsPage();
  }
}
