# WaktuTugas

Aplikasi Android berbasis Flutter + Supabase untuk membantu mahasiswa mengalokasikan sisa pengerjaan tugas ke rentang waktu yang benar-benar diizinkan sebelum tenggat, melihat pratinjau jadwal 14 hari (WIB), mengonfirmasi jadwal secara atomik, serta mencatat progres belajar.

- **Pemilik Proyek:** Ahmad Turmudi (NIM 60324069)
- **Mata Kuliah:** Pemrograman Berbasis Platform (INF2528) — UIN K.H. Abdurrahman Wahid Pekalongan
- **Spesifikasi:** [PRD_WaktuTugas_Ahmad_Turmudi_60324069.md](PRD_WaktuTugas_Ahmad_Turmudi_60324069.md) (Versi 1.2)

---

## 1. Lingkungan & Toolchain yang Tercatat

* **Flutter:** `3.44.8` (channel `stable`)
* **Dart:** `3.12.2` (dibundel bersama Flutter)
* **Android SDK:** `36.0.0` (platform `android-36.1`, build-tools `36.0.0`, `minSdkVersion` mengikuti konfigurasi Flutter `24`)
* **Java / JDK:** Android Studio JBR `25.0.3` (kompilasi Gradle ditargetkan ke Java `17`)
* **Supabase CLI:** `3.0.0`

---

## 2. Mode Operasi: Demo Lokal vs Backend Supabase

Aplikasi membedakan secara eksplisit antara **Mode Demo Lokal** dan **Mode Backend Daring**:

1. **Mode Demo Lokal (Default tanpa `--dart-define`):**
   * Aktif apabila `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY` tidak diberikan saat menjalankan atau mem-build aplikasi.
   * Menampilkan penanda eksplisit **`Demo lokal`** dengan dataset sintetis PRD Bagian 4.4 (`9 November 2026 pukul 18.00 WIB`, tugas `T01`, `T02`, `T03`).
   * Seluruh perubahan hanya berada di memori selama aplikasi terbuka dan direset saat keluar atau aplikasi dimulai ulang.
2. **Mode Backend Daring (Dengan `--dart-define`):**
   * Aktif apabila `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY` diberikan melalui `--dart-define`.
   * Mengaktifkan Supabase Auth (masuk, daftar, konfirmasi email, keluar akun), penyimpanan sesi terenkripsi (`flutter_secure_storage` melalui `SecureLocalStorage`), pembacaan snapshot & mutasi RPC transaksional (`PlannerApi`), serta cache baca luring SQLite per `user_id` (`LocalCache`).
   * **Keamanan Kredensial:** Hanya *publishable / anon key* yang boleh dikirim melalui `--dart-define`. Jangan pernah menaruh `service_role` key atau secret database di aplikasi, repositori, maupun log.

---

## 3. Struktur Database & Migrasi Supabase

Seluruh definisi database berada pada folder `supabase/migrations/`:

1. [`supabase/migrations/001_schema.sql`](supabase/migrations/001_schema.sql):
   * Lima tabel sesuai PRD Bagian 6: `planner_state`, `tasks`, `time_windows`, `activities`, dan `sessions`.
   * Constraint integritas durasi positif, batas menit harian (`0..1439` dan `1..1440`), target eksklusif `weekday` vs `date`, kelipatan menit penuh pada sesi, kesesuaian field status sesi (`completed`/`missed`/`planned`/`cancelled`), foreign key gabungan `(task_id, user_id)` ke `tasks(id, user_id) ON DELETE CASCADE`, serta indeks per pengguna.
2. [`supabase/migrations/002_policies.sql`](supabase/migrations/002_policies.sql):
   * Mengaktifkan Row Level Security (`ENABLE ROW LEVEL SECURITY`) pada kelima tabel.
   * Kebijakan `SELECT` khusus `authenticated` dengan filter `auth.uid() = user_id`.
   * Mencabut seluruh izin tulis langsung (`INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES`, `TRIGGER`) dari `PUBLIC`, `anon`, dan `authenticated` agar seluruh mutasi wajib melewati RPC ber-revisi.
3. [`supabase/migrations/003_rpc.sql`](supabase/migrations/003_rpc.sql):
   * Fungsi `SECURITY DEFINER` dengan `SET search_path = ''` dan kualifikasi skema eksplisit (`public.*`).
   * `get_planner_snapshot()` serta 8 mutator atomik: `save_task`, `delete_task`, `save_time_window`, `delete_time_window`, `save_activity`, `delete_activity`, `record_progress`, dan `confirm_schedule`.
   * Setiap mutator memverifikasi `auth.uid()`, mengunci baris `planner_state` pengguna (`FOR UPDATE`), memvalidasi `expected_revision` / `input_revision` (`STALE_REVISION` `P0002`), memvalidasi seluruh invariant bisnis di server, dan menaikkan `revision + 1` dalam satu transaksi.

