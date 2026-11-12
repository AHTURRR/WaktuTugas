# Design system WaktuTugas

**Status** — Rancangan untuk persetujuan. Penerapan atau penyesuaian kode dalam tahap ini dimulai setelah pengguna menyetujui dokumen.

WaktuTugas membantu pelajar dan mahasiswa mengenali tugas yang perlu dikerjakan, membaca tenggat, dan menyusun jadwal. Arah visualnya modern minimalis dengan hierarki profesional dan aksen playful yang ringan. Gunakan panel pinus untuk satu fokus utama per layar, kartu sederhana untuk membaca daftar, dan lime untuk tindakan utama di panel serta tab aktif. Pertahankan ikon SVG outline dan karakter hangat Studio Fokus.

## Struktur proyek dan batas perubahan

WaktuTugas memakai **Flutter, Dart, Material 3, dan `go_router`**. Tampilan didefinisikan melalui widget dan `ThemeData`.

| Lokasi | Peran dalam desain |
| --- | --- |
| `lib/app/` | Tema global, shell aplikasi, navigasi bawah, dan sidebar. Gunakan kembali `AppColors`, `AppTypography`, `AppLayout`, dan `AppMotion`. |
| `lib/features/` | Ringkasan, daftar dan form tugas, pengaturan waktu, jadwal dan progres, login, serta akun. `shared.dart` menyediakan komponen lintas layar. |
| `assets/fonts/`, `assets/figma/` | Font dan ikon yang sudah dibundel. |
| `lib/state/`, `lib/planner/`, `lib/data/` | Pengelolaan sesi, tugas, jadwal, dan penyimpanan. Tampilan membaca status dari lapisan ini dan memakai tindakan yang sudah tersedia. |
| `test/ui/`, `integration_test/` | Pengujian tema, tata letak, navigasi, formulir, dan alur aplikasi. |

Working tree saat ditinjau sudah memuat token, daftar tugas, form, navigasi adaptif, dan pilihan tema dari pengerjaan sebelumnya. Jadikan itu titik awal. Setelah persetujuan, periksa setiap tahap terhadap rancangan ini dan ubah hanya bagian visual yang masih berbeda. Pertahankan alur aksi, validasi, data, aturan tenggat dan status, serta perhitungan jadwal. Gunakan aset dan paket yang tersedia. Penambahan dependensi memerlukan izin terpisah.

## Warna

Gunakan token yang sama di kedua mode dengan nilai berbeda sesuai tabel. Pilihan awal yang diusulkan adalah mengikuti tema sistem. Gunakan aksen semantik secara lokal pada badge, pesan, dan tindakan destruktif. Teks dan ikon status selalu menyertai warna. Warna batas `outline` digunakan saat garis diperlukan untuk mengenali sebuah kontrol.

