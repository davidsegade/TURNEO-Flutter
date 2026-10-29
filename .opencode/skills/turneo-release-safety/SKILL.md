---
name: turneo-release-safety
description: Audit and validate a TURNEO Flutter change before release or handoff. Use when modifying authentication, Supabase access, RLS-sensitive writes, monthly planning queries, Google Sheets synchronization, configuration, packaging, or release workflows. Produce local evidence without using privileged secrets or deploying anything.
compatibility: Requires Flutter and Dart tooling for application checks; Node.js for Apps Script tests. The skill is local-only and does not require production credentials, network access, or deployment access.
metadata:
  author: turneo
  scope: project
  standard: agentskills
  version: "1.0"
---

# TURNEO Release Safety

Treat release readiness as a bounded local audit, not as permission to publish.

## Repository boundaries

- The Flutter client uses only the Supabase publishable key and existing Auth/RLS boundaries.
- `config.json`, `build-config.json`, keys, tokens, and credentials are not release artifacts for Git.
- Planning writes are allowed only in 2027 and are returned by Supabase so RLS or write failures remain observable.
- Monthly planning queries must stay bounded to the selected month; do not load all history.
- Google Sheets synchronization is a separate Apps Script pull and requires manual operator setup.
- The pending `shift-register` deployment for `u5` is external work, not a local release success.

## Audit workflow

1. Inspect the diff and identify whether it touches auth, data policy, configuration, release files, or the Apps Script boundary.
2. Run the repository checks that do not require secrets:

   ```bash
   node --test tool/google_apps_script/turneo_2027_pull.test.js
   flutter analyze
   flutter test
   ```

3. Run `python3 tool/check_config.py` only when the operator explicitly provides the public configuration through environment variables. Never print those values and never substitute a secret from a file.
4. If a web release is requested, use the documented build command only after configuration preflight succeeds; do not publish the output.
5. Check that tests cover narrow month queries, 2026 read-only behavior, 2027 write policy, roster filtering, auth failure, save readback, and Sheets fail-closed behavior.
6. Distinguish `local checks passed`, `external verification pending`, and `release not performed` in the final report.

## Release blockers

Block the handoff when any of these is true:

- a credential is committed, logged, embedded in a skill, or copied into generated config;
- a change broadens queries beyond the selected month or allows writes outside 2027;
- an RLS-sensitive write is treated as successful without selected-row readback;
- a Sheets conflict, formula cell, missing map row, malformed response, or uncertain cursor is silently skipped;
- a required external deployment or trigger installation is presented as complete without operator evidence;
- any check fails or cannot run and the limitation is not reported.

## Evidence format

Report the exact command, exit result, and relevant artifact path for each local check. Do not claim Supabase, Sheets, Auth, RLS, or production trigger behavior from static analysis or unit tests alone.
