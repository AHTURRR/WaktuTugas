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
| AC01–AC02 | Belum diverifikasi (Backend nyata terblokir Docker); Adapter teruji lokal | Uji unit `test/data/auth_storage_test.dart`, `test/data/planner_api_test.dart`, `test/data/cache_test.dart` lulus; uji PostgreSQL `supabase/tests/authorization.sql` terblokir Docker |
| AC03–AC10 | Lulus lokal | Test planner & UI terotomasi lulus (`test/planner/`, `test/ui/`, termasuk uji performa 50 tugas / 14 tanggal < 1 detik) |
| AC11–AC16 | Belum diverifikasi (Backend nyata terblokir Docker); Adapter & alur UI teruji lokal | Uji unit `test/data/planner_api_test.dart`, `test/ui/app_flow_test.dart` lulus; uji PostgreSQL `supabase/tests/transactions.sql` & `test/backend/planner_rpc_test.dart` terblokir Docker |
| AC17 | Lulus lokal (FFI SQLite + adapter); Belum diverifikasi pada perangkat Android fisik | `test/data/cache_test.dart` dan `test/ui/app_flow_test.dart` lulus; `integration_test/storage_test.dart` membutuhkan target perangkat Android |
| AC18 | Lulus lokal (`flutter analyze`, `flutter test`); Belum diverifikasi penuh pada backend hidup & perangkat Android | 50 test lokal (`test/planner`, `test/ui`, `test/data`) lulus, `flutter analyze --no-pub` 0 masalah, `flutter build apk --release` lulus |

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

## Task 5–6 Integration & Audit Completion — 9 November 2026 (Asia/Jakarta)

Status: Integrasi frontend-backend, hardening keamanan/offline/isolasi akun, pengujian lokal (`test/planner`, `test/ui`, `test/data`), serta dokumentasi (`README.md`, `docs/API.md`, `docs/TEST_RESULTS.md`, `docs/PROGRESS.md`) selesai. Eksekusi langsung terhadap PostgreSQL/Supabase lokal dan perangkat Android tetap dipisahkan secara jujur karena prasyarat eksternal (Docker Engine dan perangkat Android/AVD) belum aktif pada mesin host.

Perbaikan dari audit kode dan migrasi:
- `supabase/config.toml`: Mengganti kunci konfigurasi usang `auth.email.enable_signup` menjadi `auth.email.enabled = true`.
- `supabase/migrations/001_schema.sql` & `003_rpc.sql`: Memperbaiki batasan `activities.label` agar mengizinkan string kosong `''` (`char_length(label) <= 120`, bukan `BETWEEN 1 AND 120`) sesuai PRD Bagian 6 (`label text <=120`), `models.dart`, dan `TimeFormScreen` (`Label kegiatan (opsional)`). Menambahkan constraint invarian status sesi `sessions_status_fields` pada `001_schema.sql` dan urutan deterministik `ORDER BY` pada seluruh agregasi `get_planner_snapshot()` di `003_rpc.sql`.
- `android/app/src/main/AndroidManifest.xml`: Menambahkan izin `<uses-permission android:name="android.permission.INTERNET"/>` serta menonaktifkan pencadangan otomatis (`android:allowBackup="false"`, `android:fullBackupContent="false"`) agar cache SQLite dan penyimpanan sesi tidak bocor ke backup cloud.
- `lib/data/planner_api.dart`: Memperkuat pemetaan error PostgreSQL/PostgREST/Auth/jaringan (`VALIDATION`, `STALE_REVISION`, `UNAUTHENTICATED`, `FORBIDDEN`, `TIMEOUT`, `OFFLINE`, `INVALID_RESPONSE`, `SERVER`) beserta validasi payload revisi dan pesan pengguna berbahasa Indonesia yang aman.
- `lib/state/auth_controller.dart` & `lib/data/auth_storage.dart`: Menyambungkan `SecureLocalStorage` ke `Supabase.initialize`, memeriksa kesehatan penyimpanan aman sebelum masuk/daftar/pulihkan sesi (tanpa fallback plaintext), mendukung konfirmasi email & kirim ulang konfirmasi, membersihkan state memori + cache SQLite saat `logout()`, tetap membersihkan sesi & cache lokal ketika `signOut()` gagal karena offline, serta menolak pergantian akun bila pembersihan cache lokal gagal.
- `lib/state/planner_controller.dart`, `lib/app/app.dart`, `lib/main.dart`: Memisahkan secara eksplisit Mode Demo vs Mode Backend (`isDemo` vs `isCloud`), memulai mode cloud dari snapshot kosong (bukan `demoSnapshot()`), mengikat setiap respons asinkron ke `_authEpoch` dan `_userId` agar respons terlambat dari Akun A tidak mencemari Akun B, memuat ulang snapshot server otomatis saat terjadi `TIMEOUT` atau `STALE_REVISION` tanpa mengirim ulang mutasi secara buta, memblokir mutasi dan penyusunan pratinjau ketika offline (`fromCache == true`), serta memulihkan snapshot secara otomatis saat koneksi kembali melalui `connectivity_plus`.
- Pengujian baru yang ditambahkan dan lulus:
  - `test/data/planner_api_test.dart` (pemetaan kode kesalahan RPC, validasi respons cacat, isolasi respons lintas akun, pemulihan timeout/revisi usang, penolakan mutasi saat offline).
  - `test/data/cache_test.dart` (isolasi cache SQLite per `user_id` di atas `sqflite_common_ffi`, fallback offline dengan `fetchedAt`, pembersihan cache saat logout, serta pemulihan otomatis ke snapshot segar).
  - `test/data/auth_storage_test.dart` (siklus `SecureLocalStorage`, pendaftaran dengan konfirmasi email, masuk, blokir saat gagal hapus cache, logout saat offline, dan penolakan masuk saat penyimpanan aman rusak).
  - `test/planner/schedule_test.dart` (uji batas kinerja penyusunan pratinjau 50 tugas melintasi 14 tanggal WIB selesai dalam `< 1000 ms`).
  - `integration_test/storage_test.dart` (uji integrasi perangkat untuk `SecureLocalStorage` dan `SqliteLocalCache`).


