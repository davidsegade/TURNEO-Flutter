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
- The active local IDs are `u1`, `u4`, and `u5`; `u5` is the `Santa Eufemia` Sheets identity.
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
- [ ] Cursor advances only from the validated response high-water mark.
- [ ] Formula cells and old-value conflicts block the cursor.
- [ ] No secret or production side effect was introduced.
- [ ] Node tests and relevant Flutter tests pass.
