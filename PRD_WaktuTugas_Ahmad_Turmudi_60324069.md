# PRD dan Cetak Biru Pengembangan WaktuTugas

**Pemilik proyek:** Ahmad Turmudi  
**NIM:** 60324069  
**Jenis proyek:** Individu  
**Mata kuliah:** Pemrograman Berbasis Platform, INF2528  
**Program studi:** Informatika, Fakultas Sains dan Teknologi  
**Perguruan tinggi:** UIN K.H. Abdurrahman Wahid Pekalongan  
**Versi:** 1.2 — 8 November 2026  
**Status:** Spesifikasi untuk implementasi MVP; aplikasi dan pengujian live belum dilaksanakan.

## 1 Ringkasan produk dan tujuan

WaktuTugas membantu mahasiswa mengalokasikan sisa pengerjaan tugas ke waktu yang benar-benar diizinkan sebelum tenggat. Pengguna dapat menentukan waktu luang secara manual dan menggabungkannya dengan pengurangan jadwal kuliah, kegiatan rutin, serta pengecualian per tanggal. Aplikasi menampilkan pratinjau, pekerjaan yang belum tertampung, dan jadwal yang dapat disusun ulang setelah progres berubah.

Hasil utama adalah satu alur utuh: masuk akun, mencatat tugas dan waktu, memeriksa pratinjau, mengonfirmasi jadwal, lalu memperbarui progres. Sasaran rilis adalah aplikasi Android untuk demonstrasi mata kuliah. Keberhasilan teknis diukur melalui acceptance criteria; peningkatan nilai atau produktivitas belum diklaim.

### 1.1 Pengguna dan masalah

Persona rancangan adalah mahasiswa pengguna ponsel Android yang mengelola beberapa tugas pribadi. Dugaan masalahnya: daftar tenggat tidak sekaligus menunjukkan kapasitas waktu, kegiatan berubah, dan satu sesi yang terlewat mengharuskan pengguna merencanakan ulang. Persona ini perlu divalidasi; belum ada hasil wawancara yang disajikan sebagai fakta.

### 1.2 Cakupan yang dikunci

| Wajib untuk MVP | Di luar MVP |
| --- | --- |
| Akun pribadi, Supabase Auth, dan pembatasan data per pengguna | Akun dosen, kemitraan, dan tugas kelompok |
| CRUD tugas, rentang pengerjaan mingguan atau per tanggal | Impor sistem akademik dan Google Calendar |
| Kegiatan rutin, kegiatan sekali, dan penutupan waktu | AI penaksir durasi dan optimasi jadwal global |
| Pratinjau, kekurangan waktu, konfirmasi, dan progres | Pemindahan sesi dengan drag and drop |
| Penjadwalan ulang dengan riwayat sesi tetap | Push notification dan kalender bersama |
| Cache baca SQLite dan build Android | Penulisan offline dan penggabungan konflik lintas perangkat |

### 1.3 Keputusan implementasi

Stack proyek ditetapkan pada Bagian 1.4, termasuk UI, state, penyimpanan sesi, pengujian, dan build. Jadwal dihitung dengan fungsi Dart murni yang terpisah dari UI. Supabase menyediakan database, autentikasi, dan REST/RPC; tidak diperlukan server CRUD tambahan. Kebijakan kompatibilitas versi dijelaskan pada Bagian 1.5.

<!-- pagebreak -->

## 1 Stack teknologi yang ditetapkan

### 1.4 Pilihan teknologi dan tanggung jawabnya

| Bagian | Teknologi yang digunakan | Alasan untuk proyek ini |
| --- | --- | --- |
| Aplikasi Android | Flutter stable dan Dart dengan sound null safety | Satu basis kode; Android menjadi target penerimaan MVP |
| Navigasi | go_router | Root navigator, empat tab, route detail, serta redirect sesi [S1] |
| UI dan styling | Material 3, ThemeData, ColorScheme | Widget bawaan untuk formulir, daftar, dan jadwal; tema terpusat |
| State aplikasi | ChangeNotifier, ListenableBuilder, setState | Controller auth/snapshot; state formulir lokal; tanpa paket state tambahan |
| Formulir dan validasi | Form, TextFormField, validator Dart | Validasi klien eksplisit; pemeriksaan server tetap wajib |
| Input tanggal dan jam | showDatePicker dan showTimePicker | Picker bawaan Flutter; tidak perlu plugin tambahan |
| Pengolahan waktu | DateTime, timezone, intl | Instan UTC; pola dan tampilan Asia/Jakarta terlepas zona perangkat [S12] |
| Backend dan database | Supabase PostgreSQL, Auth, REST/RPC, RLS | Database relasional dan transaksi tugas serta sesi [S6] |
| Klien API | supabase_flutter | Auth, pembacaan, dan RPC melalui SDK Dart resmi [S6] |
| Penyimpanan sesi auth | flutter_secure_storage dan LocalStorage Supabase | Adapter khusus agar sesi tidak memakai penyimpanan plaintext [S8a][S8b] |
| Cache offline | sqflite | Snapshot baca terpisah per akun pada SQLite Android [S9] |
| Indikator koneksi | connectivity_plus | Sinyal koneksi; request tetap menangani timeout/error [S13] |
| Unit dan widget test | flutter_test dari Flutter SDK | Uji planner, controller, formulir, dan tampilan [S7] |
| Pengujian backend | Supabase CLI, pgTAP, flutter_test | Uji SQL/RLS dan dua klien Supabase terpisah untuk RPC paralel |
| Pengujian perangkat | integration_test dari Flutter SDK | Alur login sampai progres dan plugin Android [S7] |
| Pemeriksaan kode | flutter analyze, flutter_lints, dart format | Pemeriksaan statis dan konsistensi Dart |
| Package manager | flutter pub, pubspec.yaml, pubspec.lock | Lockfile aplikasi disimpan agar resolusi dependensi dapat diulang |
| Build demonstrasi | Flutter CLI dan Android SDK/Gradle | APK release lokal; signing disiapkan untuk artefak demonstrasi [S10] |