| Token | Terang | Gelap | Penggunaan |
| --- | --- | --- | --- |
| `canvas` | `#F7F5ED` | `#101815` | Latar halaman |
| `surface` | `#FFFEFA` | `#17231E` | Kartu, input, dialog |
| `surfaceMuted` | `#EBEDE2` | `#22312A` | Latar sekunder, kontrol nonaktif |
| `ink` | `#203A32` | `#EEF4EC` | Teks utama |
| `inkSecondary` | `#4D5F54` | `#C1CEC5` | Teks sekunder dan ikon |
| `inkMuted` | `#53624F` | `#A6B7AC` | Metadata, helper, dan teks nonaktif |
| `border` | `#DFE3D5` | `#34463D` | Pemisah dekoratif dan kartu statis |
| `outline` | `#73816B` | `#829588` | Batas kontrol aktif |
| `primary` | `#285847` | `#A5D3B6` | Isi tombol utama dan teks aksi pada surface |
| `onPrimary` | `#FFFEFA` | `#11261B` | Teks dan ikon tombol utama |
| `primaryPressed` | `#1B4334` | `#8CB99D` | Isi tombol utama saat ditekan |
| `primarySoft` | `#EAF0DF` | `#263D31` | Isi sekunder saat ditekan atau dipilih |
| `onPrimarySoft` | `#203A32` | `#CDEBD8` | Teks dan ikon di atas primarySoft |
| `accent` | `#D7ED98` | `#D7ED98` | CTA pada panel dan indikator tab aktif |
| `onAccent` | `#183D36` | `#183D36` | Teks dan ikon di atas accent |
| `accentPressed` | `#C7DF83` | `#C7DF83` | Isi CTA panel saat ditekan |
| `panel` | `#183D36` | `#213C32` | Panel fokus |
| `onPanel` | `#EDF3DF` | `#EDF3DF` | Teks dan ikon panel |
| `nav` | `#183D36` | `#132820` | Latar navigasi bawah |
| `onNav` | `#EDF3DF` | `#EDF3DF` | Tab nonaktif |
| `focus` | `#285847` | `#B9E9C9` | Ring fokus pada permukaan biasa |
| `focusOnPanel` | `#D7ED98` | `#D7ED98` | Ring fokus pada panel dan navigasi |
| `infoBg` | `#E3F2FC` | `#1C3544` | Isi badge informasi |
| `infoInk` | `#1B4D6C` | `#B7E1F8` | Teks dan ikon informasi |
| `successBg` | `#DCFCE7` | `#183826` | Isi badge keberhasilan |
| `successInk` | `#166534` | `#A9E6B9` | Teks dan ikon keberhasilan |
| `warningBg` | `#FEF3C7` | `#3C2B16` | Isi badge perhatian |
| `warningInk` | `#92400E` | `#F9D790` | Teks dan ikon perhatian |
| `dangerBg` | `#FEE2E2` | `#472521` | Isi badge bahaya dan latar error |
| `dangerInk` | `#B91C1C` | `#FFC4BC` | Teks dan ikon error serta isi tombol destruktif |
| `dangerPressed` | `#991B1B` | `#F2ABA3` | Isi tombol destruktif saat ditekan |
| `onDanger` | `#FFFEFA` | `#321311` | Teks dan ikon tombol destruktif |

## Tipografi

Gunakan **Plus Jakarta Sans** untuk judul, isi, label, dan formulir. Gunakan **IBM Plex Mono** untuk jam dan durasi yang ditampilkan sejajar, seperti `09:30`, `14:00–15:30`, dan `90 menit`. Gunakan Plus Jakarta Sans untuk tanggal dan tenggat di dalam kalimat. Kedua font sudah dibundel.

| Peran | Font | Ukuran / tinggi baris | Bobot |
| --- | --- | --- | --- |
| Judul panel fokus | Plus Jakarta Sans | 32 / 38 sp | 700 |
| Judul halaman | Plus Jakarta Sans | 28 / 34 sp | 700 |
| Judul bagian | Plus Jakarta Sans | 22 / 28 sp | 700 |
| Judul kartu dan app bar | Plus Jakarta Sans | 18 / 24 sp | 700 |
| Isi dan nilai input | Plus Jakarta Sans | 16 / 24 sp | 400 |
| Teks sekunder | Plus Jakarta Sans | 14 / 20 sp | 400 |
| Label tombol dan input | Plus Jakarta Sans | 14 / 20 sp | 600 |
| Badge, metadata, label tab | Plus Jakarta Sans | 12 / 16 sp | 600 |
| Jam dan durasi sejajar | IBM Plex Mono | 14 / 20 sp | 500 |

Biarkan judul, label, dan pesan kesalahan membungkus. Hormati skala teks sistem pada isi, kontrol, dan metadata. Untuk kartu sesi pada lebar sempit atau teks besar, letakkan blok waktu di atas detail. Gunakan format 24 jam dan tampilkan konteks WIB pada jadwal dan tenggat.

## Spasi, radius, dan bayangan

