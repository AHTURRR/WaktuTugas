# WaktuTugas - Studio Fokus

Acuan tunggal visual Flutter, 10 November 2026. Arah ini menggantikan Modern Productivity biru dan perapian awal. Permintaan pengguna: tentukan desain baru secara mandiri, tanpa meniru referensi produk, dengan isi PRD sebagai batas.

## 1. Tema

Studio Fokus adalah planner mahasiswa dengan karakter hangat, taktil, dan tegas: kertas ivory, panel hijau pinus, aksen lime, headline ekspresif, dan navigasi berupa dock gelap. Komposisi dibangun ulang per fungsi halaman, bukan sekadar mengganti warna tema. Tidak ada gambar, grafik, persentase, atau fitur yang tidak didukung model.

UI/UX Pro Max dipakai melalui pencarian lokal `student planner expressive editorial mobile --design-system` dan `adaptive forms material accessibility --stack flutter`. Prinsip grid, kontras, hierarki dan ColorScheme dipakai. Rekomendasi hero marketing, pola landing page, font unduhan dan palet pink tidak diterapkan. Tidak ada penelusuran atau peniruan produk referensi.

## 2. Palet

Token runtime berada di `lib/app/theme.dart`.

| Peran | Token | Nilai |
| --- | --- | --- |
| Kertas utama | canvas | #F7F5ED |
| Lembar isi | surface | #FFFEFA |
| Latar sekunder | surfaceMuted | #EBEDE2 |
| Panel utama / dock | forest | #183D36 |
| Teks di panel | onForest | #EDF3DF |
| Sorotan / CTA panel / tab aktif | lime | #D7ED98 |
| Teks utama | ink | #203A32 |
| Teks sekunder / helper | inkSecondary / inkMuted | #4D5F54 / #53624F |
| Primary / primaryDark | primary / primaryDark | #285847 / #1B4334 |
| Primary lembut | primarySoft / primaryBorder | #EAF0DF / #CEDDBB |
| Pemisah / kontrol aktif | border / borderStrong | #DFE3D5 / #73816B |
| Selesai | success / successSoft | #15803D / #DCFCE7 |
| Peringatan | warningInk / warningSoft | #92400E / #FEF3C7 |
| Kesalahan | error / errorSoft | #B91C1C / #FEE2E2 |

Lime memakai teks ink/forest, bukan putih. Teks pada pinus memakai surface/onForest/lime. Uji kontras mencakup seluruh pasangan ini, teks biasa >=4.5:1, batas kontrol >=3:1. Tidak ada dark-mode toggle; panel pinus adalah bagian dari satu tema terang.

## 3. Tipografi

Plus Jakarta Sans lokal dipertahankan sebagai aset proyek, bukan sebagai acuan gaya lama. Perbedaan karakter berasal dari skala dan komposisi baru.

| Peran | Ukuran / height | Weight |
| --- | --- | --- |
| Judul panel utama | 32 / 1.12 | 700 |
| Judul panel saat teks besar | 22 sebelum textScaler, tetap diperbesar OS | 700 |
| Judul halaman | 30 / 1.15 | 700 |
| Judul subbagian besar | 23 / 1.2 | 700 |
| Judul tugas / bagian | 18 / 1.35 | 700 |
| Judul sesi | 15 / 1.4 | 600-700 |
| Isi | 14-15 / 1.5-1.6 | 400 |
| Metadata / eyebrow | 12 / 1.45-1.5 | 500-600 |

Headline panel memiliki letter spacing -1. Ukuran headline menyesuaikan saat teks besar agar kata panjang tidak terpecah; textScaler pengguna tetap berlaku. Input, helper dan isi tidak dibatasi skalanya. Status selalu terbaca lewat teks dan ikon.

## 4. Komponen

- `FocusPanel`: panel pinus dengan ikon lime, eyebrow konteks, headline dan footer opsional. Dipakai untuk fokus Ringkasan, kapasitas waktu, agenda, kandidat pratinjau, auth/akun dan identitas sesi. Semua isinya berasal dari konteks atau model halaman.
- `PaperCard`: lembar isi warm white, radius 20, border 1, tanpa bayangan. Mengelompokkan satu tugas, satu sesi, atau bagian formulir. Tidak membuat kartu bertumpuk untuk setiap baris.
- `AppButton`: tinggi minimum 56; primary pinus atau secondary warm white. Varian highlighted memakai lime hanya pada panel pinus. Feedback Material native, tanpa translasi custom.
- `SessionCard`: blok jam di kiri memakai primarySoft; judul dan status di kanan. Pada teks besar, waktu berada di atas detail.
- `PageHeading` dan `SectionHeader`: pengantar serta hierarki halaman, tidak menyamar sebagai kontrol.
- `FormActions`: Simpan selebar konten di atas Batal; tidak menutupi area gulir dan mengikuti keyboard.
- `Notice`, `StatusBadge`, `PickerField`: peran, validator, helper, semantik dan batasan perilaku tetap terjaga.