<!-- pagebreak -->

### 1.5 Kebijakan pemasangan dan versi

Gunakan Flutter kanal stable pada saat setup; Dart mengikuti versi yang dibundel Flutter, bukan dipasang terpisah. Catat flutter --version, dart --version, versi Java/Android SDK, serta minimum SDK Android pada README. Minimum SDK mengikuti syarat tertinggi Flutter dan plugin yang dipilih; jangan menebak kompatibilitas versi yang belum diuji.

Dependensi runtime: go_router, supabase_flutter, flutter_secure_storage, sqflite, connectivity_plus, timezone, intl, serta flutter_localizations dari SDK. Dependensi pengembangan: flutter_test dan integration_test dari SDK serta flutter_lints. Pasang paket melalui flutter pub add; simpan pubspec.lock dan batas SDK dalam pubspec.yaml. Instal ulang memakai flutter pub get; perubahan lockfile harus ditinjau, bukan upgrade otomatis saat build.

Baseline siap setelah flutter doctor -v, flutter analyze, dart format --output=none --set-exit-if-changed lib test integration_test, unit/widget test, dan smoke test Android lulus. Inisialisasi database timezone sebelum planner digunakan; pilih Asia/Jakarta secara eksplisit. Aktifkan lokal id_ID pada MaterialApp.router. Konfigurasi publik SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY melalui --dart-define; keduanya dapat diekstrak dari APK sehingga bukan tempat secret.

APK penerimaan dibuat dengan flutter build apk --release beserta konfigurasi publik, dipasang pada perangkat uji, dan diuji ulang. Siapkan signing release; key.properties dan keystore tidak masuk repository. AndroidManifest release harus mengizinkan INTERNET. Tidak dibutuhkan layanan build cloud. Pergantian stack merupakan keputusan pemilik proyek; kesesuaiannya dengan penilaian mata kuliah yang mencontohkan Expo Router masih perlu dikonfirmasi kepada dosen.

<!-- pagebreak -->

## 2 Alur pengguna dan kebutuhan fungsional

### 2.1 Alur pertama kali

1. Pengguna mendaftar atau masuk dengan email dan kata sandi.
2. Pengguna mencatat minimal satu tugas dengan nama, tenggat, dan perkiraan sisa menit.
3. Pengguna menentukan rentang pengerjaan yang diizinkan. Tidak ada asumsi bahwa seluruh waktu kosong adalah waktu belajar.
4. Pengguna memasukkan kuliah atau kegiatan rutin dan pengecualian tanggal jika diperlukan.
5. Pengguna meminta pratinjau, memeriksa kekurangan waktu, lalu mengonfirmasi jadwal.
6. Setelah satu sesi, pengguna mencatat status dan sisa pengerjaan sebenarnya.

### 2.2 Kebutuhan fungsional

| ID | Kebutuhan | Hasil yang harus terlihat |
| --- | --- | --- |
| FR01 | Masuk, daftar, dan keluar akun | Identitas sesi jelas; pengguna hanya melihat datanya |
| FR02 | Kelola tugas | Nama, mata kuliah opsional, tenggat, sisa durasi; konfirmasi sebelum hapus |
| FR03 | Kelola waktu yang diizinkan | Pola mingguan dan tambahan per tanggal dapat digabung |
| FR04 | Kelola kegiatan | Kegiatan rutin atau sekali dan penutupan manual mengurangi waktu |
| FR05 | Buat pratinjau | Sesi, jendela perencanaan, revisi data, dan kekurangan tampil |
| FR06 | Konfirmasi jadwal | Jadwal tersimpan utuh atau gagal utuh; pratinjau bukan hasil simpan |
| FR07 | Catat progres | Sesi selesai atau terlewat; sisa pengerjaan tidak terhitung ganda |
| FR08 | Susun ulang | Riwayat dipertahankan; perubahan masa depan membutuhkan konfirmasi |
| FR09 | Baca cache | Data terakhir bertanda offline dan waktu pembaruan |

### 2.3 Jika rencana tidak mencukupi

Pengguna melihat tugas dan jumlah menit yang belum tertampung. Ia dapat menambah rentang, memperbaiki estimasi, atau memutuskan sendiri perubahan lain. Sistem tidak menambah waktu, menggeser tenggat, atau menyatakan semua tugas pasti selesai. Tenggat lewat ditandai terlambat. Pekerjaan di luar jendela perencanaan dibedakan dari kekurangan kapasitas sebelum tenggat.

### 2.4 Jika terjadi gangguan

Jika simpan gagal atau koneksi terputus, input formulir tetap berada di layar dan tidak diberi status berhasil. Jika status hasil simpan tidak diketahui akibat timeout, ambil ulang data sebelum mengirim ulang. Jika data berubah sejak pratinjau dibuat, pengguna diminta memuat ulang dan menghitung pratinjau baru.

<!-- pagebreak -->

## 3 Aturan waktu dan mesin penjadwalan

### 3.1 Representasi waktu

