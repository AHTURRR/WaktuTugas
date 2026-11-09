# Implementation ledger — docs/Rencana_Implementasi_WaktuTugas.md

Scope: Task 1–3 only. PRD 1.2 is authoritative. Existing PRD is preserved.

- Ruling: create the Flutter application in the workspace root rather than a nested waktu_tugas folder, keeping docs and commands in one project. No existing application was present.
- Ruling: local mode uses synthetic in-memory state and an explicit demo login, never simulated Supabase credentials. Restart resets data; cloud auth/cache belong to Task 4–5.
- Ruling: Android smoke tests and release acceptance remain pending; user explicitly authorized continuing local checks without a device or accepted licenses.
- Pre-flight: Tasks 1/2 share immutable UTC models and fixtures; Task 2/3 share buildPreview and revision. No contract conflict. Controller owns mutations; planner stays pure.
- Ruling: use this persistent ledger and direct commands rather than POSIX skill helper scripts in this Windows workspace. Create a local implementation branch; no remote/push/cloud operation.

## Task 1
In progress. Toolchain: Flutter 3.44.8 stable, Dart 3.12.2, Android SDK 36.0.0, Android Studio JBR 25.0.3. Doctor reports unaccepted Android licenses and no Visual Studio. No Android device/AVD available. Visual Studio is not needed for the Android target.

Task 1: local checks passed: flutter analyze (no issues), flutter test test/planner test/ui (4 tests), dart format --output=none --set-exit-if-changed lib test (0 changed). Initial tests failed on missing implementation; navigation helper corrected for Indonesian back tooltip. Android not run. Placeholder routes will be completed in Task 3.


## Task 2
Local checks: 16 tests passed across planner/UI; initial planner tests failed before files existed. Corrected a test expectation: 20:00-20:30 WIB gives 30 of 90 requested minutes (60 missing), then the next task uses 20:30-21:30. No scheduling rule changed. Intervals, 14-date WIB window, ceil-minute, deterministic order and completed-history blocking implemented. Android not run.

## Task 3
Local checks: `flutter test` passed with 30 tests, including the responsive UI, task/activity forms, preview confirmation, deletion confirmation, and progress flows. `flutter analyze` passed with no issues. `dart format --output=none --set-exit-if-changed lib test integration_test` passed with no changes, and `git diff --check` reported no whitespace errors. The implementation remains an explicit in-memory demo: authentication, persistence, Supabase RPC/RLS, and offline cache are not enabled.

## Task 4
In progress. Supabase CLI 3.0.0 telah dipasang. `supabase start`, `supabase db reset`, dan `supabase test db` belum dapat dijalankan karena Docker Engine tidak aktif/tersedia pada `dockerDesktopLinuxEngine` (ECONNREFUSED pada port database lokal). Migrasi skema database relasional telah ditinjau di `supabase/migrations/`:
- `001_schema.sql`: 5 tabel inti (`planner_state`, `tasks`, `time_windows`, `activities`, `sessions`) dengan batasan integritas, durasi, dan kepemilikan.
- `002_policies.sql`: Kebijakan RLS berbasis `auth.uid() = user_id`, mencabut mutasi langsung (direct writes) via REST untuk memastikan seluruh pembaruan melewati transaksi ber-revisi.
- `003_rpc.sql`: Prosedur transaksional atomik `SECURITY DEFINER` dengan verifikasi revisi dan *row-locking* (`get_planner_snapshot`, CRUD tugas/waktu/kegiatan, `record_progress`, dan `confirm_schedule`). Parameter SQL yang berpotensi ambigu telah diberi nama `p_*`.
RPC belum dinyatakan lulus karena belum dieksekusi pada PostgreSQL.

## Task 5
Integrasi cloud telah ditambahkan secara opt-in:
- `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY` dibaca melalui `--dart-define`; tanpa keduanya aplikasi tetap berjalan dalam demo lokal.
- `PlannerApi` dan `LocalCache` dipakai oleh controller untuk snapshot, seluruh mutasi RPC, cache per `user_id`, fallback offline baca, dan pembersihan saat logout.
- Sesi Supabase disimpan melalui `flutter_secure_storage`; `service_role` tidak digunakan.
- Timeout, revisi basi, pergantian akun, dan offline cache memiliki jalur error di kode, tetapi uji terhadap backend nyata belum dijalankan karena Docker belum aktif.

