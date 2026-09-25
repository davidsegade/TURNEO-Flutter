import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/turneo_models.dart';

class ServiceOption {
  final String code, label, color;
  final double hours;
  const ServiceOption(
      {required this.code,
      required this.label,
      required this.hours,
      required this.color});
}

class TurneoRepository {
  final SupabaseClient db;
  TurneoRepository({SupabaseClient? client})
      : db = client ?? Supabase.instance.client;
  List<AppUser>? _users;
  List<ServiceOption>? _services;
  AppUser? profile;

  Future<AppUser> loadProfile() async {
    final uid = db.auth.currentUser?.id;
    if (uid == null)
      throw StateError('Inicia sesión para acceder al cuadrante.');
    final row = await db
        .from('app_users')
        .select('local_user_id,display_name,role,slot,color')
        .eq('app_id', 'default')
        .eq('auth_uid', uid)
        .eq('active', true)
        .maybeSingle();
    if (row == null)
      throw StateError(
          'Este acceso no está asociado a un usuario activo de TURNEO.');
    return profile = AppUser.fromMap(row);
  }

  bool canEdit(String userId) =>
      profile != null && (profile!.role == 'admin' || profile!.id == userId);

  Future<List<AppUser>> loadUsers() async {
    if (_users != null) return _users!;
    final rows = await db
        .from('app_users')
        .select('local_user_id,display_name,role,slot,color')
        .eq('app_id', 'default')
        .eq('active', true)
        .order('slot');
    return _users = rows.map(AppUser.fromMap).toList();
  }

  Future<List<ServiceOption>> loadServices() async {
    if (_services != null) return _services!;
    final rows = await db
        .from('services')
        .select('code,label,hours,color')
        .eq('active', true)
        .order('code');
    return _services = rows
        .map((row) => ServiceOption(
              code: row['code'] as String,
              label: row['label'] as String,
              hours: (row['hours'] as num).toDouble(),
              color: row['color'] as String,
            ))
        .toList();
  }

  // Returning the row makes an RLS-filtered or otherwise failed write observable.
  // The unique key is the existing planning key; audit triggers feed Sheets.
  Future<String?> saveService(
      String userId, DateTime date, String? serviceCode) async {
    if (!canEdit(userId))
      throw StateError('No puedes modificar este cuadrante.');
    final row = await db
        .from('planning')
        .upsert({
          'app_id': 'default',
          'user_local_id': userId,
          'work_date': isoDate(date),
          'service_code': serviceCode,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'updated_by': db.auth.currentUser!.id,
        }, onConflict: 'app_id,user_local_id,work_date')
        .select('service_code')
        .single();
    return row['service_code'] as String?;
  }

  Future<MonthData> loadMonth(DateTime month) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final results = await Future.wait<dynamic>([
      db
          .from('planning')
          .select('work_date,user_local_id,service_code')
          .eq('app_id', 'default')
          .gte('work_date', isoDate(start))
          .lt('work_date', isoDate(end)),
      loadServices(),
      loadUsers(),
      db
          .from('holidays')
          .select('holiday_date,name')
          .eq('app_id', 'default')
          .gte('holiday_date', isoDate(start))
          .lt('holiday_date', isoDate(end)),
    ]);
    final assignments = <String, String>{};
    for (final row in results[0] as List) {
      final code = row['service_code'] as String?;
      if (code != null && code.isNotEmpty)
        assignments['${row['user_local_id']}|${row['work_date']}'] = code;
    }
    final services = results[1] as List<ServiceOption>;
    return MonthData(
      month: start,
      assignments: assignments,
      colors: {for (final s in services) s.code: s.color},
      hours: {for (final s in services) s.code: s.hours},
      users: results[2] as List<AppUser>,
      holidays: {
        for (final row in results[3] as List)
          row['holiday_date'] as String: row['name'] as String
      },
    );
  }
}
