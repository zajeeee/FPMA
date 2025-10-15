import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/activity_log.dart';
import '../models/activity_log_general.dart';

class ActivityLogService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Log an activity
  static Future<String?> logActivity({
    required String userId,
    required String userRole,
    required String action,
    String? description,
    String? referenceId,
    String? referenceType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _supabase.rpc(
        'log_activity',
        params: {
          'p_user_id': userId,
          'p_user_role': userRole,
          'p_action': action,
          'p_description': description,
          'p_reference_id': referenceId,
          'p_reference_type': referenceType,
          'p_metadata': metadata,
        },
      );

      return response as String?;
    } catch (e) {
      return null;
    }
  }

  /// Get activity logs with pagination
  static Future<List<ActivityLog>> getActivityLogs({
    int limit = 50,
    int offset = 0,
    String? action,
    String? userRole,
    String? referenceType,
  }) async {
    try {
      var query = _supabase.from('activity_logs').select();

      if (action != null) {
        query = query.eq('action', action);
      }
      if (userRole != null) {
        query = query.eq('user_role', userRole);
      }
      if (referenceType != null) {
        query = query.eq('reference_type', referenceType);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => ActivityLog.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get activity logs for a specific user
  static Future<List<ActivityLog>> getUserActivityLogs(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('activity_logs')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => ActivityLog.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get activity statistics
  static Future<Map<String, dynamic>> getActivityStats() async {
    try {
      // Get total activities
      final totalResponse = await _supabase.from('activity_logs').select('id');

      // Get activities by role
      final roleResponse = await _supabase
          .from('activity_logs')
          .select('user_role')
          .order('created_at', ascending: false);

      // Get activities by action
      final actionResponse = await _supabase
          .from('activity_logs')
          .select('action')
          .order('created_at', ascending: false);

      // Get today's activities
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayResponse = await _supabase
          .from('activity_logs')
          .select('id')
          .gte('created_at', todayStart.toIso8601String());

      final roles = <String, int>{};
      final actions = <String, int>{};

      for (final log in roleResponse as List) {
        final role = log['user_role'] as String;
        roles[role] = (roles[role] ?? 0) + 1;
      }

      for (final log in actionResponse as List) {
        final action = log['action'] as String;
        actions[action] = (actions[action] ?? 0) + 1;
      }

      return {
        'total_activities': (totalResponse as List).length,
        'today_activities': (todayResponse as List).length,
        'activities_by_role': roles,
        'activities_by_action': actions,
      };
    } catch (e) {
      return {
        'total_activities': 0,
        'today_activities': 0,
        'activities_by_role': <String, int>{},
        'activities_by_action': <String, int>{},
      };
    }
  }

  /// Get recent activities (last 24 hours)
  static Future<List<ActivityLog>> getRecentActivities({int limit = 10}) async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      final response = await _supabase
          .from('activity_logs')
          .select()
          .gte('created_at', yesterday.toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => ActivityLog.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get recent general activities (last 24 hours)
  static Future<List<ActivityLogGeneral>> getRecentGeneralActivities({
    int limit = 10,
  }) async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      final response = await _supabase
          .from('activity_logs')
          .select()
          .gte('created_at', yesterday.toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => ActivityLogGeneral.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get recent activities for a specific user
  static Future<List<ActivityLogGeneral>> getUserRecentActivities(
    String userId, {
    int limit = 10,
  }) async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      final response = await _supabase
          .from('activity_logs')
          .select()
          .eq('user_id', userId)
          .gte('created_at', yesterday.toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => ActivityLogGeneral.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }
}
