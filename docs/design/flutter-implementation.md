# Implementasi Flutter - Studio Fokus

Sistem final: [DESIGN.md](DESIGN.md). Tidak ada dependency tambahan.

- `lib/app/theme.dart`: token ivory/pinus/lime, tipografi 30/32, state kontrol Material 3, dock NavigationBar dan transisi aksesibel.
- `lib/app/router.dart`: logo jam dan nama aplikasi, dock gelap mengambang; keempat branch dan route tetap sama.
- `lib/features/shared.dart`: FocusPanel yang dipakai ulang, lembar PaperCard, tombol primary/secondary/highlighted, agenda SessionCard adaptif, input dan footer.
- `lib/features/home`: fokus/sesi/tindakan di panel utama; agenda dan tenggat pada kertas.
- `lib/features/tasks`: lembar tugas dengan judul lebar penuh serta footer tambah; form memakai lembar input tersendiri.
- `lib/features/time`: kapasitas pinus, pengaturan izin/kegiatan dan interval bersih; dropdown intrinsik mendukung label panjang.
- `lib/features/schedule`: panel agenda dan usulan, status kandidat dan kekurangan eksplisit; aksi sesi dipindah ke footer, form progres diprioritaskan saat aktif.
- `lib/features/auth`: panel identitas dan form konsisten; kemampuan auth/demo tidak ditambah.

Pengambilan screenshot:

```powershell
flutter test --no-pub test/ui/figma_screens_test.dart --dart-define=CAPTURE_UI=true --dart-define=CAPTURE_DIR=docs/design/screenshots/studio-fokus
```

Fixture dan jam demo sama dengan versi sebelum redesign. Render test memakai font asli; tidak menggantikan perangkat Android. Lihat [audit](studio-fokus-audit.md).

Build demonstrasi: `flutter build apk --release`. Jalankan tanpa --no-pub setelah berpindah dari debug agar tooling meregenerasi registrasi plugin menurut mode release. Artefak memakai konfigurasi signing debug existing, untuk tes lokal.