Semua durasi adalah bilangan bulat menit. Tenggat dan sesi adalah timestamp berzona, disimpan sebagai timestamptz dan ditampilkan dalam Asia/Jakarta. Pola mingguan menyimpan weekday ISO 1–7 beserta menit sejak tengah malam. Hari tertentu menggunakan date lokal. Interval memakai bentuk setengah terbuka [mulai, selesai): 19.00–20.00 boleh diikuti sesi mulai 20.00.

Formulir menerima rentang dalam satu hari, dengan 00.00 sampai akhir hari sebagai batas. Nilai end_minute=1440 mewakili akhir hari; jam mulai kurang dari 1440. Rentang melintasi tengah malam diinput sebagai dua rentang pada hari berbeda. Dengan demikian tidak ada tafsir tanggal yang tersembunyi.

### 3.2 Menggabungkan manual dan otomatis

Waktu tersedia = gabungan seluruh rentang yang diizinkan, dikurangi gabungan kegiatan dan penutupan. Urutkan dan gabungkan rentang bertumpuk atau bersentuhan sebelum pengurangan. Penutupan mengalahkan rentang tambahan. Pengguna harus mengubah kegiatan atau penutupan untuk membuka waktunya; tambahan manual tidak menimpanya diam-diam.

Contoh: rentang 19.00–22.00 ditambah 21.00–23.00 menghasilkan 19.00–23.00, bukan lima jam. Jika kegiatan menutup 20.00–21.00, hasil bersihnya adalah 19.00–20.00 dan 21.00–23.00, yaitu 180 menit.

### 3.3 Jendela dan urutan alokasi

Keputusan MVP: jendela tetap 14 tanggal kalender, mulai dari waktu sekarang yang dibulatkan naik ke menit penuh, berakhir pada 00.00 tanggal ke-15 dalam WIB. Tujuannya membatasi beban dan membuat hasil mudah diperiksa. UI wajib menampilkan rentang ini. Waktu sekarang disuntikkan sebagai parameter saat pengujian, bukan dibaca tersembunyi dari jam perangkat.

Tugas dengan sisa nol diabaikan. Tugas lain diurutkan menurut deadline_at, created_at, lalu id sebagai pembanding akhir. Ambil interval tersedia paling awal dan alokasikan sebanyak mungkin sisa menit, berhenti pada tenggat atau akhir jendela. Sesi dapat dipecah tanpa durasi minimum tambahan; presisi MVP adalah satu menit. Satu waktu hanya boleh dipakai satu tugas.

### 3.4 Kontrak fungsi inti

```dart
List<Interval> mergeIntervals(List<Interval> intervals);
List<Interval> subtractIntervals(
  List<Interval> allowed, List<Interval> busy);
List<Interval> expandWindows(PlannerSnapshot input, DateTime now);
SchedulePreview buildPreview(PlannerSnapshot snapshot, DateTime now);
```

Model berupa class Dart immutable dengan field final dan enum; tanpa code generation pada MVP. Interval memiliki DateTime start/end UTC. SchedulePreview memiliki int inputRevision; DateTime generatedAt, windowStart, windowEnd; List<ProposedSession> sessions; List<Unallocated> unallocated. ProposedSession memiliki String taskId serta DateTime startsAt/endsAt. Unallocated memiliki String taskId, int minutes, dan UnallocatedReason reason.

Nama field Dart memakai camelCase; fromJson/toJson memetakan snake_case sesuai kontrak API Bagian 8. Enum reason dikirim persis sebagai past_deadline, insufficient_capacity, atau outside_horizon. Instan hasil parsing dinormalisasi dengan toUtc(); JSON memakai toIso8601String(). Gunakan TZDateTime dengan lokasi Asia/Jakarta untuk batas tanggal/pola mingguan, bukan DateTime lokal perangkat. Formulir tanggal dan TimeOfDay ditafsirkan sebagai WIB sebelum dikonversi ke UTC. Konversi UTC, WIB, dan round-trip JSON wajib diuji.


<!-- pagebreak -->

## 4 Status sesi dan hasil perencanaan

### 4.1 Kekurangan yang dapat dijelaskan

Setiap hasil unallocated menyebut task_id, minutes, dan reason. Gunakan past_deadline ketika tenggat sudah lewat; insufficient_capacity jika tenggat masih berada dalam jendela tetapi waktu tidak mencukupi; outside_horizon jika sisa belum tertampung dan tenggat berada setelah jendela. outside_horizon berarti belum direncanakan dalam jendela ini, bukan bukti tugas mustahil selesai. Bila tenggat setelah jendela tetapi tugas sudah tertampung penuh, tidak ada peringatan sisa.

### 4.2 Status dan aturan progres

| Status sesi | Makna | Pengaruh pada sisa tugas |
| --- | --- | --- |
| planned | Sesi terkonfirmasi yang belum ditutup | Tidak mengurangi sisa secara otomatis |
| completed | Pengguna menutup sesi setelah mengerjakan | Pengguna memasukkan remaining_after >= 0 |
| missed | Pengguna menyatakan sesi tidak dikerjakan | Sisa tugas dipertahankan |
| cancelled | Sesi belum selesai yang digantikan jadwal baru | Tidak dianggap sudah dikerjakan |

completed berarti sesi selesai, bukan otomatis seluruh tugas selesai. Hanya sesi yang sudah mulai menurut waktu server dapat ditutup. Sisa menit boleh lebih besar dari sebelumnya bila estimasi awal terlalu kecil. Status terminal completed, missed, dan cancelled tidak diedit kembali dalam MVP. Koreksi sisa tugas tetap dapat dilakukan dari formulir tugas dan mengharuskan pratinjau baru. Menutup progres yang sama dua kali harus ditolak tanpa mengurangi sisa dua kali.

