# Implementasi Flutter dari Figma

Sumber: [WaktuTugas](https://www.figma.com/design/wWnyqoHoqAH0VG075QaecB/Untitled), diperiksa 9 November 2026.
Daftar enam halaman, 18 frame utama, dan 34 state ada di [figma-inventory.md](figma-inventory.md).

## Tahapan yang diterapkan

1. Memeriksa semua halaman, frame, design context, dan screenshot. Tidak ada respons context sparse.
2. Memusatkan warna aktual Figma, tipografi Plus Jakarta Sans, outline 2 px, radius 12/16, serta shadow solid offset 4 di tema dan widget bersama.
3. Menerapkan Ringkasan, Tugas, Waktu, dan Jadwal dengan navigasi empat tab. Menggunakan data/controller proyek yang sudah ada.
4. Menerapkan tambah/ubah tugas; rentang mingguan/tambahan; aktivitas mingguan/sekali; penutupan bertanggal; pratinjau, alasan kekurangan, detail sesi, dan pencatatan progres.
5. Menerapkan masuk, daftar, konfirmasi/kirim ulang email, demo lokal, dan akun. Layanan Supabase dipakai hanya jika sudah dikonfigurasi; akun/sesi daring tidak dipalsukan oleh UI.
6. Memeriksa empty, pending, error validasi, gagal/hasil simpan tidak pasti, loading, offline read-only, pratinjau kedaluwarsa, dan sesi mendatang/terminal melalui kondisi runtime. Frame state dipetakan ke layar yang sama, bukan ditambahkan sebagai data produksi.

## Komponen bersama

`lib/features/shared.dart`: PageContent (scroll dan aksi bawah), PageHeading, PaperCard, AppButton, DesignIcon, Notice, ErrorNotice, StatusBadge, SessionCard, StudyIllustration, EmptyState, FormActions, PickerField, ResponsiveFields.

AppButton menggunakan feedback tekan 2 px, 120 ms easeOutCubic, kembali ke posisi awal ketika dilepas. Spatial motion dimatikan ketika disableAnimations aktif. Tidak ada animasi dekoratif berulang.

43 SVG hasil ekspor Figma tersimpan lokal di assets/figma; 33 nama aset direferensikan kode, termasuk varian ukuran ikon field/navigasi. Tidak ada URL aset sementara Figma pada kode runtime. Font variable Plus Jakarta Sans dan OFL dibundel di assets/fonts. flutter_svg ditambahkan untuk merender aset vektor asli.

## Penyesuaian terhadap aplikasi

- Fixture/controller lama dipertahankan: tiga tugas dengan total 540 menit, kapasitas 420 menit, dan kekurangan T03 120 menit. Judul panjang dari fixture proyek menggantikan contoh pendek Figma. Ringkasan awal tidak menampilkan sesi terkonfirmasi yang belum benar-benar disimpan.
- Revisi/tanggal/jumlah sesi selalu berasal dari data. Teks path seperti `/task/new` yang merupakan anotasi handoff Figma tidak ditampilkan sebagai copy produk.
- Status bar, gesture area, keyboard, date picker, dan time picker memakai perilaku platform/Material. Screenshot widget tidak memuat status bar OS.
- Saat hasil simpan tugas tidak pasti, simpan ulang dinonaktifkan dan pengguna diarahkan memuat daftar terbaru untuk menghindari duplikasi.
- API proyek menyimpan penutupan satu tanggal per entri. Pilihan rentang menyimpan tanggal secara berurutan, mempertahankan input dan menghitung tanggal berhasil bila sebagian gagal. Entri tersebut diedit/dihapus satu per satu pada Waktu. Ini bukan transaksi batch atomik.
- Perbaikan adapter minimal: entri waktu/aktivitas baru mengirim ID null agar server membuat UUID; edit tetap mengirim ID yang sudah ada. Diuji dengan API pengganti, tanpa mengubah schema/RPC.

## Bukti validasi

- `flutter analyze`: tidak ada issue.
- `flutter test test/planner test/ui --dart-define=CAPTURE_UI=true`: 41 tes lulus pada pemeriksaan gabungan.
- Pemeriksaan render terakhir setelah penambahan layar alasan: 10 tes UI lulus.
- `flutter build apk --debug`: APK di `build/app/outputs/flutter-apk/app-debug.apk` berhasil dibuat. PowerShell mencatat peringatan native-access Java sebagai NativeCommandError, tetapi Gradle selesai dan Flutter mengonfirmasi artefak APK.
- Render 360 dan 412 dp, skala teks 100% dan 180%, aksi di atas inset keyboard 280 px; navigasi lanskap dan reduced motion.
- Alur tambah/edit/validasi/hapus, pratinjau/konfirmasi/progres, registrasi/konfirmasi email dengan test double, offline/loading, stale preview, dan sesi terminal.
- Seluruh aset yang direferensikan memiliki file lokal; 43 SVG valid dan mempertahankan dimensi root.
- Kontras ink #171717 terhadap canvas/lime/cyan/lilac/warning dihitung 17,57 / 15,53 / 14,34 / 11,36 / 14,30 : 1.
- Screenshot aktual: [screenshots](screenshots/), antara lain [Ringkasan](screenshots/home-412-1.0.png), [Tugas](screenshots/tugas-412-1.0.png), [Pratinjau](screenshots/preview-412-1.0.png), [Form tugas](screenshots/task-form-412-1.0.png), dan [teks besar dengan keyboard](screenshots/task-keyboard-360-1.8.png).

50 screenshot implementasi tersedia. Sampel render diperiksa secara visual terhadap screenshot Figma: warna, ilustrasi, outline, bayangan, hierarki, dan posisi aksi. Tidak diklaim pixel-identical: data/state awal, anotasi handoff, inset OS, serta label/picker Material berbeda. Belum ada perbandingan pixel otomatis pada semua 52 frame.

Tes backend penuh memerlukan Supabase lokal dan dua akun uji terpisah. Percobaan `flutter test` penuh berhenti pada konfigurasi SUPABASE_URL yang tidak tersedia; tes itu tidak dianggap lulus atau diam-diam dilewati. Auth daring, cache perangkat, dan integration test pada Android fisik belum dijalankan. Hasil analisis/build dicatat pada file results di folder ini.