## Verifikasi Android
- `flutter doctor --android-licenses`: seluruh lisensi Android diterima.
- `flutter devices`: hanya Windows, Chrome, dan Edge; tidak ada perangkat Android atau emulator.
- `flutter test`: 30 test lokal lulus.
- Integration test Android: belum dijalankan karena tidak ada target Android.
- `flutter build apk --release`: berhasil; `build/app/outputs/flutter-apk/app-release.apk` (55.8 MB).

## Acceptance criteria AC01–AC18
Status hanya dicentang bila ada bukti eksekusi pada backend/perangkat yang sesuai.

| AC | Status | Bukti |
|---|---|---|
| AC01–AC02 | Belum diverifikasi | Supabase test terblokir Docker |
| AC03–AC10 | Lulus lokal | Test planner terotomasi lulus |
| AC11–AC18 | Belum diverifikasi | RPC/integration test belum dijalankan |

## Task 4 continuation — 9 November 2026 (Asia/Jakarta)

Status: implementation and coverage expanded; **backend acceptance remains blocked**, not passed. No cloud resources, accounts, keys, or credentials were created. Existing app/data/UI edits were preserved.

Scope reviewed: PRD sections 6–9 and AC01/02/11–16/18; all three migrations, both pgTAP files, the existing RPC caller in `lib/data/planner_api.dart`, and the Task 4 plan. Changes reach only `supabase/migrations/{001_schema,002_policies,003_rpc}.sql`, `supabase/tests/{authorization,transactions}.sql`, `test/backend/planner_rpc_test.dart`, and this ledger.

Implementation changes:
- All eight mutators initialize and lock the owner's planner state before business writes, then reject NULL/mismatched revisions with `IS DISTINCT FROM`. Failed transactions cannot leave a revision increment or initial state row behind.
- SECURITY DEFINER functions use an empty search_path and qualified business tables. Table privileges revoke all direct mutations, including TRUNCATE, REFERENCES, and TRIGGER; authenticated keeps owner-filtered SELECT. EXECUTE revocation is limited to application RPCs rather than all public/extension functions.
- Sessions require finite, minute-aligned instants. New tasks require positive remaining time; existing tasks can reach zero. Task/window/activity/progress input validation returns application validation errors, including NULL fields, invalid bounds, missed-with-remaining, and NULL progress status.
- Confirmation validates the server's current WIB date and 14-date horizon, minute-aligned nonpast candidates, task ownership/deadline/remaining, total allocation, overlap, merged manual availability minus routine/event/blocked time and completed history. Server time is sampled after the owner lock. Replacing future planned sessions, inserting candidates, and incrementing revision remain one transaction.

Coverage added (written/reviewed, **not executed against PostgreSQL**):
- Authorization: two owners with fixed known foreign IDs across all five tables and snapshot datasets; RLS/grants, anon access, missing auth subject, all foreign-ID CRUD/progress paths, direct owner spoofing, owner-matched composite FK, and definer search_path/EXECUTE permissions. The old foreign-delete test looked up its target through RLS and therefore tested NULL instead of a foreign ID; this is corrected.
- Transactions: first writes and absent-state revision checks; NULL/stale revisions; invalid inputs with full before/after snapshot equality; bad candidate shape/types, foreign tasks, forbidden/past/out-of-horizon times, fractional minutes, deadline, zero remaining, total over-allocation, and overlap. A valid first candidate followed by a foreign candidate verifies rollback of both cancellation and insertion. Positive cases cover merged/adjacent windows, half-open busy boundaries, exact capacity, weekly patterns, missed-slot reuse, ignored spoofed JSON owner, empty confirmation, history preservation, missed/completed progress, increased remaining estimates, double close, and deletion cascade.
- `test/backend/planner_rpc_test.dart`: independent A/B clients plus a second A client; `Future.wait` races assert exactly one confirmation and one progress close succeeds at the same revision; stale retry and mid-transaction failure preserve full snapshots. Requires existing empty local test accounts. Setup/connection failures fail explicitly, with no skip or automatic signup. Fixture cleanup deletes only the test's own task/windows. The progress race waits for a real future minute to start; whole-test timeout is three minutes.

