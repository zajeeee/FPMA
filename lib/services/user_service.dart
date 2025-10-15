import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_role.dart';
import '../models/user_profile.dart';

class UserService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get user role from user metadata
  static Future<UserRole?> getUserRole(String userId) async {
    try {
      // Only trust explicit role stored in user_profiles
      final response =
          await _supabase
              .from('user_profiles')
              .select('role')
              .eq('user_id', userId)
              .single();

      final dynamic roleField = response['role'];
      if (roleField is String && roleField.isNotEmpty) {
        try {
          return UserRole.values.firstWhere((r) => r.name == roleField);
        } catch (_) {
          // Unknown role string -> treat as no role
          return null;
        }
      }
      // No role set
      return null;
    } catch (e) {
      // Query failed or table missing -> do not infer; deny access
      return null;
    }
  }

  /// Update user role (admin only)
  static Future<bool> updateUserRole(String userId, UserRole newRole) async {
    try {
      await _supabase
          .from('user_profiles')
          .update({'role': newRole.name})
          .eq('user_id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get user count (admin only)
  static Future<int> getUserCount() async {
    try {
      final response = await _supabase.from('user_profiles').select('id');
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// Get all users (admin only)
  static Future<List<UserProfile>> getAllUsers() async {
    try {
      final response = await _supabase.from('user_profiles').select('''
            id,
            user_id,
            email,
            full_name,
            role,
            is_active,
            created_at,
            updated_at
          ''');

      final users = <UserProfile>[];
      for (final item in response as List) {
        try {
          users.add(UserProfile.fromJson(item));
        } catch (e) {
          // Skip invalid records but continue processing
          continue;
        }
      }
      return users;
    } catch (e) {
      return [];
    }
  }

  /// Create new user account (admin only)
  static Future<bool> createUser({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    bool isActive = true,
  }) async {
    try {
      // 1) Check if auth user already exists (service role key allows this)
      String? userId;
      try {
        final existing =
            await _supabase
                .from('auth.users')
                .select('id')
                .eq('email', email)
                .maybeSingle();
        if (existing != null && existing['id'] is String) {
          userId = existing['id'] as String;
        }
      } catch (_) {}

      // 2) Create auth user if not found yet
      if (userId == null) {
        final authResponse = await _supabase.auth.admin.createUser(
          AdminUserAttributes(
            email: email,
            password: password,
            emailConfirm: true,
          ),
        );
        userId = authResponse.user?.id;
      }

      if (userId == null) return false;

      // 3) Upsert profile (handles unique email constraint gracefully)
      await _supabase.from('user_profiles').upsert({
        'user_id': userId,
        'email': email,
        'full_name': fullName,
        'role': role.name,
        'is_active': isActive,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'email');

      return true;
    } catch (e) {
      // Handle error
    }
    return false;
  }

  /// Delete user account (admin only)
  static Future<bool> deleteUser(String userId) async {
    try {
      // Delete user profile first
      await _supabase.from('user_profiles').delete().eq('user_id', userId);

      // Delete auth user
      await _supabase.auth.admin.deleteUser(userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update user password (admin only)
  static Future<bool> updateUserPassword(
    String userId,
    String newPassword,
  ) async {
    try {
      await _supabase.auth.admin.updateUserById(
        userId,
        attributes: AdminUserAttributes(password: newPassword),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update user profile (admin only)
  static Future<bool> updateUserProfile({
    required String userId,
    String? fullName,
    UserRole? role,
    bool? isActive,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fullName != null) updateData['full_name'] = fullName;
      if (role != null) updateData['role'] = role.name;
      if (isActive != null) updateData['is_active'] = isActive;

      await _supabase
          .from('user_profiles')
          .update(updateData)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Toggle user active status (admin only)
  static Future<bool> toggleUserActiveStatus(String userId) async {
    try {
      // First get current status
      final response =
          await _supabase
              .from('user_profiles')
              .select('is_active')
              .eq('user_id', userId)
              .single();

      final currentStatus = response['is_active'] as bool;

      // Toggle the status
      await _supabase
          .from('user_profiles')
          .update({
            'is_active': !currentStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get user profile by user ID
  static Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response =
          await _supabase
              .from('user_profiles')
              .select('''
            id,
            user_id,
            email,
            full_name,
            role,
            is_active,
            created_at,
            updated_at
          ''')
              .eq('user_id', userId)
              .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Search users by name or email
  static Future<List<UserProfile>> searchUsers(String query) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('''
            id,
            user_id,
            email,
            full_name,
            role,
            is_active,
            created_at,
            updated_at
          ''')
          .or('full_name.ilike.%$query%,email.ilike.%$query%');

      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Filter users by role
  static Future<List<UserProfile>> getUsersByRole(UserRole role) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('''
            id,
            user_id,
            email,
            full_name,
            role,
            is_active,
            created_at,
            updated_at
          ''')
          .eq('role', role.name);

      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Filter users by active status
  static Future<List<UserProfile>> getUsersByActiveStatus(bool isActive) async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('''
            id,
            user_id,
            email,
            full_name,
            role,
            is_active,
            created_at,
            updated_at
          ''')
          .eq('is_active', isActive);

      return (response as List)
          .map((json) => UserProfile.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }
}
