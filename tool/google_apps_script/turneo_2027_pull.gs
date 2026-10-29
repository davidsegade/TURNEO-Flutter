/**
 * TURNEO 2027: Supabase planning_audit -> Google Sheets.
 *
 * Deploy this file in a bound Apps Script project for the target spreadsheet.
 * The script never contains the sync secret. Set it manually in
 * Project Settings -> Script properties as SYNC_SECRET.
 */
const TURNEO_SYNC = Object.freeze({
  endpoint:
      'https://iiaxbriosudkmhsqvksn.supabase.co/functions/v1/sheets-sync',
  spreadsheetId: '1qL4Wrv9aR-LXlmRME4wMo2-GaVAp3y1jYeqEHT-6_0w',
  mapSheet: 'SYNC_MAP',
  cursorProperty: 'SYNC_CURSOR',
  secretProperty: 'SYNC_SECRET',
  pageSize: 100,
  maxPagesPerRun: 20,
  activeIds: Object.freeze({u1: true, u4: true, u5: true}),
});

/** Public trigger entry point. Install it manually with setupTurneo2027Trigger. */
function pullTurneo2027() {
  const lock = LockService.getScriptLock();
  if (!lock.tryLock(30000)) {
    Logger.log('sync skipped: another run holds the lock');
    return {status: 'locked'};
  }
  try {
    const secret = scriptSecret_();
    const spreadsheet = SpreadsheetApp.openById(TURNEO_SYNC.spreadsheetId);
    const syncMap = readSyncMap_(spreadsheet);
    let cursor = PropertiesService.getScriptProperties()
        .getProperty(TURNEO_SYNC.cursorProperty);
    if (!cursor) {
      throw new Error('SYNC_CURSOR is missing; initialize it after verified backfill');
    }
    let pages = 0;
    let applied = 0;
    let ignored = 0;

    while (true) {
      if (++pages > TURNEO_SYNC.maxPagesPerRun) {
        throw new Error('sync page limit reached; cursor was not advanced');
      }
      const response = pullPage_(secret, cursor);
      const plan = planChanges(response.changes, syncMap, (reference) => {
        const range = spreadsheet.getSheetByName(reference.sheet)
            .getRange(reference.cell);
        return {range: range, value: range.getValue(), formula: range.getFormula()};
      });
      if (plan.errors.length) {
        throw new Error('sync rejected: ' + plan.errors.join('; '));
      }

      for (const write of plan.writes) write.range.setValue(write.value);
      SpreadsheetApp.flush();
      for (const write of plan.writes) {
        const observed = write.range.getValue();
        const formula = write.range.getFormula();
        if (formula || !sameValue_(observed, write.value)) {
          throw new Error('sync verification failed; cursor was not advanced');
        }
      }

      const nextCursor = response.cursor;
      if ((response.changes.length || response.hasMore) && !nextCursor) {
        throw new Error('sync response omitted cursor; cursor was not advanced');
      }
      if (nextCursor) {
        PropertiesService.getScriptProperties()
            .setProperty(TURNEO_SYNC.cursorProperty, String(nextCursor));
      }
      applied += plan.writes.length;
      ignored += plan.ignored.length;
      cursor = nextCursor || cursor;
      if (!response.hasMore) break;
    }
    Logger.log(JSON.stringify({status: 'ok', pages: pages, applied: applied, ignored: ignored}));
    return {status: 'ok', pages: pages, applied: applied, ignored: ignored};
  } finally {
    lock.releaseLock();
  }
}

/**
 * Run once manually after setting SYNC_SECRET. It never overwrites a cursor;
 * an explicit verified high-water value is required.
 */
function initializeTurneo2027Cursor(initialCursor) {
  scriptSecret_();
  if (initialCursor === undefined || initialCursor === null || String(initialCursor) === '') {
    throw new Error('provide a verified planning_audit cursor; no cursor was changed');
  }
  const properties = PropertiesService.getScriptProperties();
  const existing = properties.getProperty(TURNEO_SYNC.cursorProperty);
  if (existing !== null) return {status: 'already_initialized'};
  properties.setProperty(TURNEO_SYNC.cursorProperty, String(initialCursor));
  return {status: 'initialized'};
}

/** Manual setup only. It refuses to create a trigger without secret/cursor. */
function setupTurneo2027Trigger() {
  scriptSecret_();
  scriptCursor_();
  SpreadsheetApp.openById(TURNEO_SYNC.spreadsheetId)
      .getSheetByName(TURNEO_SYNC.mapSheet);
  const existing = ScriptApp.getProjectTriggers()
      .filter((trigger) => trigger.getHandlerFunction() === 'pullTurneo2027');
  if (!existing.length) {
    ScriptApp.newTrigger('pullTurneo2027').timeBased().everyMinutes(5).create();
  }
  return {status: 'ok', triggers: Math.max(existing.length, 1)};
}

function scriptSecret_() {
  const secret = PropertiesService.getScriptProperties()
      .getProperty(TURNEO_SYNC.secretProperty);
  if (!secret || !String(secret).trim()) {
    throw new Error('SYNC_SECRET is missing from ScriptProperties');
  }
  return String(secret);
}

function scriptCursor_() {
  const cursor = PropertiesService.getScriptProperties()
      .getProperty(TURNEO_SYNC.cursorProperty);
  if (!cursor || !String(cursor).trim()) {
    throw new Error('SYNC_CURSOR is missing from ScriptProperties');
  }
  return String(cursor);
}

