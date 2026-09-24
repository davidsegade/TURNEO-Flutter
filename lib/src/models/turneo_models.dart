import 'package:flutter/material.dart';

class AppUser {
  final String id;
  final String name;
  final String role;
  final int slot;
  final String color;
  const AppUser({required this.id,required this.name,required this.role,required this.slot,required this.color});
  factory AppUser.fromMap(Map<String,dynamic> m)=>AppUser(
    id:m['local_user_id'] as String,
    name:(m['display_name'] as String?)??'Usuario',
    role:(m['role'] as String?)??'user',
    slot:(m['slot'] as num?)?.toInt()??99,
    color:(m['color'] as String?)??'#94A3B8',
  );
}

class MonthData{
  final DateTime month;
  final Map<String,String> assignments;
  final Map<String,String> colors;
  final List<AppUser> users;
  final Map<String,String> holidays;
  MonthData({required this.month,required this.assignments,required this.colors,required this.users,required this.holidays});
  String get title=>'${const ['','ENERO','FEBRERO','MARZO','ABRIL','MAYO','JUNIO','JULIO','AGOSTO','SEPTIEMBRE','OCTUBRE','NOVIEMBRE','DICIEMBRE'][month.month]} ${month.year}';
  Color serviceColor(String? code){
    final hex=colors[code]??'#1B2635';
    final v=hex.replaceFirst('#','');
    return Color(int.parse('FF$v',radix:16));
  }
}