| Token | Nilai | Penggunaan |
| --- | --- | --- |
| Spasi | 4, 8, 12, 16, 20, 24, 32, 48 dp | 4–8 untuk ikon dan label, 12 antarinput atau kartu, 16 padding kartu, 20 gutter ponsel, 24 antarbagian, 32–48 untuk blok besar |
| Lebar konten | Maksimum 560 dp | Konten terpusat. Pada lebar di bawah 360 dp gunakan gutter 16 dp, pada 600 dp ke atas gunakan 24 dp |
| Radius kontrol | 12 dp | Tombol dan input |
| Radius kartu | 20 dp | Kartu tugas dan sesi |
| Radius navigasi dan dialog | 24 dp | Wadah navigasi bawah dan dialog |
| Radius panel | 28 dp | Panel fokus |
| Radius kapsul | 999 dp | Badge dan indikator tab |
| `shadow.none` | Offset 0, blur 0, spread 0 | Kartu, tombol, input, dan navbar |
| `shadow.overlay` | Offset (0, 8), blur 24, spread 0 dp | Dialog atau menu mengambang, warna `#183D36` 16% di terang dan `#000000` 48% di gelap |

Target sentuh minimal **48 × 48 dp**. Jarak antarkontrol berdekatan 8 dp bila ruang memungkinkan. Gunakan safe area untuk app bar, navigasi bawah, dan footer formulir. Area gulir harus tetap memberi akses ke isi terakhir ketika keyboard terbuka.

## Komponen

### Tombol

| Varian | Normal | Ditekan |
| --- | --- | --- |
| Utama | `primary` + `onPrimary` | `primaryPressed` + `onPrimary` |
| Utama di panel | `accent` + `onAccent` | `accentPressed` + `onAccent` |
| Sekunder | `surface` + `ink`, batas `outline` 1 dp | `primarySoft` + `onPrimarySoft` |
| Teks | `primary` pada `surface` | `primarySoft` + `onPrimarySoft` |
| Destruktif | `dangerInk` + `onDanger` | `dangerPressed` + `onDanger` |

Tinggi minimum 48 dp, 56 dp untuk CTA halaman, padding horizontal 16 dp, dan jarak ikon–label 8 dp. Saat memuat, tampilkan indikator dan label seperti **Menyimpan…** sambil mencegah submit ganda. Saat nonaktif, gunakan `surfaceMuted` + `inkMuted` dan jelaskan penyebab jika diperlukan, misalnya pada mode luring. Fokus keyboard memakai ring 2 dp dengan celah 2 dp berwarna permukaan sekitar agar tetap terlihat pada tombol berisi warna.

### Kartu

Kartu standar memakai `surface`, garis `border` 1 dp, radius 20 dp, padding 16 dp, dan jarak 12 dp antarkartu. Urutan kartu tugas adalah judul, mata kuliah jika ada, tenggat, lalu sisa estimasi. Kartu sesi mendahulukan jam, judul tugas, durasi, dan status. Untuk kartu yang dapat diketuk, gunakan umpan balik Material dan ring fokus. Aksi seperti edit atau hapus memiliki label aksesibel dan area sentuh tersendiri. Panel fokus memakai `panel` + `onPanel`, padding 24 dp, dan maksimal satu CTA dominan.

### Input

Tinggi minimum 56 dp dengan ruang tumbuh mengikuti teks, radius 12 dp, dan padding 16 dp. Gunakan `surface` + `ink`, label persisten `inkSecondary`, serta batas `outline` 1 dp. Fokus memakai `focus` 2 dp. Error memakai `dangerInk` pada batas dan pesan inline di bawah kolom. Pertahankan nilai yang sudah diisi dan arahkan fokus ke kesalahan pertama setelah submit gagal. Helper memakai `inkMuted`. Input nonaktif memakai `surfaceMuted` + `inkMuted`. Picker tanggal dan jam memakai pola yang sama dengan label dan nilai WIB yang jelas.

### Badge status dan tenggat

Gunakan kapsul dengan tinggi minimum 24 dp, padding horizontal 8 dp dan vertikal 4 dp, ikon 14–16 dp, serta jarak ikon–label 4 dp. Badge informasional tumbuh mengikuti teks. Jika kelak dapat diketuk, target sentuhnya tetap 48 dp.