## 5. Komposisi layar

- **Ringkasan:** panel fokus menampung tanggal, beban nyata, sesi berikutnya atau sesi yang perlu dicatat, serta satu tindakan dominan lime. Agenda hari ini dan tenggat mengikuti di permukaan kertas.
- **Tugas:** headline halaman dan beban ringkas; tiap lembar menempatkan status, nama selebar konten, mata kuliah, tenggat dan durasi, dengan aksi edit/hapus 48 dp. Tambah tugas tetap di footer.
- **Waktu:** panel kapasitas bersih memperlihatkan durasi dan rumus izin dikurangi kegiatan/penutupan. Pengaturan dan rincian interval adalah bagian berbeda di bawahnya.
- **Jadwal:** panel agenda memuat status dan tindakan pratinjau. Kandidat bukan jadwal tersimpan. Agenda dikelompokkan tanggal; kontrol jam demo berada setelah agenda.
- **Pratinjau:** pengantar ringkas menandai usulan belum tersimpan; panel menunjukkan jumlah sesi dan jendela 14 tanggal. Kekurangan, agenda kandidat dan alokasi tetap eksplisit. Peringatan basi tetap memblokir konfirmasi. Konsekuensi simpan berada di footer.
- **Form tugas/waktu:** pengantar editorial singkat di atas satu lembar input. Label permanen, tenggat/jam dikelompokkan, helper dekat input. Dropdown tingginya intrinsik (`isDense: false`, `itemHeight: null`) agar pilihan panjang tidak terpotong pada teks besar.
- **Detail sesi:** identitas dalam panel pinus; waktu dan durasi pada lembar terpisah. Selesai dikerjakan/Tandai terlewat berada di footer. Saat mencatat progres, identitas diringkas dan form sisa aktual didahulukan; pengguna tidak perlu melewati seluruh detail lagi.
- **Auth/akun:** panel identitas yang konsisten, formulir serta tombol nyata di bawahnya. Demo dan penyimpanan sementara tetap dijelaskan secara jujur.
- **Alasan kekurangan:** bagian berdasarkan alasan, dengan label serta teks penjelasan yang tetap membedakan tenggat lewat, kapasitas kurang, dan luar horizon.

## 6. Spasi, bentuk dan kedalaman

Ritme 4/8 dp. Gutter 20, jarak bagian 24, lebar maksimum 560, radius lembar/kontrol 20, panel 28, dock 24. Panel padding 24; konten biasa 16-20. Ikon SVG outline yang sudah tersedia dipakai konsisten. Tidak ada gradient, glassmorphism, shadow berat atau emoji kontrol.

## 7. Interaksi dan aksesibilitas

Target Android minimal 48 x 48 dp. Callback null mempertahankan semantik disabled, dengan penjelasan offline/pending pada konteksnya. Fokus input 2 dp, error inline dan ErrorNotice live region. Isian tidak dibuang ketika gagal. Native Material menangani feedback tekan dan keyboard; transisi halaman serta indikator tab menghormati disableAnimations. SafeArea, resize Scaffold dan footer tersendiri mempertahankan akses isi ketika keyboard muncul.

## 8. Aturan dan batas

PRD tetap mengikat fitur, UTC/WIB, revisi, validasi, cache per akun, controller, route dan scheduler. Empat tab tidak berubah. Selesai sesi bukan otomatis selesai tugas. Tidak mengubah backend, menambah dependency atau mengarang data produksi. Bentuk UI yang atraktif tidak boleh menyamarkan kandidat sebagai hasil simpan.

## 9. Bukti dan panduan berikutnya

Buka `studio-fokus-review.html` untuk perbandingan versi sebelumnya dan Studio Fokus pada fixture yang sama. Screenshot baru ada di `screenshots/studio-fokus/`; hasil lama dipertahankan. Penyesuaian berikutnya harus memakai token ini dan isi PRD, bukan kembali ke sistem biru lama. Catatan pemeriksaan dan batas ada di `studio-fokus-audit.md`.
