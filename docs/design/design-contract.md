# Kontrak desain WaktuTugas - Studio Fokus

Acuan visual tunggal: [DESIGN.md](DESIGN.md). Studio Fokus menggantikan Modern Productivity biru atas permintaan eksplisit pengguna pada 10 November 2026.

- Kertas ivory, panel pinus dan aksen lime; navigasi berupa dock gelap. Seluruh layar menggunakan ThemeData, AppColors dan komponen bersama.
- Tugas, tenggat, menit dan status selalu berasal dari model. Tidak ada persentase atau grafik buatan.
- Empat tab, route, tombol kembali, state, validasi, backend dan scheduler dipertahankan.
- Pratinjau harus berlabel usulan/belum tersimpan; revisi basi tidak dapat dikonfirmasi. Konfirmasi hanya mengganti sesi rencana mendatang.
- Penutupan waktu tidak ditimpa tambahan; waktu kosong tidak otomatis tersedia. Semua tampilan waktu menggunakan WIB.
- Selesai sesi tidak otomatis menyelesaikan tugas; sisa aktual 0 yang menentukan tugas selesai. Sesi terminal tetap hanya baca.
- Target sentuh >=48 dp, kontras teks >=4.5:1, status memakai teks dan ikon. Teks besar, keyboard, reduced motion dan offline tetap didukung.
- Tidak menghapus input ketika gagal; timeout dan hasil simpan tidak pasti tetap melalui jalur controller yang ada.

Bukti visual: [galeri Studio Fokus](studio-fokus-review.html). Batas verifikasi: [audit](studio-fokus-audit.md).
