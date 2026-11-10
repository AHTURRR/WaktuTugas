# Studio Fokus - audit implementasi

10 November 2026, Asia/Jakarta. Pekerjaan ini adalah revisi setelah pengguna menilai redesign pertama terlalu mirip. Pengguna mengizinkan arah visual baru secara mandiri, mengikuti PRD dan isi layar tanpa meniru produk referensi.

## Cakupan

Tema, shell, semua layar fitur, komponen bersama, dan uji kontras. Working tree yang sudah berisi perubahan pengguna dipertahankan. Tidak ada checkout/reset/stash/commit. Backend, schema, auth, controller, algoritma penjadwalan dan dependency tidak diubah dalam revisi ini. Backup lokal file UI sebelum revisi ada di build/studio-before-code sebagai .bak, bukan source Dart yang ikut dianalisis.

## Keputusan dan implementasi

- Modern Productivity biru diganti Studio Fokus: kertas #F7F5ED, pinus #183D36, lime #D7ED98, teks hijau gelap, headline 30/32.
- Shell memakai monogram jam dan dock navigasi gelap mengambang, dengan indikator lime yang tetap mengikuti state branch.
- Ringkasan menggabungkan tanggal, beban nyata dan tindakan/sesi terdekat dalam FocusPanel. Agenda dan tenggat mengikuti, tanpa grafik atau statistik buatan.
- Tugas menjadi lembar kerja dengan status, nama penuh, course opsional, tenggat dan sisa durasi. Tambah, edit, hapus dan konfirmasi tetap ada.
- Waktu menonjolkan kapasitas bersih dalam panel; izin dan kegiatan/penutupan tetap dipisahkan. Dropdown dibuat intrinsik agar pilihan tidak terpotong saat teks besar.
- Jadwal memakai panel agenda, tanggal berkelompok dan blok jam berwarna lembut. Pratinjau memiliki status usulan, jumlah sesi, jendela waktu, kekurangan dan dampak konfirmasi.
- Formulir tugas/waktu memakai pengantar dan satu lembar input, label tetap, helper dan footer simpan. Isian gagal tidak dibuang.
- Aksi detail sesi dipindah ke footer setelah ditemukan terlalu jauh dari jangkauan pada viewport 800x600. Saat mencatat progres, ringkasan sesi dipadatkan dan input sisa aktual langsung diprioritaskan.
- Login, daftar, konfirmasi, demo, akun, alasan, kosong, error, offline dan loading mengikuti token yang sama.

## Penggunaan skill

UI/UX Pro Max CLI tersedia dan dijalankan untuk desain sistem serta stack Flutter. Hasil digunakan untuk prinsip grid, kontras dan semantik, bukan menyalin landing page atau merek lain. `ui`, `ui-animation`, dan `frontend-design` digunakan untuk arah visual, pemeriksaan render serta keputusan motion. `ui-styling` berfokus pada shadcn/Tailwind sehingga implementasi stack-nya tidak diterapkan pada Flutter. `ui-skills`, `frontend-dev`, dan `frontend-skill` yang tersedia adalah katalog, bukan bundle workflow penuh; tidak mengklaim menjalankan tool yang tidak tersedia.

## Peninjauan render

Screenshot sebelum dan sesudah memakai fixture yang sama. Render normal dan teks besar diperiksa langsung. Temuan yang diperbaiki berdasarkan gambar: headline panel terlalu dominan dan memecah kata panjang pada 1.8x, pilihan dropdown terpotong, form progres didahului terlalu banyak detail, dan pratinjau terlalu banyak pengantar sebelum kandidat. Headline kini memakai ukuran responsif sebelum textScaler; isi/input tetap mengikuti skala sistem.

[Galeri](studio-fokus-review.html): 17 pasangan versi sebelumnya/Studio Fokus dan 13 state tambahan. Seluruh tautan gambar diperiksa keberadaannya. Hasil lama dipertahankan di screenshots/after-redesign; hasil baru di screenshots/studio-fokus.

## Hasil verifikasi

- `flutter test --no-pub test/planner test/ui test/data --reporter expanded --dart-define=CAPTURE_UI=true --dart-define=CAPTURE_DIR=docs/design/screenshots/studio-fokus`: **55 tes lulus**.
- Cakupan: 360/412 dp, teks 1.0/1.8, landscape 800x412, keyboard inset, Tab email-ke-password, semua varian form waktu, register/confirmation, CRUD dan delete confirmation, preview stale, sesi terminal, progres, adapter cache/API serta scheduler.
- Uji kontras meliputi teks biasa, primary, status, foreground lime/forest dan foreground panel. Teks >=4.5:1 dan outline kontrol >=3:1.
- `flutter analyze --no-pub`: **No issues found**.
- `dart format --output=none --set-exit-if-changed lib test integration_test`: **41 file, 0 perubahan**.
- `git diff --check`: **lulus**.
- `flutter run --no-pub -d chrome --web-port 8260`: **main berhasil berjalan dan debug service aktif**.
- `flutter build apk --release`: **berhasil, 57.8 MB**. Salinan bernama `build/app/outputs/flutter-apk/WaktuTugas-StudioFokus.apk` memiliki SHA256 identik dengan app-release.apk. Konfigurasi signing existing memakai debug key, jadi artefak ini untuk demonstrasi/tes lokal.
- Percobaan `--release --no-pub` sebelumnya gagal karena GeneratedPluginRegistrant.java masih memuat integration_test dari mode debug. Sumber tooling Flutter menunjukkan --no-pub melewati regeneratePlatformSpecificTooling. Build normal tanpa --no-pub meregenerasi registrasi sesuai release dan berhasil. Tidak mengedit registrant, build config, pubspec atau lockfile sebagai workaround.

## Batas

Render menggunakan Flutter test renderer dan font asli, bukan screenshot Android fisik. Keyboard inset/key event bukan IME Android nyata. Belum ada perangkat Android pada flutter devices, sehingga TalkBack, gesture/sentuhan, keyboard, safe area OS serta smoke test instalasi Android belum diuji. Backend hidup, RLS/RPC production dan release signing/distribusi tidak diverifikasi ulang. Keberhasilan build tidak berarti penerimaan perangkat/backend lulus.