### 4.3 Penjadwalan ulang

Sebelum membuat pratinjau baru, sesi planned yang waktu mulainya sudah lewat harus ditutup pengguna sebagai completed atau missed. Sesi yang sedang berlangsung juga ditutup terlebih dahulu; sistem tidak menebak pekerjaan aktual. Ini mencegah alokasi ulang sisa yang ternyata sudah dikerjakan.

Pratinjau mengabaikan sesi planned mendatang karena kandidat baru akan menggantikannya. Interval completed yang masih beririsan dengan waktu mendatang dikurangi dari kapasitas agar alokasi historis tidak dipakai ulang. Saat konfirmasi, hanya sesi planned mendatang yang diubah menjadi cancelled, lalu kandidat baru disimpan. Riwayat completed dan missed tetap. Tidak ada pemindahan atau penghapusan riwayat akibat penjadwalan ulang. Penghapusan tugas membutuhkan konfirmasi eksplisit bahwa sesi terkait juga dihapus.

### 4.4 Contoh hasil untuk demonstrasi

Gunakan waktu awal tetap 9 November 2026 pukul 18.00 WIB. T01 memerlukan 240 menit, tenggat 11 November 18.00; T02 120 menit, tenggat 12 November 23.00; T03 180 menit, tenggat 13 November 12.00. Rentang bersih: 9 November 19.00–20.00 dan 21.00–22.00; 10 November 19.00–21.00; 11 November 19.00–21.00; 12 November 19.00–20.00. Tidak ada rentang lain pada fixture.

Hasil yang diharapkan: T01 mendapat 240 menit pada Senin–Selasa, T02 120 menit pada Rabu, T03 60 menit pada Kamis, dan T03 kekurangan 120 menit dengan reason insufficient_capacity. Menambah dua jam pada Kamis sebelum tenggat menghilangkan kekurangan. Dataset ini adalah fixture demonstrasi, bukan bukti aplikasi sudah diuji.

<!-- pagebreak -->

## 5 Struktur layar dan navigasi

MaterialApp.router memakai go_router. Root navigator memuat autentikasi, shell empat tab, formulir, pratinjau, dan detail sesi. StatefulShellRoute.indexedStack mempertahankan state tiap tab. Route detail/form menggunakan root navigator agar tampil di atas shell; redirect mengikuti perubahan sesi AuthController [S1].

```text
/login                 Masuk dan daftar; di luar shell
/home                  Tab Ringkasan
/tasks                 Tab Tugas
/time                  Tab Waktu
/schedule              Tab Jadwal
/task/new              Form tambah; root navigator
/task/:id              Form ubah; root navigator
/schedule/preview      Kandidat; root navigator
/session/:id           Progres; root navigator
```

Konfigurasi route berada pada lib/app/router.dart. Gunakan NavigationBar Material 3 untuk tab. Route tidak bergantung nama file; lib/features/ memuat widget layar. Jika sesi hilang, bersihkan state akun sebelum redirect ke /login. Jika halaman pratinjau dibuka tanpa kandidat aktif, arahkan kembali ke jadwal dengan pesan untuk menghitung ulang.

| Layar | Isi dan tindakan utama | Kondisi khusus |
| --- | --- | --- |
| Masuk | Email, kata sandi, masuk, daftar | Loading, input salah, email perlu dikonfirmasi |
| Ringkasan | Sesi hari ini, tugas terlambat, kekurangan terakhir | Belum ada tugas, ada sesi perlu ditutup, offline |
| Tugas | Nama, tenggat, sisa; tambah, ubah, hapus | Sisa nol tampil selesai; hapus perlu konfirmasi |
| Waktu | Rentang diizinkan, kegiatan, pengecualian tanggal | Konflik dan hasil waktu bersih terlihat |
| Pratinjau | Jendela, kandidat, sisa per tugas, konfirmasi | Pratinjau lama ditolak; waktu habis dihitung ulang |
| Jadwal | Sesi terkonfirmasi per tanggal | Tandai data perlu diperbarui setelah perubahan input |
| Detail sesi | Selesai atau terlewat; sisa pengerjaan | Tombol simpan terkunci saat pending atau offline |

### 5.1 Perilaku lintas layar

Semua formulir mempunyai label, pesan kesalahan dekat isian, dan tombol batal. Input belum tersimpan tidak hilang ketika simpan gagal. Hindari informasi yang hanya dibedakan lewat warna. Sediakan label pembaca layar, ukuran sentuh memadai, teks yang tetap terbaca saat ukuran font perangkat meningkat, serta scroll saat keyboard terbuka.

Keluar akun menghapus cache pribadi sebelum akun lain dibuka. Layar terlindungi tidak menampilkan data akun sebelumnya ketika sesi berubah. Cache hanya dibaca untuk pengguna yang sama; pendaftaran atau masuk baru memerlukan koneksi. Nama tugas dan pesan di UI tidak menyebut detail implementasi seperti RLS atau SQL.

<!-- pagebreak -->

## 6 Model data dan invariannya

Gunakan empat tabel bisnis dari proposal dan satu tabel kecil planner_state untuk revisi bersama. Tabel kelima merupakan keputusan teknis agar pratinjau yang dibuat dari data lama dapat ditolak secara konsisten.

