# WaktuTugas — Playful Lime

Arahan desain berdasarkan gambar referensi pengguna `download (12).jpg`. Nilai warna, ukuran, dan font di bawah adalah spesifikasi usulan, bukan hasil pengukuran gambar. Menggantikan arahan visual hijau lama untuk desain baru; aturan produk tetap mengikuti PRD 1.2. Kode aplikasi belum diubah.

## 1. Visual Theme & Atmosphere
Playful neobrutalism: latar krem, aksen lime terang, outline hitam, bayangan keras, ilustrasi pastel, dan doodle kecil. Ramah mahasiswa, dengan informasi tugas dan waktu sebagai fokus.

## 2. Color
- canvas: #FFFDF2; surface: #FFFFFF; ink: #171717.
- primary: #D7FF00, selalu dengan teks ink.
- illustration accents: cyan #A7E8F5, lilac #CBBEFF, pink #FFBEDD.
- error text: #B3261E di canvas; success text: #245D3A di canvas.
- Pastel hanya dekorasi atau latar; status selalu disertai teks dan ikon. Periksa kontras sebelum handoff.
- Lime memenuhi latar board presentasi; layar aplikasi tetap dominan krem.

## 3. Typography
Usulan: Plus Jakarta Sans, satu keluarga dengan fallback sans-serif. Judul 28/34 bold, section 20/28 bold, body 16/24 regular, label 14/20 medium. Ini pilihan desain, belum font terpasang. Ukuran dalam logical pixels untuk handoff Flutter; dukung pembesaran teks tanpa clipping.

## 4. Spacing & Grid
Baseline Android 412 × 915; validasi juga lebar 360. Padding horizontal 20; skala jarak 4, 8, 12, 16, 20, 24, 32. Area sentuh minimal 48 × 48. Safe area dan keyboard diperhitungkan; tinggi konten mengikuti isinya.

## 5. Layout & Composition
Empat tab Ringkasan, Tugas, Waktu, Jadwal. Konten vertikal; agenda dikelompokkan per tanggal. Formulir, autentikasi, pratinjau, dan detail sesi di luar shell tab. Satu tindakan utama jelas per layar. Doodle di ruang kosong, tidak di belakang teks atau formulir. Jangan membuat onboarding tambahan hanya untuk meniru referensi.

## 6. Components
Card: fill krem/putih, stroke ink 2, radius 16, shadow solid ink offset (4,4), blur 0. Tombol utama: lime, stroke ink 2, radius 12, min-height 52. Field: fill putih, stroke ink 2, radius 12, label permanen; error dekat field. Status berupa teks dan ikon dengan pastel lembut. NavigationBar krem dengan indikator lime; tab aktif juga dibedakan bentuk/weight. Dialog hapus memakai Batal dan tindakan destruktif eksplisit. Pending, disabled, focused, error, empty, offline, stale, read-only harus memiliki varian relevan.

## 7. Motion & Interaction
Usulan feedback tekan 100–150 ms: tombol bergeser 2 px menuju bayangan. Transisi sederhana, tanpa animasi dekoratif berulang; hormati reduced motion. Feedback tidak mengubah ukuran layout atau menyembunyikan status simpan.

## 8. Voice & Brand
Bahasa Indonesia jelas dan mendukung. Contoh: “Ruang untuk fokus”, “120 menit belum tertampung”, “Periksa rencana Anda”. Semua jam WIB. Bedakan sesi selesai dari tugas selesai, pratinjau dari jadwal tersimpan, dan di luar jendela dari kekurangan kapasitas. Ilustrasi orisinal bertema buku, pensil, jam, kalender, atau tas kuliah.

## 9. Anti-patterns
Hindari soft shadow blur, glassmorphism, neon glow, gradasi pada panel data, teks pastel berkontras rendah, doodle di bawah teks, serta card bertumpuk pada daftar yang harus dibaca. Jangan menyalin NFT, harga ETH, wallet, bidding, avatar, atau karya ilustrasi referensi. Jangan menambahkan AI chat, drag-and-drop, notifikasi, atau fitur di luar MVP. Jangan memalsukan auth atau offline yang belum tersedia.
