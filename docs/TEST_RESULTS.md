# Hasil Pengujian WaktuTugas 1.0.0

**Tanggal verifikasi:** 11 November 2026 (WIB)

**Acuan:** PRD WaktuTugas v1.2, bagian 10

**Status distribusi:** APK kandidat daring lulus uji alur pada emulator dan migrasi Supabase tujuan sudah diterapkan. Tag `v1.0.0` menunggu penetapan tujuan distribusi.

## Build dan perangkat

| Item | Hasil |
| --- | --- |
| Versi aplikasi | `1.0.0+1` (versionName `1.0.0`, versionCode `1`) |
| ID paket | `com.ahmadturmudi.waktutugas` |
| APK kandidat | `build/app/outputs/flutter-apk/WaktuTugas-demo-release.apk` |
| SHA-256 APK kandidat | `707c18eaf84313fd43dff538793d14b5b5c4b26df59159d4eb1b03c46ed4616b` |
| Penandatangan | `CN=WaktuTugas`, tanda tangan valid dan cocok dengan keystore rilis |
| Kompatibilitas APK | Android API 24 ke atas, ABI `arm64-v8a`, `armeabi-v7a`, dan `x86_64` |
| Perangkat uji aplikasi | Emulator Pixel 6 (`emulator-5554`), Android 15/API 35, `x86_64` |
| Backend uji | Supabase lokal dengan migrasi 001–003. Konfirmasi email diuji dengan Mailpit pada stack terpisah. |

`flutter analyze --no-pub` selesai tanpa masalah dan pemeriksaan format mencakup 41 file tanpa perubahan. Tes planner, widget, dan adapter lulus (**55 tes**). `supabase test db` lulus **278 pemeriksaan** dari dua file SQL. Uji RPC dengan dua akun lulus untuk isolasi, rollback, serta konflik revisi saat konfirmasi dan pencatatan progres berjalan bersamaan.

`storage_test.dart` dan `app_flow_test.dart` lulus pada emulator. Pengujian UI dengan APK debug yang terhubung ke Supabase lokal juga mencakup pendaftaran, penolakan login sebelum konfirmasi email, login setelah konfirmasi, pembuatan tugas, konfirmasi jadwal, pencatatan progres, pemulihan sesi saat aplikasi dibuka ulang, mode luring, pemulihan koneksi, dan pergantian akun. Pemeriksaan paket dan tanda tangan dilakukan pada APK kandidat demo.

## AC01–AC18

| ID | Hasil | Bukti dan cakupan |
| --- | --- | --- |
| AC01 | Lulus | pgTAP menolak akses tanpa sesi dan akses silang akun. Uji RPC dua akun dan UI Android memverifikasi isolasi data. |
| AC02 | Lulus | Tes formulir dan pgTAP menolak nama kosong, durasi negatif, dan rentang terbalik. pgTAP memeriksa bahwa snapshot dan revisi tetap sama. |
| AC03 | Lulus | Tes interval menggabungkan 19.00–22.00 dan 21.00–23.00 menjadi 240 menit. |
| AC04 | Lulus | Tes interval mengurangi kegiatan 20.00–21.00 dan menghasilkan 180 menit dalam dua interval. |
| AC05 | Lulus | Tes planner menerima sesi bersebelahan. pgTAP menolak irisan tepat satu menit dan memverifikasi snapshot tetap sama. |
| AC06 | Lulus | Tes planner mengakhiri sesi tepat pada tenggat 20.30. pgTAP menolak sesi yang melewati tenggat. |
| AC07 | Lulus | Tes planner dan alur demo Android memverifikasi kekurangan 120 menit pada fixture. Tes planner mengaitkannya dengan T03. |
| AC08 | Lulus | Tes planner menghilangkan kekurangan setelah 120 menit waktu yang diizinkan ditambahkan sebelum tenggat. |
| AC09 | Lulus | Tes planner memverifikasi alasan `past_deadline` dan `outside_horizon`. |
| AC10 | Lulus | Tes planner memverifikasi kandidat dan urutan yang deterministik untuk input tetap. Uji 50 tugas dalam 14 tanggal memenuhi batas 1 detik pada mesin pengembangan. |
| AC11 | Lulus | pgTAP dan tes progres memverifikasi bahwa penutupan `missed` mempertahankan sisa tugas. |
| AC12 | Lulus | pgTAP dan uji RPC menyimpan sisa tepat 90 menit dan menolak penutupan ulang. Alur demo Android menampilkan 90 menit setelah progres disimpan. |
| AC13 | Lulus | Tes planner dan UI memblokir pratinjau jika sesi `planned` sudah mulai. pgTAP menolak konfirmasi selama sesi itu belum ditutup. |
| AC14 | Lulus | pgTAP dan uji RPC menolak revisi lama serta mempertahankan jadwal sebelumnya. |
| AC15 | Lulus | pgTAP memverifikasi rollback setelah mutasi parsial. Uji RPC menunjukkan tepat satu dari dua konfirmasi serentak berhasil untuk revisi yang sama. |
| AC16 | Lulus | pgTAP menolak kandidat tugas milik akun lain dan waktu terlarang. Snapshot tetap sama setelah penolakan. |
| AC17 | Lulus | Tes penyimpanan Android memverifikasi cap waktu dan cache per akun. Uji aplikasi Android membaca cache akun A saat luring, memblokir pembuatan tugas, lalu menampilkan akun B tanpa tugas atau jadwal akun A. |
| AC18 | Lulus | Tes UI memeriksa pembatalan hapus. pgTAP memeriksa pembatalan dan penghapusan tugas beserta sesi terkait setelah konfirmasi. |

