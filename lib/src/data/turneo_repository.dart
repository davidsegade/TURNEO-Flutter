import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/turneo_models.dart';

class ServiceOption{
  final String code;
  final String label;
  final double hours;
  final String color;
  const ServiceOption({required this.code,required this.label,required this.hours,required this.color});
}

class TurneoRepository{
  final SupabaseClient db=Supabase.instance.client;
  Future<List<AppUser>> loadUsers() async{
    final rows=await db.from('app_users').select('local_user_id,display_name,role,slot,color').eq('app_id','default').order('slot');
    return (rows as List).map((x)=>AppUser.fromMap(Map<String,dynamic>.from(x))).toList();
  }
  Future<List<ServiceOption>> loadServices() async{
    final rows=await db.from('services').select('code,label,hours,color').eq('active',true).order('code');
    return (rows as List).map((row)=>ServiceOption(
      code:row['code'] as String,
      label:(row['label'] as String?)??'',
      hours:(row['hours'] as num?)?.toDouble()??0,
      color:(row['color'] as String?)??'#1B2635',
    )).toList();
  }

  Future<String?> currentLocalUserId() async{
    final uid=db.auth.currentUser?.id;
    if(uid==null)return null;
    final row=await db.from('app_users').select('local_user_id').eq('app_id','default').eq('auth_uid',uid).maybeSingle();
    return row?['local_user_id'] as String?;
  }

  Future<void> saveService(String userId, DateTime date, String? serviceCode) async{
    String two(int n)=>n.toString().padLeft(2,'0');
    final workDate='${date.year}-${two(date.month)}-${two(date.day)}';
    final existing=await db.from('planning').select('id').eq('app_id','default').eq('user_local_id',userId).eq('work_date',workDate).maybeSingle();
    final values=<String,dynamic>{
      'service_code':serviceCode,
      'updated_at':DateTime.now().toUtc().toIso8601String(),
      'updated_by':db.auth.currentUser?.id,
    };
    if(existing==null){
      await db.from('planning').insert({
        'app_id':'default',
        'user_local_id':userId,
        'work_date':workDate,
        ...values,
      });
    }else{
      await db.from('planning').update(values).eq('id',existing['id']);
    }
  }

  Future<MonthData> loadMonth(DateTime month) async{
    final start=DateTime(month.year,month.month,1),end=DateTime(month.year,month.month+1,0);
    String iso(DateTime d)=>'${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    final results=await Future.wait([
      db.from('planning').select('work_date,user_local_id,service_code').eq('app_id','default').gte('work_date',iso(start)).lte('work_date',iso(end)),
      db.from('services').select('code,color').eq('active',true),
      db.from('app_users').select('local_user_id,display_name,role,slot,color').eq('app_id','default').order('slot'),
      db.from('holidays').select('holiday_date,name').eq('app_id','default').gte('holiday_date',iso(start)).lte('holiday_date',iso(end)),
    ]);
    final assignments=<String,String>{};
    for(final row in (results[0] as List)){final code=row['service_code'] as String?;if(code!=null&&code.isNotEmpty)assignments['${row['user_local_id']}|${row['work_date']}']=code;}
    final colors=<String,String>{};for(final row in (results[1] as List)){colors[row['code'] as String]=(row['color'] as String?)??'#1B2635';}
    final users=(results[2] as List).map((x)=>AppUser.fromMap(Map<String,dynamic>.from(x))).toList();
    final holidays=<String,String>{};for(final row in (results[3] as List)){holidays[row['holiday_date'] as String]=(row['name'] as String?)??'Festivo';}
    return MonthData(month:month,assignments:assignments,colors:colors,users:users,holidays:holidays);
  }
}
