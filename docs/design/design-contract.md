# Kontrak desain WaktuTugas

Target: UI Android di Figma dan handoff Flutter untuk mahasiswa, sesuai PRD 1.2.

## Bukti
| Sumber | Kepastian | Penggunaan |
| --- | --- | --- |
| Gambar pengguna download (12).jpg | observed | Lime, krem, outline hitam, hard shadow, pastel, doodle |
| Permintaan pengguna mengikuti style gambar | provided | Mengganti arahan visual sebelumnya |
| PRD 1.2 dan kode Flutter yang dibaca | provided | Empat tab, formulir, pratinjau, progres, batas MVP |
| Nilai hex, radius, font, dan ukuran pada DESIGN.md | inferred | Token usulan untuk konsistensi implementasi |

## Batas referensi
| Keep | Change | Do not copy |
| --- | --- | --- |
| Outline, hard shadow, krem, lime, aksen pastel, doodle | NFT menjadi tugas/kegiatan/sesi; ilustrasi menjadi alat belajar; komposisi mengikuti data aplikasi | Logo, karya ilustrasi, avatar, teks NFT, ETH, bidding |

## Keputusan
Satu arah: Playful Lime neobrutalism. Krem mendominasi layar, lime menonjolkan CTA dan pilihan aktif. Ilustrasi hanya mendukung ruang kosong; data dan formulir tetap jelas. Material 3 tetap menjadi dasar perilaku, dengan styling yang mengikuti token baru.

## Risiko dan hal belum diketahui
- Gambar bukan screenshot aplikasi WaktuTugas; tidak menjadi acuan alur atau fitur.
- Token belum diukur dari gambar dan belum diuji kontras pada render final.
- Font dan ilustrasi final belum tersedia; pemasangan font memerlukan langkah implementasi.
- Desain Figma, akses node, dan kesesuaian screenshot belum diperiksa.
- Akun daring/cache offline adalah target PRD; UI sekarang masih demo lokal.

## Quality gate
- [x] Target, pengguna, dan bukti dicatat; interpretasi diberi label.
- [x] Keep/change/do-not-copy dan satu arah visual ditetapkan.
- [x] DESIGN.md memuat sembilan bagian; handoff disediakan.
- [ ] Figma memakai komponen editable, Auto Layout, variables, dan variant.
- [ ] Semua layar/alur PRD dan state penting tercakup tanpa fitur tambahan.
- [ ] Kontras, target sentuh, pembesaran teks, lebar 360, dan keyboard diperiksa.
- [ ] Screenshot Flutter dibandingkan dengan node Figma pada state/data sama.
