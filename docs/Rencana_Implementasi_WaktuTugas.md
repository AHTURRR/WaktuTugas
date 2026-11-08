# WaktuTugas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Membuat MVP Android yang mengalokasikan tugas ke waktu tersedia, menyimpan jadwal dengan aman, dan mencatat progres.

**Architecture:** Flutter menampilkan empat tab dan menghitung pratinjau memakai fungsi Dart murni. ChangeNotifier mengelola sesi/snapshot. Supabase Auth dan RPC menyimpan perubahan secara transaksional dengan revision per pengguna; SQLite hanya cache baca.

**Tech Stack:** Flutter stable + Dart null safety; Material 3; go_router; ChangeNotifier/ListenableBuilder/setState; timezone dan intl; supabase_flutter; flutter_secure_storage dengan LocalStorage khusus; sqflite; connectivity_plus; flutter_test/integration_test/flutter_lints; Supabase CLI dan pgTAP; flutter pub; Flutter CLI Android APK.

**Spec:** PRD_WaktuTugas_Ahmad_Turmudi_60324069.md versi 1.2, terutama Bagian 1.4-1.5. Pemilik: Ahmad Turmudi, NIM 60324069, individu. Revisi 8 November 2026.

## Global Constraints

- Zona tampilan/perluasan pola: Asia/Jakarta; instan UTC; durasi bilangan bulat menit.
- Jendela tetap 14 tanggal kalender; interval setengah terbuka [mulai, selesai).
- Urutan tugas: deadline_at, created_at, id. Sisa nol tidak dialokasikan.
- Waktu manual digabung lalu dikurangi kegiatan; tidak ada penulisan offline.
- Semua mutasi mengambil pemilik dari server, memeriksa expected_revision, dan memakai transaksi.
- Model Dart camelCase; JSON/RPC snake_case sesuai PRD. Jangan mengubah kontrak backend karena pergantian UI.
- Tidak ada secret/service_role key di aplikasi, fixture, tangkapan layar, atau repository.
- pubspec.lock disimpan. Versi Flutter/Dart dan Android SDK dicatat setelah setup; belum ada kombinasi yang dinyatakan teruji.

## Review Focus

- Tengah malam dan perangkat di luar WIB: Task 2 memeriksa tanggal, tenggat, dan round-trip JSON.
- Progres terlewat, penutupan dua kali, dan estimasi meningkat: Task 3 dan 4.
- Konfirmasi serentak serta timeout yang tidak membatalkan proses server: Task 4 dan 5.
- ID akun lain dan fungsi SECURITY DEFINER: Task 4.
- Cache akun lama, logout offline, kegagalan secure storage, serta plugin Android: Task 5 dan 6.

## Task 1 Kerangka aplikasi dan model bersama

