import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/turneo_models.dart';

class TurneoRepository{
  final SupabaseClient db=Supabase.instance.client;
  Future<MonthData> loadMonth(DateTime month) async{
    final start=DateTime(month.year,month.month,1);
    final end=DateTime(month.year,month.month+1,0);
    String iso(DateTime d)=>'${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
    final results=await Future.wait([
      db.from('planning').select('work_date,user_local_id,service_code').eq('app_id','default').gte('work_date',iso(start)).lte('work_date',iso(end)),
      db.from('services').select('code,color').eq('active',true),
    ]);
    final assignments=<String,String>{};
    for(final row in (results[0] as List)){
      final code=row['service_code'] as String?;
      if(code!=null&&code.isNotEmpty)assignments['${row['user_local_id']}|${row['work_date']}']=code;
    }
    final colors=<String,String>{};
    for(final row in (results[1] as List))colors[row['code'] as String]=(row['color'] as String?)??'#1B2635';
    return MonthData(month:month,assignments:assignments,colors:colors);
  }
}
