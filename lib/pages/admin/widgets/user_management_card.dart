import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import '../../../models/user_role.dart';
import '../../../models/user_profile.dart';
import '../../../services/user_service.dart';

class UserManagementCard extends StatefulWidget {
  final List<UserProfile> users;
  final bool isLoading;
  final VoidCallback onRefresh;

  const UserManagementCard({
    super.key,
    required this.users,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  State<UserManagementCard> createState() => _UserManagementCardState();
}

class _UserManagementCardState extends State<UserManagementCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'User Management',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onRefresh,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Users',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Expanded(
                child:
                    widget.users.isEmpty
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No users found',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create the first user account',
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
                        )
                        : ListView.builder(
                          itemCount: widget.users.length,
                          itemBuilder: (context, index) {
                            final user = widget.users[index];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1),
                                  child: Icon(
                                    user.role.icon,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                title: Text(
                                  user.fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(user.email),
                                    Text(user.role.displayName),
                                    Text(
                                      'Created: ${_formatDate(user.createdAt)}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected:
                                      (value) => _handleUserAction(value, user),
                                  itemBuilder:
                                      (context) => [
                                        const PopupMenuItem(
                                          value: 'edit_role',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit),
                                              SizedBox(width: 8),
                                              Text('Edit Role'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'reset_password',
                                          child: Row(
                                            children: [
                                              Icon(Icons.lock_reset),
                                              SizedBox(width: 8),
                                              Text('Reset Password'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Delete User',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                ),
                              ),
                            );
                          },
                        ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _handleUserAction(String action, UserProfile user) {
    switch (action) {
      case 'edit_role':
        _showEditRoleDialog(user);
        break;
      case 'reset_password':
        _showResetPasswordDialog(user);
        break;
      case 'delete':
        _showDeleteConfirmation(user);
        break;
    }
  }

  void _showEditRoleDialog(UserProfile user) {
    showDialog(
      context: context,
      builder:
          (context) => _EditRoleDialog(
            user: user,
            currentRole: user.role,
            onRoleUpdated: widget.onRefresh,
          ),
    );
  }

  void _showResetPasswordDialog(UserProfile user) {
    showDialog(
      context: context,
      builder:
          (context) => _ResetPasswordDialog(
            user: user,
            onPasswordReset: widget.onRefresh,
          ),
    );
  }

  void _showDeleteConfirmation(UserProfile user) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete User'),
            content: Text(
              'Are you sure you want to delete ${user.fullName}? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _deleteUser(user);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteUser(UserProfile user) async {
    try {
      final success = await UserService.deleteUser(user.userId);
      if (success) {
        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.success,
            style: ToastificationStyle.flat,
            title: const Text('User Deleted'),
            description: const Text(
              'User account has been deleted successfully',
            ),
            alignment: Alignment.topRight,
            autoCloseDuration: const Duration(seconds: 3),
          );
          widget.onRefresh();
        }
      } else {
        throw Exception('Failed to delete user');
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          title: const Text('Error'),
          description: const Text('Failed to delete user account'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    }
  }
}

class _EditRoleDialog extends StatefulWidget {
  final UserProfile user;
  final UserRole currentRole;
  final VoidCallback onRoleUpdated;

  const _EditRoleDialog({
    required this.user,
    required this.currentRole,
    required this.onRoleUpdated,
  });

  @override
  State<_EditRoleDialog> createState() => _EditRoleDialogState();
}

class _EditRoleDialogState extends State<_EditRoleDialog> {
  late UserRole _selectedRole;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.currentRole;
  }

  Future<void> _updateRole() async {
    setState(() => _isLoading = true);

    try {
      final success = await UserService.updateUserRole(
        widget.user.userId,
        _selectedRole,
      );

      if (success) {
        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.success,
            style: ToastificationStyle.flat,
            title: const Text('Role Updated'),
            description: Text(
              'User role changed to ${_selectedRole.displayName}',
            ),
            alignment: Alignment.topRight,
            autoCloseDuration: const Duration(seconds: 3),
          );
          Navigator.of(context).pop();
          widget.onRoleUpdated();
        }
      } else {
        throw Exception('Failed to update role');
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          title: const Text('Error'),
          description: const Text('Failed to update user role'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit User Role'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Current role: ${widget.currentRole.displayName}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<UserRole>(
            value: _selectedRole,
            decoration: const InputDecoration(labelText: 'New Role'),
            items:
                UserRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Row(
                      children: [
                        Icon(role.icon, size: 20),
                        const SizedBox(width: 8),
                        Text(role.displayName),
                      ],
                    ),
                  );
                }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedRole = value);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _updateRole,
          child:
              _isLoading
                  ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Update Role'),
        ),
      ],
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  final UserProfile user;
  final VoidCallback onPasswordReset;

  const _ResetPasswordDialog({
    required this.user,
    required this.onPasswordReset,
  });

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final success = await UserService.updateUserPassword(
        widget.user.userId,
        _passwordController.text,
      );

      if (success) {
        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.success,
            style: ToastificationStyle.flat,
            title: const Text('Password Reset'),
            description: const Text(
              'User password has been reset successfully',
            ),
            alignment: Alignment.topRight,
            autoCloseDuration: const Duration(seconds: 3),
          );
          Navigator.of(context).pop();
        }
      } else {
        throw Exception('Failed to reset password');
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          title: const Text('Error'),
          description: const Text('Failed to reset user password'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Reset password for ${widget.user.fullName}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                prefixIcon: Icon(Icons.lock),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _resetPassword,
          child:
              _isLoading
                  ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Reset Password'),
        ),
      ],
    );
  }
}