## Instalasi APK kandidat demo

1. Salin `WaktuTugas-demo-release.apk` ke perangkat Android, lalu buka dari pengelola file.
2. Jika Android meminta izin memasang aplikasi dari sumber tersebut, aktifkan izin untuk pengelola file lalu lanjutkan instalasi.
3. Buka WaktuTugas dan ketuk **Buka demo lokal**.

Cakupan verifikasi perangkat adalah emulator. Uji alur backend lengkap sebelumnya menggunakan Supabase lokal dan Mailpit. Uji alur lengkap dengan APK daring tercatat sebagai temuan R02.

## Pencatatan temuan dan tindak lanjut

Setiap eksekusi skrip rilis menyimpan status pemeriksaan, tindak lanjut, dan
SHA-256 APK di `build/release/<waktu>/hasil.md`. Gunakan catatan berikut untuk
temuan yang perlu ditindaklanjuti sampai rilis.

Eksekusi `20261111-202051-349` meluluskan 55 tes Flutter, 278 pemeriksaan SQL,
uji RPC dua akun, dan dua tes Android pada `emulator-5560`. APK demo bertanda
tangan berhasil dipasang dan dibuka. SHA-256-nya cocok dengan laporan.

Uji ulang `20261111-204715-089` menjalankan `scripts/release.ps1 -Device emulator-5560`.
Dependensi, format, analisis, 55 tes Flutter, 278 pemeriksaan SQL, uji RPC dua
akun, dan kedua tes integrasi Android lulus. Skrip membangun, memverifikasi tanda
tangan, dan memasang `build/release/20261111-204715-089/WaktuTugas-demo.apk`.
APK versi `1.0.0+1` dibuka di emulator `WaktuTugasRelease` (`emulator-5560`,
Android 15/API 35, x86_64) dan menampilkan tiga tugas demo. SHA-256 `base.apk`
di emulator cocok dengan artefak dan `build/release/20261111-204715-089/hasil.md`
(`707c18eaf84313fd43dff538793d14b5b5c4b26df59159d4eb1b03c46ed4616b`).
Laporan mencatat dua status tertunda untuk konfigurasi Supabase tujuan serta
uji APK daring dan distribusi. Status tersebut membuat skrip keluar dengan
kode `1`.

Eksekusi daring `20261111-211851-158` memakai proyek
`lgjzoipinceatiitptyc.supabase.co`. Analisis, format, 55 tes Flutter, 278
pemeriksaan SQL, RPC dua akun pada backend lokal, dan kedua tes integrasi
Android lulus. Skrip membangun, memverifikasi tanda tangan, dan memasang
`build/release/20261111-211851-158/WaktuTugas-candidate.apk` versi `1.0.0+1`
pada `emulator-5560` (Android 15/API 35, x86_64). SHA-256 APK pada emulator
cocok dengan artefak dan `build/release/20261111-211851-158/hasil.md`
(`33cbb6148a56a06316a191e33eb27f538ee97f20bc5135cea8e9e99e0257a220`).
URL HTTPS dan publishable key di APK cocok dengan konfigurasi proyek.
Layar masuk dan daftar berhasil dibuka, dan layar masuk menampilkan
penolakan kredensial uji yang tidak valid dari Supabase Auth.

