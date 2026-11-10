# Hasil Pengujian & Status Verifikasi WaktuTugas

**Proyek:** WaktuTugas (Ahmad Turmudi — NIM 60324069)  
**Acuan Spesifikasi:** `PRD_WaktuTugas_Ahmad_Turmudi_60324069.md` (Versi 1.2)  
**Tanggal Pencatatan:** 9 November 2026 (Asia/Jakarta)

> **Prinsip Pelaporan:** Hasil pengujian dibedakan secara eksplisit antara **(1) Pengujian Lokal (Unit, Widget, & Adapter/Fake)**, **(2) Backend PostgreSQL/Supabase Nyata**, dan **(3) Perangkat/Emulator Android**. Kasus uji yang belum dieksekusi pada runtime targetnya tidak diklaim lulus pada target tersebut.

---

## 1. Ringkasan Eksekusi per Lingkungan

| Lingkungan Uji | Perintah / Cakupan | Status Aktual | Bukti / Kendala |
| :--- | :--- | :--- | :--- |
| **Analisis Statis & Format** | `flutter analyze --no-pub`<br>`dart format --output=none --set-exit-if-changed lib test integration_test` | **Lulus** | 0 masalah statis; 0 file perlu diformat ulang |
| **Unit, Widget & Data Adapter Test (Lokal)** | `flutter test --no-pub test/planner test/ui test/data` | **Lulus (38 test)** | Mencakup mesin jadwal, UI responsif, formulir, progres, adapter RPC `PlannerApi`, `SecureLocalStorage`, dan `LocalCache` SQLite |
| **Database & pgTAP SQL Test (Backend Nyata)** | `supabase test db` (`supabase/tests/authorization.sql`, `transactions.sql`) | **Terblokir prasyarat** | File uji pgTAP siap, tetapi Docker Engine (`dockerDesktopLinuxEngine`) tidak aktif pada mesin ini (`ECONNREFUSED` ke `127.0.0.1:54322`) |
| **Uji RPC Paralel 2 Akun (Backend Nyata)** | `flutter test test/backend/planner_rpc_test.dart` | **Terblokir prasyarat** | Membutuhkan stack Supabase lokal aktif dan variabel environment 2 akun uji (`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `WAKTUTUGAS_TEST_A_*`, `WAKTUTUGAS_TEST_B_*`) |
| **Build Android Release APK** | `flutter build apk --release` | **Lulus Kompilasi** | Artefak `build/app/outputs/flutter-apk/app-release.apk` berhasil dibangun |
| **Integration Test Perangkat Android** | `flutter test integration_test/app_flow_test.dart`<br>`flutter test integration_test/storage_test.dart` | **Belum dijalankan di perangkat** | `flutter devices` belum mendeteksi perangkat Android fisik atau AVD/emulator aktif |

---

## 2. Matriks Acceptance Criteria (AC01–AC18)

| ID | Kondisi Uji (PRD Bagian 10) | Verifikasi Lokal (Unit / Widget / Adapter) | Verifikasi Backend PostgreSQL Nyata | Verifikasi Perangkat Android |
| :--- | :--- | :--- | :--- | :--- |
| **AC01** | Akun B dan tanpa sesi mengakses ID milik A | **Lulus (Adapter/Fake):** `test/data/planner_api_test.dart`, `test/data/cache_test.dart` | **Belum dijalankan** (tercakup di `supabase/tests/authorization.sql` & `test/backend/planner_rpc_test.dart`, menunggu Docker) | Menunggu perangkat + backend |
| **AC02** | Nama kosong, menit negatif, rentang terbalik ditolak; revisi tetap | **Lulus:** `test/planner/models_test.dart`, `test/ui/forms_test.dart`, `test/data/planner_api_test.dart` | **Belum dijalankan** (tercakup di `supabase/tests/transactions.sql`, menunggu Docker) | Menunggu perangkat |
| **AC03** | Rentang 19–22 dan 21–23 menghasilkan gabungan 240 menit | **Lulus:** `test/planner/intervals_test.dart` | N/A (Mesin Dart murni + dicek di `transactions.sql`) | Menunggu perangkat |
| **AC04** | AC03 dikurangi kegiatan 20–21 menghasilkan 180 menit & 2 interval | **Lulus:** `test/planner/intervals_test.dart` | N/A (Mesin Dart murni + dicek di `transactions.sql`) | Menunggu perangkat |
| **AC05** | Sesi berakhir 20.00 diikuti mulai 20.00 diterima; irisan ditolak | **Lulus:** `test/planner/schedule_test.dart` | **Belum dijalankan** (tercakup di `supabase/tests/transactions.sql`, menunggu Docker) | Menunggu perangkat |
| **AC06** | Tenggat 20.30 di rentang 20–22 mengalokasikan maksimum sampai 20.30 | **Lulus:** `test/planner/schedule_test.dart` | **Belum dijalankan** (tercakup di `supabase/tests/transactions.sql`, menunggu Docker) | Menunggu perangkat |
| **AC07** | Fixture 540 kebutuhan & 420 kapasitas menyisakan T03 kurang 120 menit | **Lulus:** `test/planner/schedule_test.dart`, `test/ui/forms_test.dart` | N/A (Mesin Dart murni) | Menunggu perangkat (`integration_test/app_flow_test.dart`) |
| **AC08** | Tambah 120 menit tersedia sebelum tenggat menghilangkan kekurangan | **Lulus:** `test/planner/schedule_test.dart` | N/A (Mesin Dart murni) | Menunggu perangkat |
| **AC09** | Tenggat lewat atau setelah jendela menghasilkan `past_deadline` / `outside_horizon` | **Lulus:** `test/planner/schedule_test.dart` | N/A (Mesin Dart murni) | Menunggu perangkat |
| **AC10** | Input, `now`, dan `revision` sama menghasilkan kandidat deterministik | **Lulus:** `test/planner/schedule_test.dart` (+ uji performa 50 tugas $\le 1$ detik) | N/A (Mesin Dart murni) | Menunggu perangkat |
| **AC11** | Tutup `missed` tidak mengurangi sisa tugas | **Lulus:** `test/ui/progress_test.dart` | **Belum dijalankan** (tercakup di `supabase/tests/transactions.sql`, menunggu Docker) | Menunggu perangkat |
| **AC12** | Tutup `completed` dengan `remaining_after=90`; penutupan ulang ditolak | **Lulus:** `test/ui/progress_test.dart`, `test/data/planner_api_test.dart` | **Belum dijalankan** (tercakup di `supabase/tests/transactions.sql` & `test/backend/planner_rpc_test.dart`, menunggu Docker) | Menunggu perangkat |
| **AC13** | `planned` sudah mulai dan belum ditutup memblokir pratinjau/konfirmasi | **Lulus:** `test/planner/schedule_test.dart`, `test/ui/progress_test.dart` | **Belum dijalankan** (tercakup di `supabase/tests/transactions.sql`, menunggu Docker) | Menunggu perangkat |
| **AC14** | Revisi berubah setelah pratinjau membatalkan konfirmasi tanpa merusak jadwal lama | **Lulus:** `test/ui/progress_test.dart`, `test/data/planner_api_test.dart` | **Belum dijalankan** (tercakup di `supabase/tests/transactions.sql` & `test/backend/planner_rpc_test.dart`, menunggu Docker) | Menunggu perangkat |
| **AC15** | Gagal di tengah penyimpanan atau dua konfirmasi serentak bersifat atomik | **Lulus (Simulasi Klien):** `test/ui/progress_test.dart`, `test/data/planner_api_test.dart` | **Belum dijalankan** (tercakup di `supabase/tests/transactions.sql` & `test/backend/planner_rpc_test.dart`, menunggu Docker) | Menunggu perangkat + backend |
| **AC16** | Kandidat memuat tugas akun lain atau waktu terlarang ditolak seluruhnya | **Lulus (Simulasi Klien):** `test/data/planner_api_test.dart` | **Belum dijalankan** (tercakup di `supabase/tests/transactions.sql` & `test/backend/planner_rpc_test.dart`, menunggu Docker) | Menunggu perangkat + backend |
| **AC17** | Offline dan pergantian akun: cache bertanda waktu, tulis nonaktif, data A tidak bocor ke B | **Lulus:** `test/data/cache_test.dart`, `test/data/auth_storage_test.dart`, `test/ui/figma_screens_test.dart` | N/A | Menunggu perangkat (`integration_test/storage_test.dart`) |
| **AC18** | Hapus tugas dibatalkan tidak mengubah data; disetujui menghapus tugas & sesi terkait | **Lulus:** `test/ui/forms_test.dart`, `test/ui/progress_test.dart` | **Belum dijalankan** (tercakup di `supabase/tests/transactions.sql`, menunggu Docker) | Menunggu perangkat |

---

## 3. Pengukuran Performa Mesin Penjadwalan

* **Target Rancangan (PRD Bagian 9.3):** `buildPreview` $\le 1000\text{ ms}$ untuk 50 tugas dan jendela 14 tanggal kalender, diukur terpisah dari latensi jaringan.
* **Hasil Uji Lokal (`test/planner/schedule_test.dart`):** Eksekusi `buildPreview` untuk 50 tugas aktif, 7 pola rentang mingguan, dan 5 kegiatan rutin pada jendela 14 tanggal selesai dalam **$< 50\text{ ms}$** pada mesin pengembangan (lulus batas $\le 1000\text{ ms}$). Pengukuran pada perangkat fisik Android masih harus dicatat saat perangkat tersedia.
