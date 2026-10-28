import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:turneo/src/data/turneo_repository.dart';
import 'calendar_test.dart' show users;

void main() {
  test('monthly queries are bounded across year change; catalog is cached',
      () async {
    final requests = <http.Request>[];
    final client = SupabaseClient('https://example.com', 'test',
        httpClient: MockClient((request) async {
      requests.add(request);
      final table = request.url.pathSegments.last;
      return http.Response(
          jsonEncode(switch (table) {
            'services' => [
                {
                  'code': 'MC',
                  'label': 'Mañana',
                  'hours': 7.5,
                  'color': '#FFFFFF'
                }
              ],
            'app_users' => [
                {
                  'local_user_id': 'u2',
                  'display_name': 'Carlos',
                  'role': 'user',
                  'slot': 1,
                },
                {
                  'local_user_id': 'u3',
                  'display_name': 'Alejandro',
                  'role': 'user',
                  'slot': 3,
                },
                {
                  'local_user_id': 'u1',
                  'display_name': 'DAVID',
                  'role': 'admin',
                  'slot': 2,
                },
                {
                  'local_user_id': 'u4',
                  'display_name': 'JUAN',
                  'role': 'user',
                  'slot': 4,
                },
                {
                  'local_user_id': 'u5',
                  'display_name': 'Adrián',
                  'role': 'user',
                  'slot': 5,
                  'sheet_name': 'Santa Eufemia',
                },
              ],
            'balance_snapshots' => [
                {
                  'user_local_id': 'u2',
                  'das_available': 3,
                  'das_generated': 1,
                  'df_available': 2,
                  'pico_close': 1,
                  'pico_manual': 0
                },
                {
                  'user_local_id': 'u1',
                  'das_available': 8,
                  'das_generated': 2,
                  'df_available': 4,
                  'pico_close': 3,
                  'pico_manual': null,
                }
              ],
            'planning' => [
                {
                  'work_date': '2026-12-01',
                  'user_local_id': 'u2',
                  'service_code': 'MC'
                },
                {
                  'work_date': '2026-12-02',
                  'user_local_id': 'u2',
                  'service_code': null
                },
                {
                  'work_date': '2026-12-03',
                  'user_local_id': 'u1',
                  'service_code': 'MC'
                },
              ],
            _ => [],
          }),
          200,
          request: request,
          headers: {'content-type': 'application/json'});
    }));
    addTearDown(client.dispose);
    final repo = TurneoRepository(client: client);
    final month = await repo.loadMonth(DateTime(2026, 12, 15));
    expect(month.assignments, {'u1|2026-12-03': 'MC'});
    expect(month.hours['MC'], 7.5);
    expect(month.balances.containsKey('u2'), isFalse);
    expect(month.balances['u1']?.dasAvailable, 8);
    expect(month.balances['u1']?.dfAvailable, 4);
    expect(month.balances['u1']?.pico, 3);
    expect(month.users.map((user) => user.id), ['u1', 'u4', 'u5']);
    expect(month.users.singleWhere((user) => user.id == 'u1').role, 'admin');
    final balanceRequest = requests
        .firstWhere((r) => r.url.pathSegments.last == 'balance_snapshots');
    expect(balanceRequest.url.queryParameters['period_id'], 'eq.2026-12');
    for (final request in requests.where(
        (r) => ['planning', 'holidays'].contains(r.url.pathSegments.last))) {
      final column = request.url.pathSegments.last == 'planning'
          ? 'work_date'
          : 'holiday_date';
      expect(request.url.queryParametersAll[column],
          containsAll(['gte.2026-12-01', 'lt.2027-01-01']));
      expect(request.url.queryParameters['app_id'], 'eq.default');
    }
    await repo.loadMonth(DateTime(2027, 1));
    expect(
        requests.where((r) => r.url.pathSegments.last == 'services').length, 1);
    expect(requests.where((r) => r.url.pathSegments.last == 'app_users').length,
        1);
    final usersRequest =
        requests.firstWhere((r) => r.url.pathSegments.last == 'app_users');
    expect(usersRequest.url.queryParameters['select'], contains('sheet_name'));
  });

  test('unauthorized edits are rejected before any HTTP request', () async {
    var requests = 0;
    final client = SupabaseClient('https://example.com', 'test',
        httpClient: MockClient((request) async {
      requests++;
      return http.Response('[]', 200);
    }));
    addTearDown(client.dispose);
    final repo = TurneoRepository(client: client);
    await expectLater(
        repo.saveService('u2', DateTime(2026, 9, 1), 'M'), throwsStateError);
    repo.profile = users.first;
    expect(repo.canEdit('u2'), isTrue);
    await expectLater(
        repo.saveService('u1', DateTime(2026, 9, 1), 'M'), throwsStateError);
    expect(requests, 0);
    repo.profile = users[1];
    expect(users.every((u) => repo.canEdit(u.id)), isTrue);
  });

  test('2026 edits are rejected before any HTTP request', () async {
    var requests = 0;
    final client = SupabaseClient('https://example.com', 'test',
        httpClient: MockClient((request) async {
      requests++;
      return http.Response('{}', 200);
    }));
    addTearDown(client.dispose);
    final repo = TurneoRepository(client: client)..profile = users[1];

    await expectLater(
        repo.saveService('u2', DateTime(2026, 12, 31), 'M'), throwsStateError);
    expect(requests, 0);
  });
}
