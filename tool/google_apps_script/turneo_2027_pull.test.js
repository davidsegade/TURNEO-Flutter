const assert = require('node:assert/strict');
const test = require('node:test');

require.extensions['.gs'] = require.extensions['.js'];
const sync = require('./turneo_2027_pull.gs');

const map = sync.buildSyncMap([
  ['HOJA', 'CELDA', 'USUARIO', 'FECHA'],
  ['Enero', 'B4', 'u1', '2027-01-01'],
  ['Enero', 'B5', 'u4', '2027-01-01'],
  ['Enero', 'B6', 'u5', '2027-01-01'],
  ['Enero', 'B7', 'u5', '2028-01-01'],
]);

test('active map accepts u1, u4 and u5 only', () => {
  assert.deepEqual(Object.keys(map), ['u1|2027-01-01', 'u4|2027-01-01', 'u5|2027-01-01']);
  assert.deepEqual(sync.buildSyncMap([['Enero', 'B7', 'u2', '2026-01-01']]), {});
});

test('old/new processing is idempotent and preserves formulas', () => {
  const cells = {
    'Enero!B4': {value: 'M', formula: ''},
    'Enero!B5': {value: 'TC', formula: ''},
    'Enero!B6': {value: 'M', formula: '=SUM(A1:A2)'},
  };
  const changes = [
    {id: 1, user_local_id: 'u1', work_date: '2027-01-01', old_service_code: 'M', new_service_code: 'MC'},
    {id: 2, user_local_id: 'u4', work_date: '2027-01-01', old_service_code: 'TC', new_service_code: 'TC'},
    {id: 3, user_local_id: 'u5', work_date: '2027-01-01', old_service_code: 'M', new_service_code: 'N'},
  ];
  const plan = sync.planChanges(changes, map, (reference) => ({
    range: reference,
    ...cells[`${reference.sheet}!${reference.cell}`],
  }));
  assert.deepEqual(plan.writes.map((write) => [write.id, write.value]), [['1', 'MC']]);
  assert.deepEqual(plan.errors, ['formula cell Enero!B6']);
});

test('sequential events for one cell use virtual state and coalesce', () => {
  const changes = [
    {id: 10, user_local_id: 'u1', work_date: '2027-01-01', old_service_code: 'M', new_service_code: 'MC'},
    {id: 11, user_local_id: 'u1', work_date: '2027-01-01', old_service_code: 'MC', new_service_code: 'N'},
  ];
  let reads = 0;
  const plan = sync.planChanges(changes, map, (reference) => {
    reads++;
    return {range: reference, value: 'M', formula: ''};
  });
  assert.equal(reads, 1);
  assert.deepEqual(plan.writes.map((write) => [write.id, write.value]), [['11', 'N']]);
  assert.deepEqual(plan.errors, []);
});

test('inactive, pre-2027 and echo rows are ignored without writes', () => {
  const rows = [
    {id: 4, user_local_id: 'u2', work_date: '2027-01-01', old_service_code: '', new_service_code: 'M'},
    {id: 5, user_local_id: 'u1', work_date: '2026-12-31', old_service_code: '', new_service_code: 'M'},
    {id: 6, user_local_id: 'u1', work_date: '2027-01-01', old_service_code: '', new_service_code: 'M', origin: 'google_sheets'},
  ];
  const plan = sync.planChanges(rows, map, () => ({range: {}, value: '', formula: ''}));
  assert.deepEqual(plan.writes, []);
  assert.deepEqual(plan.ignored, ['4', '5', '6']);
  assert.deepEqual(plan.errors, []);
});

test('in-scope missing map still fails closed', () => {
  const plan = sync.planChanges([{
    id: 7,
    user_local_id: 'u1',
    work_date: '2027-01-02',
    old_service_code: '',
    new_service_code: 'M',
  }], map, () => ({range: {}, value: '', formula: ''}));
  assert.deepEqual(plan.writes, []);
  assert.deepEqual(plan.errors, ['missing SYNC_MAP row for 7']);
});

test('production pull response uses cursor as the high-water id', () => {
  assert.deepEqual(sync.parsePullResponse({
    changes: [{
      id: 417,
      user_local_id: 'u1',
      work_date: '2027-01-04',
      old_service_code: 'M',
      new_service_code: 'MC',
      origin: 'app',
    }],
    hasMore: false,
    cursor: 417,
  }), {
    changes: [{
      id: 417,
      user_local_id: 'u1',
      work_date: '2027-01-04',
      old_service_code: 'M',
      new_service_code: 'MC',
      origin: 'app',
    }],
    hasMore: false,
    cursor: '417',
  });
  assert.throws(() => sync.parsePullResponse({changes: []}));
});
