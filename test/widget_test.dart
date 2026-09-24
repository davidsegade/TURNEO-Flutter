import 'package:flutter_test/flutter_test.dart';
import 'package:turneo/src/models/turneo_models.dart';

void main(){
  test('month title uses Spanish month name',(){
    final d=MonthData(month:DateTime(2026,9),assignments:{},colors:{},users:const [],holidays:{});
    expect(d.title,'SEPTIEMBRE 2026');
  });
}