| Tabel | Kolom dan constraint utama |
| --- | --- |
| tasks | id uuid PK; user_id uuid FK auth.users; title text 1–120 karakter setelah trim; course text opsional <=100 karakter; deadline_at timestamptz; remaining_minutes integer >=0; created_at timestamptz |
| time_windows | id uuid PK; user_id FK; weekday smallint 1–7 atau date date; start_minute integer 0–1439; end_minute integer 1–1440; end > start; tepat satu weekday/date |
| activities | Struktur waktu sama dengan time_windows; kind enum routine, event, blocked; label text <=120; routine memakai weekday, event/blocked memakai date |
| sessions | id uuid PK; user_id FK; task_id FK tasks; starts_at dan ends_at timestamptz; status planned/completed/missed/cancelled; remaining_after integer nullable >=0; closed_at timestamptz nullable |
| planner_state | user_id uuid PK FK auth.users; revision bigint >=0; satu baris per pengguna, dibuat melalui jalur server saat pengguna pertama kali menulis |

### 6.1 Constraint dan relasi

sessions harus mempunyai pemilik yang sama dengan tasks. Gunakan foreign key gabungan (task_id, user_id) ke tasks(id, user_id) dengan pasangan tersebut unique. Durasi sesi positif dan kelipatan menit. Sesi planned yang aktif tidak boleh saling beririsan per pengguna. Periksa juga tenggat, rentang tersedia, dan status pada fungsi penyimpanan; constraint foreign key saja tidak cukup.

Title, durasi, rentang, enum, dan tanggal divalidasi kembali di server. Input tanggal wajib jelas; jangan mengandalkan parsing lokal yang ambigu. Tugas baru harus mempunyai sisa durasi positif. Pada tugas yang sudah ada, pembaruan sisa menjadi nol menandai tugas selesai. UTC dipakai untuk penyimpanan instan, WIB untuk perluasan pola mingguan dan tampilan.

### 6.2 Revisi dan penghapusan

revision bertambah satu pada setiap transaksi perubahan tugas, waktu, kegiatan, progres, atau konfirmasi jadwal yang berhasil. Gagal validasi tidak menaikkan revisi. Semua mutasi mengunci baris planner_state pengguna lebih dahulu, membandingkan expected_revision, dan baru menyentuh tabel bisnis dalam transaksi yang sama.

Menghapus tugas menghapus sesi terkait setelah konfirmasi pengguna. Mengubah tenggat atau waktu tidak diam-diam memindahkan jadwal tersimpan: UI menunjukkan perlu penjadwalan ulang dan menghitung apakah sesi lama masih sesuai input terbaru. Sebelum konfirmasi baru, progres tetap boleh ditutup dengan sisa aktual yang dilaporkan pengguna.

<!-- pagebreak -->

## 7 API dan kontrak layanan

Supabase menyediakan REST berdasarkan skema dan RPC untuk fungsi database [S2][S3]. Endpoint di bawah adalah kontrak yang akan dibuat, bukan URL proyek live. Pemilik data diturunkan dari auth.uid(); klien tidak memilih user_id pada mutasi.

### 7.1 Pembacaan dan snapshot

GET /rest/v1/tasks, time_windows, activities, dan sessions digunakan untuk tampilan, dengan filter tanggal dan pemilik melalui RLS. Untuk menghitung jadwal, gunakan POST /rest/v1/rpc/get_planner_snapshot agar empat dataset dan revision diperoleh sebagai satu snapshot konsisten. PlannerSnapshot berisi revision, tasks, time_windows, activities, dan sessions. Fungsi snapshot memakai penguncian per pengguna yang sama dengan mutasi selama pembacaan.

### 7.2 Mutasi yang diizinkan

Semua mutasi memakai POST /rest/v1/rpc/{nama_fungsi}. Ini merinci keputusan transaksi pada proposal, tanpa menambah backend terpisah. Berikan SELECT pada tabel sesuai RLS; tulis langsung melalui REST tabel dibatasi agar perubahan tidak melewati mekanisme revisi.

| Fungsi | Argumen utama selain expected_revision | Efek atomik |
| --- | --- | --- |
| save_task | task_id nullable, title, course, deadline_at, remaining_minutes | Tambah/ubah satu tugas |
| delete_task | task_id, confirm_delete=true | Hapus tugas dan sesi terkait |
| save_time_window | id nullable, weekday/date, start_minute, end_minute | Tambah/ubah waktu diizinkan |
| delete_time_window | id | Hapus rentang diizinkan |
| save_activity | id nullable, kind, label, weekday/date, start_minute, end_minute | Tambah/ubah kegiatan atau penutupan |
| delete_activity | id | Hapus kegiatan atau penutupan |
| record_progress | session_id, status, remaining_after | Tutup sesi dan perbarui sisa bila completed |
| confirm_schedule | input_revision, window_start/end, sessions | Batalkan planned mendatang dan simpan kandidat tervalidasi |

confirm_schedule menggunakan input_revision sebagai revisi yang diharapkan. Identitas, seluruh perubahan, dan kenaikan revision berada dalam transaksi yang sama. Semua fungsi hanya diberikan ke authenticated. get_planner_snapshot boleh membuat state kosong secara aman bila belum ada, tanpa membuka data pengguna lain.

### 7.3 Hasil dan error

Mutasi berhasil mengembalikan revision baru dan data minimum yang berubah. Kontrak error aplikasi memakai code, message, dan field opsional. Gunakan kode UNAUTHENTICATED, FORBIDDEN, NOT_FOUND, VALIDATION_ERROR, STALE_REVISION, dan SESSION_ALREADY_CLOSED. Adapter memetakan error SDK/SQL/HTTP ke kode tersebut; respons RLS tanpa baris bukan bukti data tidak pernah ada. Pesan ke pengguna tidak membocorkan keberadaan data akun lain.

<!-- pagebreak -->

## 8 Transaksi jadwal dan contoh kontrak

