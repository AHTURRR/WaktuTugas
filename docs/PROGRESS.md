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
Not started. The Supabase CLI is not installed in this environment, so migrations, pgTAP authorization tests, and RPC integration tests have not been created or claimed as passing. Do not treat the local fixture tests as evidence that backend authorization or transaction guarantees work.