function pullPage_(secret, cursor) {
  const response = UrlFetchApp.fetch(TURNEO_SYNC.endpoint, {
    method: 'post',
    contentType: 'application/json',
    headers: {'x-sync-secret': secret},
    payload: JSON.stringify({action: 'pull', cursor: cursor, limit: TURNEO_SYNC.pageSize}),
    muteHttpExceptions: true,
  });
  const status = response.getResponseCode();
  if (status < 200 || status >= 300) throw new Error('sheets-sync HTTP ' + status);
  return parsePullResponse_(JSON.parse(response.getContentText()));
}

function readSyncMap_(spreadsheet) {
  const sheet = spreadsheet.getSheetByName(TURNEO_SYNC.mapSheet);
  if (!sheet) throw new Error('missing hidden SYNC_MAP sheet');
  const values = sheet.getRange(1, 1, Math.max(sheet.getLastRow(), 1), 4).getValues();
  return buildSyncMap(values);
}

/** SYNC_MAP columns: exact sheet name, exact A1 cell, local_user_id, work_date. */
function buildSyncMap(rows) {
  const map = {};
  for (const row of rows) {
    if (!row || row.length < 4 || String(row[0]).trim().toUpperCase() === 'HOJA') continue;
    const sheet = String(row[0]).trim();
    const cell = String(row[1]).trim();
    const userId = String(row[2]).trim();
    const date = normalizeDate_(row[3]);
    if (!userId && !date && !sheet && !cell) continue;
    if (date && (date.slice(0, 4) !== '2027' || !TURNEO_SYNC.activeIds[userId])) {
      continue;
    }
    if (!TURNEO_SYNC.activeIds[userId] || !date || !sheet || !cell) {
      throw new Error('invalid SYNC_MAP row');
    }
    const key = changeKey_({user_local_id: userId, work_date: date});
    if (map[key]) throw new Error('duplicate SYNC_MAP row for ' + key);
    map[key] = {sheet: sheet, cell: cell};
  }
  return map;
}

function parsePullResponse_(payload) {
  if (!payload || !Array.isArray(payload.changes) || typeof payload.hasMore !== 'boolean') {
    throw new Error('invalid sheets-sync pull response');
  }
  return {
    changes: payload.changes,
    hasMore: payload.hasMore,
    cursor: payload.cursor === undefined || payload.cursor === null
        ? null
        : String(payload.cursor),
  };
}

/**
 * Pure processing stage. readCell returns {range, value, formula}; no Sheet API
 * is needed to test the safety rules. A write is allowed only when current=old.
 */
function planChanges(changes, syncMap, readCell) {
  const writes = [];
  const writesByCell = {};
  const virtual = {};
  const ignored = [];
  const errors = [];
  for (const raw of changes) {
    const change = normalizeChange_(raw);
    if (!change) {
      errors.push('invalid audit row');
      continue;
    }
    if (change.origin === 'google_sheets') {
      ignored.push(change.id);
      continue;
    }
    if (!TURNEO_SYNC.activeIds[change.userId] || change.date.slice(0, 4) !== '2027') {
      ignored.push(change.id);
      continue;
    }
    const reference = syncMap[changeKey_({user_local_id: change.userId, work_date: change.date})];
    if (!reference) {
      errors.push('missing SYNC_MAP row for ' + change.id);
      continue;
    }
    const cellKey = reference.sheet + '!' + reference.cell;
    if (!virtual[cellKey]) {
      const current = readCell(reference);
      virtual[cellKey] = {
        range: current.range,
        value: current.value,
        formula: current.formula,
        initialValue: current.value,
      };
    }
    const state = virtual[cellKey];
    if (state.formula) {
      errors.push('formula cell ' + reference.sheet + '!' + reference.cell);
      continue;
    }
    if (sameValue_(state.value, change.newValue)) continue;
    if (!sameValue_(state.value, change.oldValue)) {
      errors.push('old value conflict for ' + change.id);
      continue;
    }
    state.value = change.newValue;
    const outputValue = change.newValue === null ? '' : change.newValue;
    const existing = writesByCell[cellKey];
    if (sameValue_(state.initialValue, state.value)) {
      if (existing) {
        writes.splice(writes.indexOf(existing), 1);
        delete writesByCell[cellKey];
      }
    } else if (existing) {
      existing.id = change.id;
      existing.value = outputValue;
    } else {
      const write = {id: change.id, range: state.range, value: outputValue};
      writes.push(write);
      writesByCell[cellKey] = write;
    }
  }
  return {writes: writes, ignored: ignored, errors: errors};
}

function normalizeChange_(raw) {
  if (!raw || raw.id === undefined || raw.id === null) return null;
  const userId = String(raw.user_local_id || '').trim();
  const date = normalizeDate_(raw.work_date);
  if (!userId || !date || raw.new_service_code === undefined) return null;
  return {
    id: String(raw.id),
    userId: userId,
    date: date,
    oldValue: raw.old_service_code === undefined ? null : raw.old_service_code,
    newValue: raw.new_service_code === null || raw.new_service_code === ''
        ? null
        : raw.new_service_code,
    origin: String(raw.origin || '').trim(),
  };
}

function normalizeDate_(value) {
  const text = value instanceof Date
      ? Utilities.formatDate(value, Session.getScriptTimeZone(), 'yyyy-MM-dd')
      : String(value || '').trim();
  return /^\d{4}-\d{2}-\d{2}$/.test(text) ? text : null;
}

function changeKey_(change) {
  return change.user_local_id + '|' + change.work_date;
}

function sameValue_(left, right) {
  const a = left === null || left === undefined ? '' : String(left);
  const b = right === null || right === undefined ? '' : String(right);
  return a === b;
}

if (typeof module !== 'undefined') {
  module.exports = {
    TURNEO_SYNC: TURNEO_SYNC,
    buildSyncMap: buildSyncMap,
    parsePullResponse: parsePullResponse_,
    planChanges: planChanges,
  };
}
