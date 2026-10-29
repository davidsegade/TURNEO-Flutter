---
name: turneo-sheets-sync-2027
description: Safely inspect, change, test, or explain the TURNEO 2027 Supabase to Google Sheets synchronization. Use when working on planning writes, planning_audit, turneo_2027_pull.gs, SYNC_MAP, sync cursors, roster IDs, or Sheets reconciliation. Preserve 2026 history, fail closed on ambiguous cells, and never expose or invent sync secrets.
compatibility: Requires Node.js for the Apps Script unit tests and Flutter tooling for Dart changes. Production Sheets, Supabase, Apps Script triggers, and credentials are outside this repository and must not be contacted or changed.
metadata:
  author: turneo
  scope: project
  standard: agentskills
  version: "1.0"
---

# TURNEO 2027 Sheets Sync

Use this skill for the repository's explicit data boundary:

`Excel corporate <-> Google Sheets <-> Supabase <-> TURNEO Flutter`

## Source of truth and safety rules

- Flutter writes `planning` through Supabase; it does not call Google Sheets.
- The Apps Script pull reads the Supabase audit stream and writes only mapped 2027 cells.
- 2026 is read-only historical data. Never rewrite, migrate, or delete it while changing this flow.
- The 2026 and 2027 books use the same ID-based `SYNC_MAP` positions: row 9 is
  `u1` / `DAVID`, row 10 is `u4` / `JUAN`, row 11 is `u5` / `SANTA EUFEMIA`
  (Adrián), and row 12 is hidden.
- The active visible local IDs are `u1`, `u4`, and `u5`. `u2` (Carlos) and
  `u3` (Alejandro) are inactive in Supabase and must not be shown in the app.
  Planning and audit records for them may remain archived or inactive; do not
  claim complete database deletion.
- Never put `SYNC_SECRET`, Supabase keys, tokens, or workbook credentials in source, logs, tests, or commits.
- Do not install triggers, deploy Edge Functions, call production endpoints, or mutate a spreadsheet from this skill.

## Workflow

1. Read `README.md`, `tool/google_apps_script/README.md`, `lib/src/data/turneo_policy.dart`, and `lib/src/data/turneo_repository.dart` before changing contracts.
2. For Apps Script behavior, run:

   ```bash
   node --test tool/google_apps_script/turneo_2027_pull.test.js
   ```

3. Keep changes fail-closed: missing map rows, formula cells, old-value conflicts, malformed responses, and unsafe years must remain errors rather than guessed writes.
4. Keep pull processing idempotent. Echo rows with `origin = google_sheets`, inactive IDs, and pre-2027 dates must remain ignored without writes.
5. If changing Flutter writes, verify `TurneoWritePolicy.targetYear`, the active roster, monthly query bounds, RLS-observable write readback, and the existing focused tests.
6. Report local evidence separately from any production verification. Production verification requires a human operator with credentials and is not implied by passing local tests.

## Required review checklist

- [ ] No 2026 row is written or rewritten.
- [ ] Only `u1`, `u4`, and `u5` are in the active 2027 map.
- [ ] `u5` remains mapped to `Santa Eufemia`.
- [ ] Both book maps use the ID positions: rows 9, 10, 11 for `u1`, `u4`, `u5`; row 12 remains hidden.
- [ ] `u5` uses DAS baseline `0`; existing national, autonomous, and local holiday formulas yield DF 5 for December 2026 and DF 6 for January 2027.
- [ ] December 2027 DF is documented as a forecast of `18` only if `u5` takes no DF.
- [ ] `u2/u3` are documented as inactive and not visible, without claiming complete DB deletion.
- [ ] Cursor advances only from the validated response high-water mark.
- [ ] Formula cells and old-value conflicts block the cursor.
- [ ] No secret or production side effect was introduced.
- [ ] Node tests and relevant Flutter tests pass.