Detail kontrak RPC dan kode error didokumentasikan di [`docs/API.md`](docs/API.md).

---

## 4. Cara Menjalankan

### 4.1 Pemeriksaan Kualitas Kode & Pengujian Lokal (Tanpa Docker / Perangkat)
```powershell
flutter pub get
flutter analyze --no-pub
dart format --output=none --set-exit-if-changed lib test integration_test
flutter test --no-pub test/planner test/ui test/data
```

### 4.2 Menjalankan Backend Supabase Lokal & Pengujian Database (Membutuhkan Docker Desktop Aktif)
Pastikan Docker Desktop sudah berjalan (`docker info`), lalu jalankan dari root repositori:
```powershell
$env:SUPABASE_TELEMETRY_DISABLED='1'
supabase start
supabase test db
```
Untuk menjalankan pengujian konkurensi dan isolasi dua klien Dart terhadap Supabase lokal (`test/backend/planner_rpc_test.dart`), siapkan dua akun uji kosong pada instance lokal lalu jalankan:
```powershell
$env:SUPABASE_URL='http://127.0.0.1:54321'
$env:SUPABASE_PUBLISHABLE_KEY='<anon-key-lokal-dari-supabase-status>'
$env:WAKTUTUGAS_TEST_A_EMAIL='test-a@example.com'
$env:WAKTUTUGAS_TEST_A_PASSWORD='<password-uji-a>'
$env:WAKTUTUGAS_TEST_B_EMAIL='test-b@example.com'
$env:WAKTUTUGAS_TEST_B_PASSWORD='<password-uji-b>'
flutter test --no-pub test/backend/planner_rpc_test.dart
```

### 4.3 Menjalankan Aplikasi & Build Android
Menjalankan dalam mode demo lokal:
```powershell
flutter run -d <id-perangkat>
```
Menjalankan atau mem-build APK release dengan backend Supabase:

APK release menggunakan ID aplikasi `com.ahmadturmudi.waktutugas`. Siapkan
`android/key.properties` dengan `storeFile`, `storePassword`, `keyAlias`, dan
`keyPassword`. Path relatif `storeFile` dihitung dari direktori `android/`.
Simpan keystore dan kredensial secara privat, serta gunakan kunci yang sama untuk
menandatangani pembaruan APK.

```powershell
flutter run -d <id-perangkat> `
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<supabase-publishable-key>

flutter build apk --release `
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<supabase-publishable-key>
```
Menjalankan integration test pada perangkat/emulator Android:
```powershell
flutter test integration_test/storage_test.dart -d <id-perangkat-android>
flutter test integration_test/app_flow_test.dart -d <id-perangkat-android>
```

---

## 5. Status Pengujian & Pekerjaan yang Masih Tertunda

Catatan lengkap progres dan matriks penerimaan (`AC01–AC18`) tersedia di:
* [`docs/PROGRESS.md`](docs/PROGRESS.md)
* [`docs/TEST_RESULTS.md`](docs/TEST_RESULTS.md)

## 6. Pemeriksaan rilis dalam satu perintah

Dari root repositori, jalankan di PowerShell Windows.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\release.ps1
```

Perintah menjalankan analisis, pemeriksaan format, dan tes Flutter. Jika Docker
aktif, skrip menyalakan Supabase lokal dan membuat dua akun uji baru untuk uji
RPC di database lokal. Gunakan `-Device <id>` dari `flutter devices` untuk
menjalankan tes Android dan memasang APK yang tanda tangannya telah diperiksa.
Build debug memakai paket `.debug`. Skrip menonaktifkan penghapusan otomatis
oleh Flutter setelah pengujian.
Siapkan `android/key.properties` dan keystore seperti pada bagian 4.3.

Untuk kandidat daring, siapkan akses Supabase CLI lalu isi URL proyek dan
publishable key dalam satu perintah.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\release.ps1 -Device '<id-perangkat>' -SupabaseUrl 'https://<project-ref>.supabase.co' -PublishableKey 'sb_publishable_...'
```

Skrip juga membaca `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY` dari sesi
PowerShell. Tambahkan `-ApplyMigrations` untuk menerapkan migrasi ke proyek
tujuan setelah pratinjau dan pemeriksaan lulus. Tanpa konfigurasi Supabase,
skrip membangun APK demo.

APK dan `hasil.md` tersimpan per eksekusi di `build/release/`. Kode keluar
`1` menandakan pemeriksaan otomatis gagal atau masih tertunda. Lanjutkan dengan
uji alur Supabase pada APK final sebelum membuat tag atau membagikannya.

## Pengingat WhatsApp

Untuk menyiapkan nomor pengirim OpenWA, secrets Supabase, migrasi 004, Cron, dan tes mock, ikuti [panduan pengingat WhatsApp](docs/WHATSAPP_REMINDERS.md).
#   W a k t u T u g a s A p p  
 