### 8.1 Bentuk pratinjau

```json
{
  "input_revision": 12,
  "generated_at": "2026-11-09T18:00:00+07:00",
  "window_start": "2026-11-09T18:00:00+07:00",
  "window_end": "2026-11-23T00:00:00+07:00",
  "sessions": [
    {
      "task_id": "<uuid-tugas>",
      "starts_at": "2026-11-09T19:00:00+07:00",
      "ends_at": "2026-11-09T20:00:00+07:00"
    }
  ],
  "unallocated": [
    {
      "task_id": "<uuid-tugas-lain>",
      "minutes": 120,
      "reason": "insufficient_capacity"
    }
  ]
}
```

UUID di atas merupakan penanda skema, bukan fixture siap dikirim. Konfirmasi hanya mengirim revisi, batas jendela, dan sesi kandidat. generated_at dan unallocated untuk UI, tidak dipercaya sebagai pembuktian validitas di server.

### 8.2 Urutan validasi server

1. Pastikan pengguna terautentikasi; kunci planner_state miliknya dan cocokkan revisi.
2. Periksa batas jendela 14 tanggal dan waktu sekarang dari server. Kandidat dengan sesi yang telah mulai harus dihitung ulang; sesi tidak ditempatkan ke masa lalu.
3. Pastikan tidak ada sesi planned yang sudah mulai tetapi progresnya belum ditutup.
4. Validasi kepemilikan tugas, durasi positif, tidak overlap, ketersediaan waktu, serta akhir sesi tidak melewati tenggat. Total alokasi per tugas tidak melebihi sisa.
5. Ubah planned mendatang menjadi cancelled, masukkan kandidat, naikkan revision, lalu commit. Kegagalan apa pun melakukan rollback seluruh perubahan.

Server wajib memverifikasi invariant jadwal, tetapi tidak harus mengulang seluruh algoritma pengurutan untuk menilai optimalitas. Pengujian fungsi Dart murni membuktikan urutan deterministik; pengujian server membuktikan integritas dan otorisasi.

### 8.3 Timeout dan permintaan berulang

Jangan melakukan retry buta untuk mutasi. Setelah timeout, ambil snapshot terbaru. Jika transaksi awal berhasil, revisi lama pada permintaan ulang ditolak sehingga tidak menggandakan perubahan. Jika tidak berhasil, pengguna dapat mencoba setelah melihat status terbaru. Tombol konfirmasi dan progres dinonaktifkan selama pending. Kepastian hasil lebih penting daripada tampilan sukses seketika.

<!-- pagebreak -->

## 9 Keamanan privasi dan penyimpanan lokal

### 9.1 Autentikasi dan akses

Gunakan publishable key di aplikasi bersama sesi pengguna, bukan secret atau service_role key [S4]. Aktifkan RLS pada semua tabel exposed dan batasi SELECT ke auth.uid() = user_id [S5]. Tab dan route detail wajib memeriksa sesi, tetapi penjagaan layar tidak menggantikan pemeriksaan server.

Karena tulis langsung tabel dibatasi, fungsi mutasi dapat memakai SECURITY DEFINER yang dibatasi ketat: search_path kosong, semua referensi tabel berkualifikasi skema, auth.uid() wajib ada, setiap baris diperiksa pemiliknya, tidak ada dynamic SQL, serta EXECUTE dicabut dari PUBLIC/anon dan diberikan hanya ke authenticated. Fungsi ini melewati jalur hak tabel biasa sehingga uji lintas akun dan manipulasi argumen wajib lulus. Alternatif privilege tidak diubah tanpa meninjau kembali mekanisme revisi [S3].

### 9.2 Cache dan kondisi offline

SQLite hanya menyimpan snapshot baca terakhir per user_id, fetched_at, dan payload yang diperlukan UI. Setelah jaringan gagal, tampilkan label Data terakhir beserta waktu pembaruan. Pengguna dapat membaca jadwal, tetapi menambah, mengubah, menghapus, menutup progres, menghasilkan pratinjau, dan mengonfirmasi dinonaktifkan saat offline. Tidak ada antrean tulis atau rekonsiliasi offline pada MVP.

Cache lama dihapus sebelum akun berganti atau saat keluar. Token dan kata sandi tidak ditulis ke SQLite, log, fixture, atau tangkapan layar pengujian. Persistensi sesi memakai implementasi LocalStorage dari supabase_flutter yang menyimpan session string melalui flutter_secure_storage; injeksikan melalui FlutterAuthClientOptions.localStorage. Jangan memakai persistensi SharedPreferences bawaan untuk token. Adapter menyediakan initialize, hasAccessToken, accessToken, persistSession, dan removePersistedSession sesuai SDK terkunci. SDK menangani serialisasi sesi; adapter menyimpan/membaca string utuh tanpa mengubah kontraknya [S8a][S8b].

Uji pemulihan sesi, refresh, logout, penolakan penyimpanan, dan restart pada Android. Jika storage gagal, tampilkan kegagalan dan hentikan persistensi/login; jangan beralih diam-diam ke plaintext. Saat logout offline, bersihkan sesi lokal, cache, serta state memori; logout lokal tidak menjamin pencabutan sesi server sampai ada koneksi. Nonaktifkan backup data sesi terenkripsi sesuai petunjuk plugin agar pemulihan backup tidak menghasilkan key yang tidak cocok. Bila cache rusak, bersihkan cache saja dan muat ulang cloud; jangan menghapus data cloud.

### 9.3 Keandalan dan target teknis