Checks actually run this continuation:

| Command/check | Actual result |
|---|---|
| `SUPABASE_TELEMETRY_DISABLED=1 supabase --version` (PowerShell environment assignment) | Passed: CLI 3.0.0. Initial invocation without telemetry disabled failed writing a telemetry temp file outside the workspace; disabling telemetry resolved that CLI issue. |
| `docker info --format '{{.ServerVersion}}'` | Blocked: `dockerDesktopLinuxEngine` named pipe does not exist; no running Docker engine. |
| `$env:SUPABASE_TELEMETRY_DISABLED='1'; supabase test db` | Blocked before SQL execution: target local stack `127.0.0.1:54322`, `DbConnectError`, connect EACCES. CLI also reports the existing deprecated `auth.email.enable_signup` setting. No pgTAP assertion or migration was executed. |
| `flutter test --no-pub test/planner test/ui` | Passed: 30 tests. SDK cache locking outside the workspace required the approved escalated tool invocation; an initial sandbox-only invocation could not open the SDK lockfile. |
| `flutter analyze --no-pub` | Passed: no issues, including the new backend test. |
| Direct installed Dart SDK: `dart analyze test/backend/planner_rpc_test.dart` | Passed: no issues on the final run. An earlier run reported one unnecessary import, which was removed. |
| Direct installed Dart SDK: `dart format --output=none --set-exit-if-changed test/backend` | Passed: 1 file, 0 changes after formatting. |
| `git diff --check` | Passed: no whitespace errors; Git printed existing LF/CRLF conversion warnings. This command does not include untracked SQL files. |
| Python standard-library whitespace assertions over `supabase/**/*.sql` and `test/backend/*.dart` | Passed: all 6 SQL/Dart files have no trailing whitespace. This is not a SQL parser or runtime check. |

Review: one independent read-only reviewer checked the SQL/RPC tests against the PRD. Two findings were addressed with explicit input validation and separate valid-task/bad-timestamp cases; SQL runtime verification of those fixes remains blocked. No claim of a SQL red-to-green test cycle is made.

Rulings:
- Continue Task 4 in the existing implementation branch and persistent ledger; do not reset, commit, or replace the user's in-progress Task 5 files. No remote action.
- Keep the already-used `p_*` RPC parameter names rather than renaming the Flutter contract during this coverage task. This is the existing deviation from the plan's verbatim argument naming; renaming requires changing `PlannerApi` and external callers together.
- Edit the existing untracked, never-runtime-verified migrations in place. There is no evidence of an applied backend in this workspace; an already-migrated database would instead need a forward migration. Do not reset any database containing real data.
- A preview's window_start may predate confirmation within the same WIB date and cannot be later than the server's rounded-up current minute; window_end must match the current 14-date horizon, and every candidate must still be in the future at lock acquisition. A preview crossing WIB midnight must be regenerated.

Still blocked / not run:
- `supabase start` / `supabase db reset` were not retried because the Docker prerequisite is absent. No reset or cloud operation was attempted.
- Final `supabase test db`, migration application/SQL compilation, and all runtime owner-isolation/transaction assertions need a disposable local Supabase stack. No psql/pg_prove executable is available as an alternative. Static review is not a SQL test pass.
- `flutter test --no-pub test/backend/planner_rpc_test.dart` was not run: there is no local backend and none of the required environment-variable names are present. It requires `SUPABASE_URL` (loopback only), `SUPABASE_PUBLISHABLE_KEY`, `WAKTUTUGAS_TEST_A_EMAIL`, `WAKTUTUGAS_TEST_A_PASSWORD`, `WAKTUTUGAS_TEST_B_EMAIL`, and `WAKTUTUGAS_TEST_B_PASSWORD`, supplied externally for existing empty test accounts; never commit their values.
- No Android/device/build/cloud/cache checks were run in this Task 4 continuation. AC01/02/11–16/18 remain unverified on a real backend; AC17 and Tasks 5–6 are outside this continuation.
