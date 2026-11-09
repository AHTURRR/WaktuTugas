# Prompt desain dan implementasi

Buat UI Android WaktuTugas di Figma dengan style Playful Lime sesuai gambar referensi pengguna: playful neobrutalism, canvas krem, aksen lime, outline hitam, hard shadow tanpa blur, ilustrasi pastel orisinal, dan doodle secukupnya. Gunakan token dan aturan docs/design/DESIGN.md; nilainya adalah keputusan desain, bukan hasil sampling gambar.

Baca PRD_WaktuTugas_Ahmad_Turmudi_60324069.md dan docs/design/design-contract.md. Semua kebutuhan layar, navigasi, validasi, state, aturan penjadwalan, dan batas MVP dalam PRD tetap berlaku. Arahan visual ini menggantikan warna hijau dan styling visual prompt sebelumnya. Jangan mengadopsi fitur NFT dari referensi.

Buat Ringkasan, Tugas, tambah/ubah tugas, Waktu beserta formulir rentang/kegiatan/penutupan, Jadwal, Pratinjau, Detail/Progres sesi, dan Masuk/Daftar. Pisahkan varian demo lokal dari target MVP. Lengkapi empty, loading, validation error, pending, save failed, offline read-only, stale preview, dan sesi terminal sesuai relevansi. Input tetap ada saat simpan gagal; riwayat tetap ada saat susun ulang; hapus tugas menjelaskan penghapusan sesi terkait.

Gunakan frame utama 412 × 915 dan periksa lebar 360, safe area, font besar, serta keyboard. Gunakan Auto Layout, variables, text styles, component instances, dan prototype alur utama. Sertakan halaman Tokens, Components, Screens, States, dan Handoff. Aset ilustrasi bertema belajar dibuat orisinal; jangan menyalin karya pada gambar. Jangan mengandalkan gambar raster untuk seluruh layar atau komponen.

Artifact pertama harus membuktikan Ringkasan, Tugas, dan Pratinjau dengan fixture PRD: total sisa 540 menit, kapasitas bersih 420 menit, T03 belum tertampung 120 menit. Lanjutkan seluruh layar yang dibutuhkan. Periksa teks/status dapat dipahami tanpa warna dan kontras memenuhi kebutuhan aksesibilitas.

Untuk implementasi Flutter, baca lib/app/theme.dart, lib/app/router.dart, lib/features/shared.dart, dan layar terkait di lib/features/. Gunakan widget Material 3 dan controller yang ada. Pusatkan token tema; jangan mengubah planner/backend untuk mengejar style. Font Plus Jakarta Sans belum terpasang: bundel secara benar saat implementasi dan pertahankan fallback jika belum tersedia. Dokumen ini sendiri tidak memasang font.

Lampirkan URL Figma beserta node layar pada instruksi implementasi. AI harus membaca node dan screenshot, lalu membandingkan screenshot Flutter pada viewport, data, state, dan text scale sama. Jika tidak dapat mengakses Figma, laporkan batas tersebut. Jangan mengklaim kesesuaian persis sebelum perbandingan visual. Perubahan Figma tidak otomatis tersinkron ke kode.