Target rancangan, bukan hasil benchmark: pratinjau <=1 detik untuk 50 tugas dan jendela 14 tanggal pada perangkat Android uji yang dicatat. Permintaan jaringan memakai timeout aplikasi 15 detik dan menyediakan coba lagi manual. Pembacaan tidak memuat seluruh histori sesi tanpa batas; ambil rentang tanggal yang dibutuhkan. Pisahkan waktu komputasi dari latensi jaringan saat mencatat performa.

Kondisi 429 tidak diulang cepat; ikuti Retry-After bila tersedia. Kuota dan batas proyek Supabase diperiksa saat setup; angka global tidak diasumsikan sama untuk seluruh layanan. Rilis demo menggunakan data sintetis, dua akun uji, dan kredensial yang tidak dibagikan di laporan.

<!-- pagebreak -->

## 10 Acceptance criteria dan matriks pengujian

| ID | Kondisi uji | Hasil yang harus dibuktikan |
| --- | --- | --- |
| AC01 | Akun B dan tanpa sesi mengakses ID milik A | Tidak memperoleh data atau mengubah baris milik A |
| AC02 | Nama kosong, menit negatif, rentang terbalik | Validasi menolak; data dan revision tidak berubah |
| AC03 | Rentang 19–22 dan 21–23 | Gabungan 240 menit sebelum pengurangan |
| AC04 | AC03 dikurangi kegiatan 20–21 | Hasil bersih 180 menit dan dua interval |
| AC05 | Sesi berakhir 20.00, sesi lain mulai 20.00 | Diterima; irisan satu menit ditolak |
| AC06 | Tenggat 20.30 di rentang 20–22 | Alokasi maksimum sampai 20.30 |
| AC07 | Fixture 540 kebutuhan dan 420 kapasitas | T03 kurang 120 menit; kandidat lain sesuai Bagian 4 |
| AC08 | Tambah 120 menit tersedia sebelum tenggat | Kekurangan fixture menjadi nol |
| AC09 | Tenggat lewat atau setelah jendela | Reason past_deadline atau outside_horizon tepat |
| AC10 | Input sama, now dan revision sama | Kandidat dan urutan sama pada setiap pemanggilan |
| AC11 | Tutup missed | Tidak mengurangi sisa tugas |
| AC12 | Tutup completed dengan remaining_after=90 | Sisa tepat 90; penutupan ulang ditolak |
| AC13 | planned sudah mulai dan belum ditutup | Pratinjau/konfirmasi diblokir sampai progres ditutup |
| AC14 | Revisi berubah setelah pratinjau | Konfirmasi gagal tanpa membatalkan jadwal lama |
| AC15 | Gagal di tengah penyimpanan atau dua konfirmasi serentak | Tidak ada penyimpanan parsial; paling banyak satu revisi lama berhasil |
| AC16 | Kandidat memuat tugas akun lain atau waktu terlarang | Server menolak seluruh transaksi |
| AC17 | Offline dan pergantian akun | Cache bertanda waktu; tulis dinonaktifkan; data A tidak muncul pada B |
| AC18 | Hapus tugas dibatalkan atau disetujui | Batal tidak mengubah data; setuju menghapus sesi terkait |

Unit test menilai interval, timezone, pengurutan, dan fixture. Integration test menilai transaksi, RLS, serta RPC. Uji Android manual menilai navigasi, keyboard, keterbacaan, putus koneksi, dan pembukaan ulang aplikasi. Semua AC wajib lulus sebelum demo cloud dinyatakan siap. Hasil dan bukti masih harus dikumpulkan saat implementasi.

<!-- pagebreak -->

## 11 Cetak biru file dan tahap implementasi

### 11.1 Struktur minimum

```text
lib/main.dart                     Inisialisasi SDK dan timezone
lib/app/app.dart                   MaterialApp.router dan locale
lib/app/router.dart                go_router dan penjagaan sesi
lib/app/theme.dart                 ThemeData dan ColorScheme
lib/features/auth/login_screen.dart
lib/features/home/home_screen.dart
lib/features/tasks/tasks_screen.dart
lib/features/tasks/task_form_screen.dart
lib/features/time/time_screen.dart
lib/features/schedule/schedule_screen.dart
lib/features/schedule/preview_screen.dart
lib/features/schedule/session_screen.dart
lib/state/auth_controller.dart     Sesi akun dan logout
lib/state/planner_controller.dart  Snapshot, pending, dan error
lib/planner/models.dart            Model immutable dan JSON
lib/planner/intervals.dart          Merge dan pengurangan
lib/planner/schedule.dart           Perluasan dan alokasi
lib/planner/fixtures.dart           Dataset demo tetap
lib/data/supabase_client.dart       Konfigurasi klien
lib/data/auth_storage.dart          LocalStorage terenkripsi
lib/data/planner_api.dart           Snapshot, RPC, pemetaan error
lib/data/cache.dart                 Cache SQLite per akun
test/planner/                      Model, interval, jadwal
test/ui/                           Widget dan controller
test/data/                         Storage, API, cache via fake
test/backend/                      RPC dua klien, backend lokal
integration_test/                  Smoke test Android
supabase/migrations/                Skema, RLS, grants, RPC
supabase/tests/                     SQL pgTAP
```

UI memakai model planner yang sama; aturan jadwal hanya di lib/planner/. AuthController dan PlannerController memakai ChangeNotifier; widget mengamati melalui ListenableBuilder. setState dan TextEditingController menangani formulir lokal; dispose controller/subscription saat tidak dipakai. Dependensi disuntikkan melalui constructor dari app.dart. Tidak ada Riverpod, Bloc, GetX, generator model, atau backend CRUD tambahan dalam baseline. Gunakan fake penyimpanan/API pada unit test; plugin nyata diperiksa melalui integration_test Android.

