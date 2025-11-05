import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:toastification/toastification.dart';
import 'package:flutter/material.dart';
import 'activity_log_service.dart';
import 'user_service.dart';
import '../pages/auth/login_page.dart';

class LogoutService {
  /// Centralized logout with activity logging
  static Future<void> logout(BuildContext context) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      // Log logout activity before signing out
      if (user != null) {
        try {
          final userRole = await UserService.getUserRole(user.id);
          if (userRole != null) {
            await ActivityLogService.logActivity(
              userId: user.id,
              userRole: userRole.name,
              action: 'logout',
              description: 'User logged out',
              metadata: {
                'timestamp': DateTime.now().toIso8601String(),
                'ip_address': 'unknown',
              },
            );
          }
        } catch (e) {
          // Don't fail logout if activity logging fails
          debugPrint('Failed to log logout activity: $e');
        }
      }

      // Sign out from Supabase
      await Supabase.instance.client.auth.signOut();

      if (context.mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.info,
          style: ToastificationStyle.flat,
          title: const Text('Logged Out'),
          description: const Text('You have been logged out successfully'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 3),
        );

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) => const LoginPage(),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          style: ToastificationStyle.flat,
          title: const Text('Error'),
          description: const Text('Failed to logout'),
          alignment: Alignment.topRight,
          autoCloseDuration: const Duration(seconds: 4),
        );
      }
    }
  }
}
