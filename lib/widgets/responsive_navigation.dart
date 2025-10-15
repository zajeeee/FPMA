import 'package:flutter/material.dart';
import '../models/user_role.dart';

class ResponsiveNavigation extends StatelessWidget {
  final Widget child;
  final UserRole userRole;
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  const ResponsiveNavigation({
    super.key,
    required this.child,
    required this.userRole,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use sidebar navigation for screens wider than 768px
        if (constraints.maxWidth > 768) {
          return _DesktopLayout(
            userRole: userRole,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            child: child,
          );
        } else {
          // Use bottom navigation for mobile screens
          return _MobileLayout(
            userRole: userRole,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            child: child,
          );
        }
      },
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  final Widget child;
  final UserRole userRole;
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  const _DesktopLayout({
    required this.child,
    required this.userRole,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final hasLogout = _getNavigationItems(
      userRole,
    ).any((i) => i.route == '/logout');
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // App Logo/Title
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.water_drop,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'FPMS',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        'Fish Product Monitoring',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Navigation Items
                Expanded(child: _buildNavigationItems(context)),
                // User Info
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Divider(),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.1),
                            child: Icon(
                              userRole.icon,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userRole.displayName,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  userRole.description,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (hasLogout) ...[
                        const SizedBox(height: 12),
                        // Logout Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // Trigger logout confirmation
                              onDestinationSelected(
                                _getNavigationItems(userRole).length - 1,
                              );
                            },
                            icon: const Icon(Icons.logout, size: 16),
                            label: const Text('Logout'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.error,
                              side: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.error.withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildNavigationItems(BuildContext context) {
    final navigationItems = _getNavigationItems(userRole);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: navigationItems.length,
      itemBuilder: (context, index) {
        final item = navigationItems[index];
        final isSelected = selectedIndex == index;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Material(
            color:
                isSelected
                    ? Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.3)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onDestinationSelected(index),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      item.icon,
                      size: 20,
                      color:
                          isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                          fontWeight:
                              isSelected ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MobileLayout extends StatelessWidget {
  final Widget child;
  final UserRole userRole;
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  const _MobileLayout({
    required this.child,
    required this.userRole,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final navigationItems = _getNavigationItems(userRole);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: Container(
            constraints: const BoxConstraints(minHeight: 60, maxHeight: 80),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children:
                  navigationItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isSelected = selectedIndex == index;

                    return Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => onDestinationSelected(index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primaryContainer
                                                .withValues(alpha: 0.3)
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    item.icon,
                                    size: 18,
                                    color:
                                        isSelected
                                            ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Flexible(
                                  child: Text(
                                    item.label,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(
                                      color:
                                          isSelected
                                              ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.7),
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.w500
                                              : FontWeight.normal,
                                      fontSize: 10,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ),
      ),
    );
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
        NavigationItem(icon: Icons.person, label: 'Profile', route: '/profile'),
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
        NavigationItem(icon: Icons.person, label: 'Profile', route: '/profile'),
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
        NavigationItem(icon: Icons.person, label: 'Profile', route: '/profile'),
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
        NavigationItem(icon: Icons.person, label: 'Profile', route: '/profile'),
        NavigationItem(icon: Icons.logout, label: 'Logout', route: '/logout'),
      ];
  }
}