Uji alur daring dengan APK yang sama lulus pada `emulator-5560`. Kedua akun
didaftarkan dan terkonfirmasi di Supabase. APK menolak login akun B sebelum
konfirmasi. Akun A berhasil masuk, membuat tugas, mengonfirmasi jadwal, dan
mencatat progres. Supabase menyimpan sesi `completed` dan sisa tugas 25 menit.
Setelah aplikasi ditutup paksa dan dibuka ulang, progres tampil lagi.
Saat Wi-Fi dan jaringan seluler dimatikan, APK memuat cache akun A dalam mode
hanya baca dan memblokir penambahan tugas. Setelah koneksi pulih, akun B
berhasil masuk dan tugas serta sesi akun A tidak muncul pada UI maupun snapshot
akun B. Hash APK terpasang diverifikasi ulang dan cocok dengan artefak di atas.

| ID | Temuan | Status | Tindakan dan bukti penutupan |
| --- | --- | --- | --- |
| R01 | Supabase tujuan belum dikonfigurasi untuk APK final. | Ditutup | Kandidat daring terpasang dan memuat URL HTTPS serta publishable key proyek yang ditetapkan. |
| R02 | Alur daring pada APK final belum lengkap. | Ditutup | Pendaftaran, konfirmasi email, login, pembuatan tugas, konfirmasi jadwal, progres, pemulihan sesi, cache luring hanya baca, pemulihan koneksi, dan pergantian akun lulus pada APK kandidat daring di `emulator-5560`. |
| R03 | Ringkasan README masih mencantumkan hasil lama dan menyebut tes backend serta Android tertunda. | Ditutup | README merujuk ke matriks pengujian dan menjelaskan cara menjalankan pemeriksaan rilis. |
| R04 | Tes integrasi Flutter dapat mengganti aplikasi saat ID paket debug sama dengan rilis. Flutter juga mencoba menghapus ID paket demo lama setelah tes. | Ditutup | APK debug memakai ID `com.ahmadturmudi.waktutugas.debug`. Waktu instalasi pertama paket rilis tetap sama setelah dua tes Android dan pemasangan ulang kandidat. Skrip juga memakai `--no-uninstall` untuk melewati penghapusan otomatis oleh Flutter. |
| R05 | Skrip Windows melaporkan startup Supabase gagal meski Docker aktif. | Ditutup | Skrip memakai `supabase.cmd` jika tersedia. Startup, 278 pemeriksaan SQL, dan uji RPC dua akun lulus pada pengujian ulang. |
| R06 | Proyek tujuan mengembalikan `PGRST202` untuk `get_planner_snapshot`. Pratinjau migrasi lewat koneksi langsung gagal dengan `DbConfigIpv6Error`. | Ditutup | Dengan izin pemilik, migrasi `001_schema.sql`, `002_policies.sql`, dan `003_rpc.sql` diterapkan lewat pooler IPv4. `migration list` menunjukkan ketiganya tercatat di tujuan dan pratinjau ulang menyatakan database mutakhir. RPC `get_planner_snapshot` di proyek tujuan dikenali dan menolak akses tanpa sesi dengan HTTP 401 (`42501`). Uji RPC dengan akun dari APK daring masih tercatat pada R02. |
| R07 | Konfirmasi jadwal menolak sesi dengan pesan `Rentang sesi tidak valid` saat jam emulator tertinggal sekitar 4 menit 42 detik dari Supabase. | Ditutup pada lingkungan uji | Jam emulator diselaraskan dengan waktu server dan rentang waktu fixture disesuaikan melalui RPC akun A. Pengujian ulang dari APK menyimpan sesi `planned` lalu `completed`. Pengaturan waktu otomatis emulator dikembalikan setelah uji. |

Untuk temuan baru, tambahkan versi atau hash APK, perangkat, langkah
reproduksi, hasil aktual dan yang diharapkan, serta bukti uji ulang saat ditutup.
