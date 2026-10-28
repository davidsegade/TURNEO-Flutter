# TURNEO 2027 Google Apps Script

This source implements the missing automatic **Supabase -> Google Sheets 2027**
pull. It does not modify the 2026 workbook and does not contain the sync secret.
The deployed Edge Function contract is:

```text
POST https://iiaxbriosudkmhsqvksn.supabase.co/functions/v1/sheets-sync
x-sync-secret: <ScriptProperties SYNC_SECRET>
{"action":"pull","cursor":<last planning_audit id>,"limit":100}
```

The response must contain `changes`, `hasMore`, and `cursor` (the last audit id
in the returned page). Each change
must contain `id`, `user_local_id`, `work_date`, `old_service_code`,
`new_service_code`, and optional `origin`. `origin = google_sheets` is skipped
to prevent an echo.

## Manual installation

1. Open the target spreadsheet `1qL4Wrv9aR-LXlmRME4wMo2-GaVAp3y1jYeqEHT-6_0w`
   and open **Extensions -> Apps Script**.
2. Add `turneo_2027_pull.gs`. Do not paste a secret into the source.
3. In **Project Settings -> Script properties**, add `SYNC_SECRET` with the
   secret supplied by the backend owner. Do not store it in Git or the sheet.
4. Create or verify the hidden sheet `SYNC_MAP` with columns A:D:
   exact target sheet name, exact A1 cell, `local_user_id`, `work_date`.
   The backfill currently has nine entries for 2027-01-01 through 2027-01-03.
5. Verify the map contains only `u1`, `u4`, and `u5`, with `u5` mapped as the
   `Santa Eufemia` Excel identity. Rows dated 2028 are ignored. The target workbook already contains the
   backfilled 20 shifts for `u1/u4` on January 1-10; do not recreate them.
6. The known local high-water is audit id `416` at `2026-10-28T22:15Z`; it is
   only a reference, not proof of the current production high-water. Verify
   the current maximum audit id and reconcile all changes after the completed
   backfill before activation. Configure the verified high-water directly as
   the `SYNC_CURSOR` Script property. `initializeTurneo2027Cursor(arg)` is a
   helper for code-driven setup, but the Apps Script function selector cannot
   pass its argument. It refuses to overwrite an existing cursor. The trigger
   refuses to run without this property, so it can never start implicitly at
   cursor 0 against a sheet that was already backfilled. If the boundary is
   unavailable, reconcile first.
7. Run `setupTurneo2027Trigger()` manually. It refuses to create a trigger
   unless both `SYNC_SECRET` and a non-empty `SYNC_CURSOR` exist, and creates a
   five-minute time trigger only when one is absent.

The trigger lock prevents concurrent runs. Every page is planned before writes;
inactive IDs and non-2027 dates are ignored and included in the minimal run
counts, so the large historical audit does not block the 2027 pull. Missing map
rows, old-value conflicts and formula cells for an in-scope `u1/u4/u5` 2027 row
fail closed. After writes, `SpreadsheetApp.flush()` and readback verify each
cell before the cursor is saved. Only mapped cells are written, so formulas
outside the explicit map are untouched.

The setup functions are intentionally not called automatically. Installation,
permissions, the trigger, production Supabase and the spreadsheet require a
manual operator with the appropriate credentials.

The processor keeps a virtual cell state inside each page, so sequential audit
events for one cell are coalesced to the final value. A final value equal to
the original value produces no write. Out-of-scope history is ignored; only
in-scope 2027 `u1/u4/u5` map/formula/conflict errors block the cursor.

## Local tests

From the repository root:

```text
node --test tool/google_apps_script/turneo_2027_pull.test.js
```

The tests load the same `.gs` source under Node and never call Apps Script,
Supabase, Google Sheets, `UrlFetchApp`, `LockService`, or `PropertiesService`.