### 11.2 Tahap dan hasil yang dapat ditinjau

| Tahap | Hasil | Verifikasi utama |
| --- | --- | --- |
| M1 | Proyek Flutter dan navigasi memakai fixture | Seluruh route utama terbuka dan kembali dengan benar |
| M2 | Mesin interval dan jadwal | AC03–AC10 lulus tanpa UI atau jaringan |
| M3 | Form tugas/waktu dan progres lokal dummy | Input sampai pratinjau dan progres dapat didemo |
| M4 | Skema, Auth, RLS, snapshot, dan RPC | AC01, AC02, AC11–AC16, AC18 lulus pada backend uji |
| M5 | Integrasi cloud dan cache baca | AC17; status simpan dan pratinjau kedaluwarsa benar |
| M6 | Build Android dan dokumentasi | Semua AC, smoke test perangkat, dan bukti demo lengkap |

Tahap bukan janji tanggal selesai; tenggat mata kuliah belum diberikan. M1–M3 dapat dikerjakan dengan data sintetis sambil menyiapkan proyek Supabase. Setelah M4, uji keamanan tidak ditunda sampai akhir. Rencana langkah implementasi terpisah disertakan dalam Rencana_Implementasi_WaktuTugas.md.

<!-- pagebreak -->

## 12 Risiko keputusan terbuka dan definisi selesai

| Risiko | Tindakan dalam MVP |
| --- | --- |
| Estimasi pengguna meleset | Sisa menit dapat diperbaiki; tampilkan jadwal sebagai rencana |
| Jam perangkat berbeda dari server | Konfirmasi memakai waktu server; kandidat masa lalu ditolak |
| Hak fungsi database terlalu luas | Grants minimum, pemeriksaan pemilik, dan uji dua akun |
| Penyimpanan timeout atau data berubah | Muat ulang snapshot; revisi mencegah perubahan berganda |
| Jendela 14 tanggal dianggap seluruh masa depan | Tampilkan batas jendela dan reason outside_horizon |
| Beban proyek individu membesar | Pertahankan fitur di luar MVP pada backlog |

### 12.1 Yang masih perlu divalidasi

Wawancara 5–8 mahasiswa, kesesuaian aturan pembagian sesi satu menit, dan kenyamanan jendela 14 tanggal belum diuji. Proyek Supabase, kuota aktual, konfigurasi email, perangkat Android uji, versi SDK, dan tanggal pengumpulan belum ditetapkan. Hal-hal ini dicatat sebagai pekerjaan lanjutan, bukan alasan untuk mengarang hasil verifikasi. Revisi PRD diperlukan jika validasi mengubah aturan inti.

### 12.2 Definition of done

Fitur wajib selesai; semua AC lulus dengan bukti; tidak ada sesi yang melanggar invariant; akses lintas akun ditolak; cache bersih saat akun berganti; build dapat dipasang; dokumentasi setup dan API tersedia; fixture bisa diulang; tidak ada secret pada aplikasi/repository. Luaran mata kuliah meliputi source code, migrasi, build Android, catatan pengujian, dan laporan. PRD ini sendiri tidak menyatakan luaran tersebut sudah dibuat.

<!-- pagebreak -->

### 12.3 Sumber dan hubungan dengan proposal

Dokumen ini meneruskan Proposal WaktuTugas Ahmad Turmudi 60324069 bertanggal 3 November 2026 serta Materi Pertemuan 9. Penegasan teknis adalah jendela 14 tanggal, status sesi terminal, planner_state untuk revisi, serta mutasi RPC terpusat pada transaksi. Versi 1.2 mengganti stack implementasi ke Flutter + Dart atas pilihan pemilik proyek; navigasi, state, model, persistensi sesi, pengujian, struktur file, dan build disesuaikan. Aturan produk, kontrak JSON/RPC, model SQL, dan AC01-AC18 tetap menjadi acuan. Contoh teknologi pada materi kuliah bukan bukti izin dosen untuk mengganti stack. Semua merupakan keputusan rancangan untuk menghilangkan ambiguitas implementasi.

Dokumentasi resmi ditinjau pada 8 November 2026. Referensi berikut mendukung kemampuan platform; kontrak RPC dan aturan produk pada PRD adalah rancangan proyek ini.

- [S1 Flutter architecture recommendations and navigation](https://docs.flutter.dev/app-architecture/recommendations).
- [S2 Supabase Data REST API](https://supabase.com/docs/guides/api).
- [S3 Supabase database functions](https://supabase.com/docs/guides/database/functions).
- [S4 Supabase API keys](https://supabase.com/docs/guides/getting-started/api-keys).
- [S5 Supabase Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security).
- [S6 Supabase Flutter initialization](https://supabase.com/docs/reference/dart/initializing).
- [S7 Testing Flutter apps](https://docs.flutter.dev/testing/overview).
- [S8a Supabase Flutter LocalStorage interface](https://pub.dev/documentation/supabase_flutter/latest/supabase_flutter/LocalStorage-class.html).
- [S8b Flutter Secure Storage documentation](https://pub.dev/packages/flutter_secure_storage).
- [S9 sqflite documentation](https://pub.dev/packages/sqflite).
- [S10 Flutter build and release Android](https://docs.flutter.dev/deployment/android).
- [S11 Supabase testing overview](https://supabase.com/docs/guides/local-development/testing/overview).
- [S12 timezone documentation](https://pub.dev/packages/timezone).
- [S13 connectivity_plus documentation](https://pub.dev/packages/connectivity_plus).