## UI/UX redesign - 10 November 2026 (Asia/Jakarta)

Arah Modern Productivity dipertahankan dan dipertajam menjadi planner editorial berorientasi tindakan, berdasarkan pencarian UI/UX Pro Max dan render UI terbaru. Ringkasan memprioritaskan sesi/progres, Tugas menjadi daftar datar dengan footer tambah, Waktu mendahulukan kapasitas bersih, agenda memakai jam sejajar/adaptif, pratinjau menjelaskan konsekuensi di footer, serta seluruh form/auth memakai tema dan kontrol bersama. Label progres diperpendek setelah terlihat terpotong pada teks besar. Tidak ada perubahan algoritma, backend, dependency atau data produksi dalam pekerjaan ini; perubahan pengguna yang sudah ada dipertahankan.

Verifikasi: 55 tes planner/UI/data lulus; 15 tes render lulus dengan screenshot sebelum/sesudah pada 360/412 dp dan skala 1.0/1.8, form lima varian, auth, kosong, terlambat/judul panjang, offline/loading dan keyboard; uji kontras dan target 48 dp lulus. Format 41 file 0 perubahan, analyze tanpa masalah, build APK debug berhasil. Aplikasi juga berjalan di Chrome. Belum ada perangkat Android untuk TalkBack/IME/gesture atau smoke test; backend nyata tidak diuji ulang. Bukti: docs/design/redesign-audit.md dan docs/design/redesign-review.html. Acuan visual final: docs/design/DESIGN.md.


## Studio Fokus - revisi visual menyeluruh, 10 November 2026

Pengguna menilai hasil pertama masih terlalu mirip dan mengizinkan arah visual baru tanpa referensi produk. Studio Fokus menggantikan Modern Productivity biru: ivory/pinus/lime, panel fokus, dock navigasi mengambang, lembar tugas, agenda berblok jam, pengantar formulir, auth/akun baru dan progres yang memprioritaskan input. Semua layar mengikuti DESIGN.md baru; aturan bisnis PRD, route, controller dan backend dipertahankan.

Hasil: 55 tes planner/UI/data lulus termasuk render screenshot 360/412 dp pada skala 1.0/1.8, kontras panel/CTA baru, keyboard, offline/loading, kosong, judul panjang, preview basi, form dan progres. flutter analyze tanpa masalah; format 41 file 0 perubahan; diff --check bersih. Chrome main berhasil berjalan. APK release berhasil (57.8 MB) dan disalin sebagai build/app/outputs/flutter-apk/WaktuTugas-StudioFokus.apk dengan hash terverifikasi. Build memakai signing debug existing untuk demo lokal.

Catatan build: --release --no-pub awalnya memakai registrant integration_test debug yang basi. Flutter build apk --release tanpa --no-pub menyegarkan registrasi sesuai mode release dan berhasil; tidak mengubah konfigurasi atau dependency. Bukti: docs/design/studio-fokus-review.html (17 pasangan dan 13 state), docs/design/studio-fokus-audit.md. Android fisik, TalkBack, IME Android dan backend hidup belum diverifikasi.