| Label | Isi / teks dan ikon | Makna |
| --- | --- | --- |
| Usulan, Direncanakan | `infoBg` / `infoInk` | Usulan pratinjau dan sesi tersimpan memakai label masing-masing |
| Selesai, Terkonfirmasi | `successBg` / `successInk` | Sesi selesai, tugas dengan sisa 0, atau jadwal yang sudah tersimpan sesuai konteks |
| Hari ini, Terlewat, Perlu ditinjau | `warningBg` / `warningInk` | Tenggat hari ini, sesi terlewat, atau jadwal perlu ditinjau |
| Mendatang, Dalam proses | `infoBg` / `infoInk` | Tenggat mendatang atau tugas yang memiliki progres sesi |
| Terlambat | `dangerBg` / `dangerInk` | Tenggat sudah lewat dan tugas masih punya sisa |
| Belum mulai, Dibatalkan | `surfaceMuted` / `inkMuted` | Status netral dengan label eksplisit |

Tampilkan tanggal dan jam aktual. Urutkan kelompok daftar sesuai klasifikasi yang ada: **Terlambat**, **Hari ini** menurut kalender WIB, **Mendatang**, lalu **Tugas selesai**. Gunakan ikon dan label untuk setiap kelompok, serta badge terpisah untuk status pengerjaan. Sesi selesai dan tugas selesai tetap mengikuti kondisi masing-masing. Pertahankan aksi tambah, edit, hapus, dan centang selesai yang sudah tersedia.

### Navigasi adaptif

Empat tujuan sesuai aplikasi saat ini, **Ringkasan**, **Tugas**, **Waktu**, dan **Jadwal**. Pada lebar di bawah 900 dp gunakan navigasi bawah dengan tinggi minimum 72 dp di luar safe area. Mulai 900 dp gunakan sidebar berlabel dan pertahankan tab terpilih saat lebar berubah. Gunakan `nav` untuk wadah, radius 24 dp, dan ikon 22–24 dp. Tab aktif memakai kapsul `accent` dengan ikon `onAccent`, label `accent` berbobot 700, dan semantik terpilih. Tab lain memakai `onNav`. Seluruh item menjadi target sentuh. Label selalu terlihat dan bar boleh tumbuh saat teks diperbesar. Fokus pada navigasi dan panel memakai `focusOnPanel` dan dapat dibedakan dari indikator tab aktif.

### Mode gelap dan gerak

Gunakan pilihan yang sudah tersedia di **Akun Anda → Tampilan**: **Ikuti sistem**, **Terang**, dan **Gelap**. Terapkan token semantik pada seluruh permukaan, input, dialog, serta status di kedua tema. Gunakan transisi 160 ms untuk hover dan dialog, serta centang Material yang singkat. Saat pengurangan animasi aktif, tampilkan keadaan akhir langsung.

## Urutan penerapan setelah persetujuan

| Tahap | Pekerjaan visual | Syarat untuk melanjutkan |
| --- | --- | --- |
| 1. Token global | Selaraskan tema, tipografi, spasi, radius, dan komponen bersama. | Pasangan warna yang digunakan lulus pengukuran; ukuran kontrol dan teks mengikuti token. |
| 2. Daftar tugas | Selaraskan hierarki tenggat, kartu, badge, dan posisi aksi yang ada. | Status terbaca tanpa warna; daftar tetap dapat digunakan saat kosong, memuat, atau luring. |
| 3. Form | Susun detail, tenggat, dan estimasi; selaraskan bantuan dan pesan error. | Fokus keyboard terlihat; isian tetap terbaca saat teks membesar atau keyboard terbuka; aturan simpan yang ada lulus tes regresi. |
| 4. Navigasi | Selaraskan navbar dan sidebar, safe area, target sentuh, dan fokus. | Keempat tujuan dapat dicapai dengan sentuhan dan keyboard; pilihan tab bertahan saat ukuran berubah. |
| 5. Dark mode | Periksa token gelap, preferensi tema, serta pengurangan animasi. | Setiap pilihan tema memakai palet yang benar; status dan fokus terbaca pada kedua tema. |

## Aksesibilitas dan verifikasi

