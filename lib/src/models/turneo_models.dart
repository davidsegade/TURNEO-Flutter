import 'package:flutter/material.dart';

class MonthData{
  final DateTime month;
  final Map<String,String> assignments;
  final Map<String,String> colors;
  MonthData({required this.month,required this.assignments,required this.colors});
  String get title=>'${month.month.toString().padLeft(2,'0')} / ${month.year}';
  Color serviceColor(String? code){
    final hex=colors[code]??'#1B2635';
    final v=hex.replaceFirst('#','');
    return Color(int.parse('FF$v',radix:16));
  }
}