**Files:** lib/main.dart; lib/app/{app,router,theme}.dart; lib/features/*/*_screen.dart sesuai PRD Bagian 11; lib/state/{auth_controller,planner_controller}.dart; lib/planner/{models,fixtures}.dart; pubspec.yaml; pubspec.lock; analysis_options.yaml; test/planner/models_test.dart; test/ui/navigation_test.dart; README.md.

**Interfaces:** Model Task, TimeWindow, Activity, PlannerSession (agar tidak bentrok dengan Session SDK), PlannerSnapshot, Interval, SchedulePreview, ProposedSession, Unallocated, UnallocatedReason sesuai PRD. PlannerSnapshot memiliki int revision dan daftar tasks/timeWindows/activities/sessions. Setiap model JSON memiliki factory fromJson(Map<String, dynamic> json) dan Map<String, dynamic> toJson(). AuthController dan PlannerController extends ChangeNotifier; UI menerima instance melalui constructor.

- [ ] Buat proyek flutter create --platforms=android waktu_tugas; perintah selanjutnya dijalankan dari root aplikasi. Pasang dependensi Bagian 1.5, aktifkan Material 3, locale id_ID, empat tab go_router, dan root route detail.
- [ ] Tulis models_round_trip untuk camelCase/snake_case, UTC, enum reason, nilai null opsional, dan input JSON tidak valid. Jalankan flutter test test/planner/models_test.dart; pastikan gagal sebelum implementasi.
- [ ] Definisikan model immutable, validasi parsing, dan fixture now=2026-11-09T11:00:00Z yang setara 18.00 WIB. Inisialisasi timezone sebelum app dijalankan.
- [ ] Tulis navigation_test untuk empat tab, detail/back, login redirect, dan pratinjau tanpa kandidat; implementasikan router dan controller minimal dengan fixture.
- [ ] Jalankan flutter doctor -v, flutter analyze, flutter test test/planner test/ui, serta dart format --output=none --set-exit-if-changed lib test. Catat versi aktual dan commit kerangka.

## Task 2 Mesin waktu dan pratinjau

**Files:** lib/planner/intervals.dart; lib/planner/schedule.dart; test/planner/intervals_test.dart; test/planner/schedule_test.dart.

**Interfaces:** List<Interval> mergeIntervals(List<Interval> intervals); List<Interval> subtractIntervals(List<Interval> allowed, List<Interval> busy); List<Interval> expandWindows(PlannerSnapshot input, DateTime now); SchedulePreview buildPreview(PlannerSnapshot snapshot, DateTime now). Semua instan model UTC; konversi kalender memakai lokasi Asia/Jakarta.

- [ ] Tulis merge_overlap: 19-22 dan 21-23 menghasilkan 240 menit; subtract_busy: penutupan 20-21 menghasilkan 180 menit. Jalankan flutter test test/planner; pastikan gagal sebelum fungsi dibuat.
- [ ] Implementasikan merge/subtract tanpa UI, jaringan, atau pembacaan jam global.
- [ ] Tulis deadline_mid_slot berakhir 20.30; adjacent_intervals tidak overlap; ceil_now membulatkan detik ke menit berikutnya; wib_midnight berakhir pada 2026-11-22T17:00:00Z (23 November 00.00 WIB).
- [ ] Tulis demo_shortfall menghasilkan T03=120, added_capacity menghasilkan nol, stable_order deterministik, past_deadline/outside_horizon tepat, completed_overlap tidak dialokasikan ulang, serta device_non_wib tetap menghasilkan jadwal WIB yang sama.
- [ ] Implementasikan ekspansi pola dan alokasi sesuai PRD. Jalankan flutter test test/planner dan flutter analyze sampai lulus; commit mesin jadwal.

## Task 3 Formulir dan progres dengan fixture

**Files:** lib/features/tasks/{tasks_screen,task_form_screen}.dart; lib/features/time/time_screen.dart; lib/features/schedule/{schedule_screen,preview_screen,session_screen}.dart; lib/state/planner_controller.dart; test/ui/forms_test.dart; test/ui/progress_test.dart.

**Interfaces:** PlannerController mengonsumsi PlannerSnapshot dan buildPreview; snapshot, preview, isPending, error dapat diamati UI. Formulir memakai Form/TextFormField, showDatePicker/showTimePicker; nilai waktu diperlakukan sebagai WIB. Pada tahap ini perubahan hanya fixture lokal dan ditandai demikian.

- [ ] Tulis widget test nama kosong, durasi negatif, rentang terbalik, serta weekday/date harus tepat satu. Jalankan flutter test test/ui; pastikan gagal sebelum formulir dihubungkan.
- [ ] Implementasikan formulir tugas/waktu/kegiatan, pratinjau, kekurangan, dan konfirmasi lokal. Tombol pending terkunci; input tetap tersedia ketika gagal; dispose TextEditingController.
- [ ] Tulis missed_preserves_remaining, completed_remaining_90, increased_estimate_allowed, double_close_rejected, dan started_planned_blocks_preview; implementasikan perubahan state sesuai PRD.
- [ ] Uji pratinjau ulang mempertahankan completed/missed dan membatalkan planned mendatang saat konfirmasi; uji hapus tugas batal/setuju (AC18).
- [ ] Jalankan flutter test test/ui test/planner dan flutter analyze; rekam demo fixture dan commit.

## Task 4 Database Auth RLS dan RPC

**Files:** supabase/config.toml; supabase/migrations/001_schema.sql, 002_policies.sql, 003_rpc.sql; supabase/tests/{authorization,transactions}.sql; test/backend/planner_rpc_test.dart.

**Interfaces:** Tabel PRD Bagian 6; get_planner_snapshot dan delapan mutasi Bagian 7. Semua mutasi mengunci planner_state sebelum tabel bisnis; gagal tidak mengubah revision. Nama argumen RPC mengikuti PRD persis. Dart SupabaseClient dua instance memakai akun uji berbeda untuk uji isolasi; uji balapan memakai dua instance akun yang sama, bukan mengganti sesi satu klien.

- [ ] Siapkan Supabase CLI lokal dan container runtime; supabase start lalu supabase db reset pada lingkungan uji saja. Kredensial uji diberikan lewat environment/--dart-define, tidak ditulis dalam fixture.
- [ ] Tulis pgTAP untuk dua akun, anon, spoofed user/ID, foreign key pemilik, dan grants tulis tabel. Jalankan supabase test db; pastikan kasus gagal sebelum skema lengkap.
- [ ] Buat skema, constraint, indeks, Auth, RLS, grants minimum, snapshot konsisten, dan mutasi. Batasi SECURITY DEFINER sesuai PRD; server memvalidasi seluruh kepemilikan serta jadwal.
- [ ] Tulis test backend confirm_stale menjaga jadwal lama; fail_mid_transaction rollback; double_confirm_same_revision serentak melalui Future.wait menghasilkan tepat satu sukses. Uji dua penutupan progres tidak mengurangi sisa dua kali.
- [ ] Uji kandidat tugas akun lain, waktu terlarang, sesi masa lalu, kelebihan alokasi, serta overlap ditolak; ikuti AC01/02/11-16/18.
- [ ] Jalankan supabase test db dan flutter test test/backend dengan konfigurasi backend lokal sampai lulus. Kegagalan koneksi harus gagal jelas, bukan diam-diam skip; simpan log tanpa token dan commit.

## Task 5 Integrasi layanan dan cache

**Files:** lib/data/{supabase_client,auth_storage,planner_api,cache}.dart; lib/state/{auth_controller,planner_controller}.dart; test/data/{auth_storage,planner_api,cache}_test.dart; integration_test/storage_test.dart; hubungkan layar Task 3.

**Interfaces:** PlannerApi.fetchSnapshot(): Future<PlannerSnapshot>; confirmSchedule(SchedulePreview preview): Future<int>; recordProgress(String sessionId, SessionStatus status, int? remainingAfter, int expectedRevision): Future<int>. int hasil mutasi adalah revision baru; remainingAfter nonnegatif untuk completed, null untuk missed. Mutasi CRUD memetakan fungsi Bagian 7 tanpa user_id dari klien. Cache.readCachedSnapshot(String userId): Future<CachedSnapshot?>; writeCachedSnapshot(String userId, PlannerSnapshot snapshot, DateTime fetchedAt): Future<void>; clearCache(String userId): Future<void>. CachedSnapshot menyimpan snapshot dan fetchedAt UTC. AuthStorage extends LocalStorage mengikuti SDK terkunci dan PRD Bagian 9.2.

- [ ] Tulis timeout_unknown memuat ulang snapshot tanpa retry mutasi otomatis; stale_revision memerlukan preview baru. Future.timeout tidak membatalkan transaksi server. Uji pemetaan error dan respons salah bentuk sebelum implementasi API.
- [ ] Implementasikan supabase_flutter, pemetaan JSON/error, dan pending state. Setelah mutasi ambil snapshot server; jangan menampilkan sukses saat status transaksi masih tidak diketahui.
- [ ] Implementasikan adapter LocalStorage dengan flutter_secure_storage dan injeksi FlutterAuthClientOptions.localStorage. Tulis persist/restore/refresh/logout/storage_failure tanpa fallback plaintext; uji plugin nyata pada Android.
- [ ] Tulis cache_wrong_user, logout_offline, corrupted_cache, serta perubahan akun ketika request lama masih berjalan. Respons A yang terlambat tidak boleh masuk ke state/cache B; ikat hasil request ke identitas sesi saat dimulai.
- [ ] Implementasikan sqflite dengan placeholder SQL dan cache per user_id; token tidak disimpan di cache. UI menampilkan fetched_at dan menonaktifkan tulis/pratinjau offline. connectivity_plus hanya sinyal; tangani kegagalan request secara terpisah.
- [ ] Pada logout hapus sesi lokal, cache, snapshot/preview, dan langganan akun lama sebelum akun baru tampil. Jika pembersihan gagal, jangan membuka data akun berikutnya; tampilkan kegagalan untuk dicoba ulang.
- [ ] Jalankan flutter test test/planner test/ui test/data, flutter analyze, supabase test db, flutter test test/backend, dan flutter test integration_test/storage_test.dart -d <device-id>. Untuk Android emulator, endpoint backend lokal memakai alamat host yang dapat dijangkau emulator; HTTP lokal hanya di konfigurasi debug.
- [ ] Coba alur login-tugas-waktu-pratinjau-konfirmasi-progres pada Android; simpan bukti dan commit integrasi.

## Task 6 Release candidate dan bukti mata kuliah

**Files:** README.md; docs/API.md; docs/TEST_RESULTS.md; integration_test/app_flow_test.dart; android/app/src/main/AndroidManifest.xml; android/app/build.gradle.kts atau build.gradle sesuai template; .gitignore; contoh konfigurasi tanpa kredensial nyata.

**Interfaces:** Tidak menambah fitur; merilis perilaku Task 1-5. Android minimum SDK dan Java/Gradle mengikuti persyaratan plugin terpasang; gunakan konfigurasi template Flutter yang kompatibel.

- [ ] Jalankan AC01-AC18 dan tulis hasil aktual, perangkat, versi, tanggal; jangan menandai kasus yang belum dijalankan sebagai lulus.
- [ ] Uji font besar, pembaca layar, keyboard, kembali, data kosong, restart, putus koneksi, logout, pergantian akun, dan zona perangkat di luar WIB.
- [ ] Ukur buildPreview untuk 50 tugas/14 tanggal, terpisah dari latensi jaringan; catat target <=1 detik pada perangkat uji.
- [ ] Jalankan flutter analyze, dart format --output=none --set-exit-if-changed lib test integration_test, unit/widget test, SQL/RPC test, dan flutter test integration_test/app_flow_test.dart -d <device-id>.
- [ ] Pastikan INTERNET pada manifest release, URL HTTPS Supabase, backup secure storage sesuai petunjuk plugin, serta konfigurasi signing release. Abaikan key.properties/keystore dari Git; aplikasi hanya membawa publishable key.
- [ ] Jalankan flutter build apk --release --dart-define=SUPABASE_URL=<url-proyek> --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>. APK universal berada di build/app/outputs/flutter-apk/app-release.apk; pasang dan ulangi smoke test sampai progres.
- [ ] Dokumentasikan setup Flutter/Android, dependensi terkunci, migrasi, backend lokal, signing, konfigurasi publik, dan demo fixture. Commit release candidate.

## Handoff

Rencana belum dieksekusi. Mulai Task 1 saat implementasi diminta; gunakan PRD 1.2 sebagai sumber aturan. Pergantian Flutter sudah dipilih pemilik proyek; kesesuaian dengan penilaian dosen, deadline, proyek Supabase, dan perangkat uji masih perlu ditetapkan. Jangan membuat layanan cloud atau menggunakan kredensial di luar proyek yang ditentukan pengguna. Belum ada instalasi Flutter, pengujian aplikasi, atau build APK yang dinyatakan berhasil.