- Pasangkan status dengan label dan ikon yang bermakna. Ikon dekoratif di samping teks dapat dilewati pembaca layar. Kontrol ikon mandiri memiliki nama yang dibaca TalkBack.
- Gunakan umpan balik tekan bawaan Material tanpa mengubah ukuran. Transisi visual 150–200 ms dan mengikuti pengaturan pengurangan animasi sistem.
- Uji kedua tema pada **375, 768, dan 1280 dp**, serta lanskap. Pada web, periksa reflow pada lebar 320 CSS px dan pembesaran teks hingga 200%. Pastikan isi dan aksi tetap dapat dijangkau tanpa gulir horizontal untuk konten biasa. [Reflow WCAG](https://www.w3.org/WAI/WCAG22/Understanding/reflow.html)
- Telusuri alur dengan Tab, Shift+Tab, dan Enter. Pastikan fokus terlihat dan tidak tertutup sepenuhnya oleh navigasi atau footer yang menetap. Periksa label, urutan baca, dan pengumuman error dengan TalkBack sebelum menyatakan pemenuhan WCAG AA. [Fokus terlihat](https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html) · [Fokus tidak tertutup](https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html)

Rasio berikut dihitung dari nilai sRGB solid di tabel. WCAG 2.2 AA menetapkan **4,5:1** untuk teks biasa serta **3:1** untuk teks besar dan indikator visual yang diperlukan. `border` bersifat dekoratif. Ukur ulang warna yang benar-benar dirender, termasuk saat hover, fokus, dan dialog terbuka. Tabel token saja belum cukup untuk menyatakan aplikasi memenuhi WCAG AA. [Kontras teks](https://www.w3.org/TR/WCAG22/#contrast-minimum) · [Kontras nonteks](https://www.w3.org/TR/WCAG22/#non-text-contrast)

| Pasangan warna | Terang | Gelap | Target |
| --- | ---: | ---: | ---: |
| `ink` / `surface` | 12.15 | 14.50 | 4.5 |
| `inkSecondary` / `surface` | 6.76 | 9.96 | 4.5 |
| `inkMuted` / `surfaceMuted` | 5.50 | 6.48 | 4.5 |
| `onPrimary` / `primary` | 8.07 | 9.56 | 4.5 |
| `onPrimary` / `primaryPressed` | 10.96 | 7.25 | 4.5 |
| `onPrimarySoft` / `primarySoft` | 10.53 | 9.18 | 4.5 |
| `onAccent` / `accent` | 9.35 | 9.35 | 4.5 |
| `onAccent` / `accentPressed` | 8.13 | 8.13 | 4.5 |
| `onPanel` / `panel` | 10.51 | 10.52 | 4.5 |
| `onNav` / `nav` | 10.51 | 13.67 | 4.5 |
| `accent` / `nav` | 9.35 | 12.17 | 4.5 |
| `infoInk` / `infoBg` | 7.90 | 9.22 | 4.5 |
| `successInk` / `successBg` | 6.49 | 9.01 | 4.5 |
| `warningInk` / `warningBg` | 6.37 | 9.78 | 4.5 |
| `dangerInk` / `dangerBg` | 5.30 | 8.93 | 4.5 |
| `onDanger` / `dangerInk` | 6.41 | 11.22 | 4.5 |
| `onDanger` / `dangerPressed` | 8.23 | 9.00 | 4.5 |
| `dangerInk` / `surface` | 6.41 | 10.71 | 4.5 |
| `outline` / `surface` | 4.10 | 5.10 | 3.0 |
| `outline` / `surfaceMuted` | 3.49 | 4.29 | 3.0 |
| `focus` / `surface` | 8.07 | 12.01 | 3.0 |
| `focusOnPanel` / `panel` | 9.35 | 9.37 | 3.0 |
| `focusOnPanel` / `nav` | 9.35 | 12.17 | 3.0 |

Acuan visualnya adalah [Studio Fokus](design/DESIGN.md). Rekomendasi Flat Design dari UI/UX Pro Max mendukung permukaan sederhana, status dengan ikon dan teks, serta gerak singkat. Palet dan font mengikuti identitas Studio Fokus yang sudah ada.
