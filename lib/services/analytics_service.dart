import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get comprehensive dashboard statistics
  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      // Total users
      final usersRes = await _supabase.from('user_profiles').select('id');
      final totalUsers = (usersRes as List).length;

      // Total fish products (inspections)
      final productsRes = await _supabase.from('fish_products').select('id');
      final totalInspections = (productsRes as List).length;

      // Today inspections
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayRes = await _supabase
          .from('fish_products')
          .select('id, created_at, vessel_name, vessel_registration')
          .gte('created_at', todayStart.toIso8601String());
      final todayInspections = (todayRes as List).length;

      // Active vessels today (unique vessels from all fish products)
      final allVesselsRes = await _supabase
          .from('fish_products')
          .select('vessel_name, vessel_registration');

      final activeVesselsToday = <String>{};
      for (final item in allVesselsRes) {
        final vesselName = item['vessel_name'] as String?;
        final vesselReg = item['vessel_registration'] as String?;
        if (vesselName != null && vesselName.isNotEmpty) {
          activeVesselsToday.add(vesselName);
        } else if (vesselReg != null && vesselReg.isNotEmpty) {
          activeVesselsToday.add(vesselReg);
        }
      }

      // Orders/Receipts stats
      final receiptsRes = await _supabase
          .from('receipts')
          .select('amount_paid');
      final totalOrders = (receiptsRes as List).length;
      double totalPayments = 0.0;
      for (final row in receiptsRes) {
        final amt = row['amount_paid'];
        if (amt != null) totalPayments += (amt as num).toDouble();
      }

      return {
        'total_inspections': totalInspections,
        'total_orders': totalOrders,
        'total_receipts': totalOrders,
        'total_users': totalUsers,
        'today_inspections': todayInspections,
        'active_vessels_today': activeVesselsToday.length,
        'total_payments_collected': totalPayments,
        'top_species': <Map<String, dynamic>>[],
        'recent_activities': <Map<String, dynamic>>[],
      };
    } catch (e) {
      return {
        'total_inspections': 0,
        'total_orders': 0,
        'total_receipts': 0,
        'total_users': 0,
        'today_inspections': 0,
        'active_vessels_today': 0,
        'total_payments_collected': 0.0,
        'top_species': <Map<String, dynamic>>[],
        'recent_activities': <Map<String, dynamic>>[],
      };
    }
  }

  /// Get fish species distribution for pie chart
  static Future<List<Map<String, dynamic>>> getFishSpeciesDistribution() async {
    try {
      final response = await _supabase.from('fish_products').select('species');

      final speciesCount = <String, int>{};
      for (final item in response as List) {
        final species = item['species'] as String;
        speciesCount[species] = (speciesCount[species] ?? 0) + 1;
      }

      return speciesCount.entries
          .map(
            (entry) => {
              'species': entry.key,
              'count': entry.value,
              'percentage':
                  (entry.value /
                          speciesCount.values.reduce((a, b) => a + b) *
                          100)
                      .round(),
            },
          )
          .toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    } catch (e) {
      return [];
    }
  }

  /// Get payments collected over time for line chart
  static Future<List<Map<String, dynamic>>> getPaymentsOverTime({
    int days = 30,
  }) async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));

      final response = await _supabase
          .from('receipts')
          .select('amount_paid, payment_date')
          .gte('payment_date', startDate.toIso8601String().split('T')[0])
          .order('payment_date', ascending: true);

      final dailyPayments = <String, double>{};
      for (final item in response as List) {
        final date = item['payment_date'] as String;
        final amount = (item['amount_paid'] as num).toDouble();
        dailyPayments[date] = (dailyPayments[date] ?? 0.0) + amount;
      }

      // Fill in missing dates with 0
      final result = <Map<String, dynamic>>[];
      for (int i = 0; i < days; i++) {
        final date = startDate.add(Duration(days: i));
        final dateStr = date.toIso8601String().split('T')[0];
        result.add({'date': dateStr, 'amount': dailyPayments[dateStr] ?? 0.0});
      }

      return result;
    } catch (e) {
      return [];
    }
  }

  /// Get vessel activities
  static Future<List<Map<String, dynamic>>> getVesselActivities({
    int limit = 10,
  }) async {
    try {
      final response = await _supabase
          .from('fish_products')
          .select(
            'vessel_name, vessel_registration, inspector_name, created_at, species',
          )
          .not('vessel_name', 'is', null)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map(
            (item) => {
              'vessel_name': item['vessel_name'] as String?,
              'vessel_registration': item['vessel_registration'] as String?,
              'inspector_name': item['inspector_name'] as String?,
              'species': item['species'] as String,
              'created_at': item['created_at'] as String,
            },
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get inspection status distribution
  static Future<List<Map<String, dynamic>>>
  getInspectionStatusDistribution() async {
    try {
      final response = await _supabase.from('fish_products').select('status');

      final statusCount = <String, int>{};
      for (final item in response as List) {
        final status = item['status'] as String;
        statusCount[status] = (statusCount[status] ?? 0) + 1;
      }

      return statusCount.entries
          .map((entry) => {'status': entry.key, 'count': entry.value})
          .toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    } catch (e) {
      return [];
    }
  }

  /// Get monthly revenue trend
  static Future<List<Map<String, dynamic>>> getMonthlyRevenueTrend({
    int months = 12,
  }) async {
    try {
      final endDate = DateTime.now();
      final startDate = DateTime(endDate.year, endDate.month - months + 1, 1);

      final response = await _supabase
          .from('receipts')
          .select('amount_paid, payment_date')
          .gte('payment_date', startDate.toIso8601String().split('T')[0])
          .order('payment_date', ascending: true);

      final monthlyRevenue = <String, double>{};
      for (final item in response as List) {
        final date = DateTime.parse(item['payment_date'] as String);
        final monthKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}';
        final amount = (item['amount_paid'] as num).toDouble();
        monthlyRevenue[monthKey] = (monthlyRevenue[monthKey] ?? 0.0) + amount;
      }

      // Fill in missing months with 0
      final result = <Map<String, dynamic>>[];
      for (int i = 0; i < months; i++) {
        final date = DateTime(startDate.year, startDate.month + i, 1);
        final monthKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}';
        result.add({
          'month': monthKey,
          'revenue': monthlyRevenue[monthKey] ?? 0.0,
        });
      }

      return result;
    } catch (e) {
      return [];
    }
  }
}
