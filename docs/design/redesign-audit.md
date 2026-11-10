> Riwayat redesign pertama. Acuan final kini [Studio Fokus](DESIGN.md); lihat [hasil revisi](studio-fokus-review.html).

# Audit dan verifikasi redesign WaktuTugas

Tanggal: 10 November 2026 (Asia/Jakarta). Perubahan dikerjakan di working tree yang sudah berisi perubahan pengguna. Tidak ada reset, checkout, stash, commit, atau perubahan backend/algoritma dalam pekerjaan redesign ini. Screenshot awal milik pengguna tetap di root `screenshots/`; baseline dan hasil baru dipisahkan.

## Cakupan yang dibaca

PRD 1.2 (alur, aturan waktu/status, navigasi dan acceptance), README, PROGRESS, dokumen desain/handoff, pubspec, ThemeData, router, seluruh layar di `lib/features`, komponen bersama, AuthController, PlannerController dan pengujian pemanggil. Pencarian AGENTS.md di workspace dan direktori induk tidak menemukan instruksi tambahan. Dependensi, router shell, auth/backend, skema database dan scheduler tidak diganti.

## Temuan dan bukti

| Temuan | Bukti | Penyelesaian |
| --- | --- | --- |
| Metrik Ringkasan lebih dominan daripada tindakan terdekat | Render baseline `home-360-1.0` | Beban tugas satu baris, sesi/progres atau Tinjau jadwal menjadi fokus |
| Badge mempersempit judul tugas, pembungkus kartu memecah daftar | Render baseline `tugas-360-1.0` | Daftar datar, judul lebar penuh, metadata dan status jelas |
| Kapasitas bersih tersembunyi setelah daftar pengaturan | Render baseline `waktu-412-1.0`, urutan kode | Kapasitas 14 tanggal tampil pertama; detail interval tetap tersedia |
| Penanda agenda berupa stripe dekoratif, jam belum membentuk kolom | Kode SessionCard dan render | Kolom jam sejajar pada teks normal; jam di atas judul pada teks besar |
| Kolom jam versi awal redesign memecah kata pada 360/1.8 | Render hasil antara, sudah diperbaiki | Layout adaptif berdasarkan skala teks, bukan mengecilkan font |
| Label sisa aktual terpotong pada teks besar | Render progres 360/1.8, sudah diperbaiki | Label singkat dengan pertanyaan/helper terpisah |
| Warna muted lama tidak mencapai 4.5:1 pada canvas/muted | Perhitungan luminans: 4.44 dan 4.24 | inkMuted #52637A dan uji kontras otomatis |
| IconButton memakai compact density, potensi target terlalu kecil | Audit kode, bukan klaim pengukuran perangkat | Standard density dan uji target hapus minimal 48 x 48 dp |
| Tombol custom memiliki translasi/bayangan dan listener tambahan | Audit kode, bukan pengukuran latensi | FilledButton stateless dengan feedback Material; transisi halaman/tab mengikuti reduced motion |
| Dampak konfirmasi hanya mudah dibaca setelah gulir | Kode dan render pratinjau | Penjelasan singkat juga ditempatkan di footer konfirmasi |

## Keputusan desain

[DESIGN.md](DESIGN.md) adalah acuan tunggal. UI/UX Pro Max CLI tersedia dan kedua pencarian berhasil. Flat Design dan Plus Jakarta Sans sesuai produk; rekomendasi landing page/teal/orange tidak diadopsi. Identitas biru royal terbaru dipertahankan. Tidak ada grafik, persentase progres, data produksi buatan, dependency baru atau dark mode.

Tema dan komponen bersama menjangkau semua layar: empat tab, form tugas, lima varian form waktu, pratinjau, alasan kekurangan, detail/progres, login/daftar/konfirmasi dan akun. Perilaku hapus, input gagal, revisi, sesi terminal, cache luring, back dan tab state tetap melalui controller/router yang ada.

## Bukti eksekusi

- `flutter devices`: Windows, Chrome dan Edge; tidak ada Android.
- `flutter run --no-pub -d chrome --web-port 8250`: berhasil menjalankan main dan membuka debug service; pengujian interaksi utama dilakukan dengan widget tests.
- `flutter test --no-pub test/planner test/ui test/data --reporter expanded`: **55 tes lulus**.
- Render screenshot: `flutter test --no-pub test/ui/figma_screens_test.dart --dart-define=CAPTURE_UI=true --dart-define=CAPTURE_DIR=docs/design/screenshots/after-redesign`: **15 tes lulus**.
- `flutter analyze --no-pub`: tidak ada masalah.
- `dart format --output=none --set-exit-if-changed lib test integration_test`: 41 file, 0 perubahan.
- `git diff --check`: lulus; peringatan konversi LF/CRLF pada file existing bukan kesalahan whitespace.
- `flutter build apk --debug --no-pub`: berhasil, `build/app/outputs/flutter-apk/app-debug.apk`. Gradle/JDK mengeluarkan warning native-access, build tetap berhasil.

## Matriks pemeriksaan

| Skenario | Pemeriksaan |
| --- | --- |
| Empat tab, task form, keyboard, preview, konfirmasi, sesi, progres | Render 360/412 dp, skala 1.0/1.8; alur mutasi dan assertion tidak ada exception |
| Login, daftar, akun, alasan kekurangan, lima varian waktu | Render pada empat kombinasi ukuran/skala |
| Kosong: Ringkasan, Tugas, Waktu, Jadwal | Render 360 dp / 1.8 |
| Judul panjang, mata kuliah panjang, 99999 menit, terlambat | Render 360 dp / 1.8, kontrol hapus tetap 48 dp dan bisa digulir ke tampilan |
| Validasi gagal + keyboard | Error inline, input -1 bertahan, tombol simpan hit-testable |
| Offline dan loading | Screenshot, mutasi disabled, label menunggu dan hanya baca |
| Keyboard | Tab berpindah dari email ke kata sandi |
| Reduced motion + lanskap | 800 x 412, kontrol tidak bergeser saat ditekan, empat tab tetap berfungsi |
| Pratinjau basi dan sesi terminal | Konfirmasi disabled; progres terminal hanya baca |
| Data/controller/planner | Suite regresi 55 tes, termasuk adapter API/cache, validasi dan konfirmasi hapus |
| Kontras | Pasangan teks utama/sekunder/muted terhadap tiga surface >=4.5:1, pasangan status/primary >=4.5:1, batas kontrol >=3:1 |

## Membuka hasil

[Galeri perbandingan](redesign-review.html) berisi 18 pasangan sebelum/sesudah dan 12 state tambahan. Screenshot memakai fixture, waktu demo dan ukuran yang sama untuk pasangan utama. Gambar dapat dibuka pada ukuran asli. Peninjauan visual dilakukan langsung pada render awal dan hasil, termasuk teks besar, jadwal, keyboard, validasi, offline, autentikasi, akun, alasan, dan rincian waktu.

## Batas verifikasi

Screenshot berasal dari Flutter test renderer, bukan perangkat Android. Keyboard diuji melalui viewInsets dan key event, bukan IME Android nyata. TalkBack, focus traversal menyeluruh dengan screen reader, performa sentuhan/gesture perangkat, status/navigation bar OS nyata dan backend Supabase hidup belum diverifikasi. Tidak ada klaim AC backend atau penerimaan Android fisik lulus. Build debug tidak menggantikan build release bertanda tangan dan smoke test perangkat.
