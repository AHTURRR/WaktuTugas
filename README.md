# WaktuTugas — demo lokal Flutter

Implementasi Task 1–3 dari [rencana](docs/Rencana_Implementasi_WaktuTugas.md), berdasarkan [PRD 1.2](PRD_WaktuTugas_Ahmad_Turmudi_60324069.md). Target aplikasi Android. Data sintetis hanya berada di memori; keluar/restart mengembalikan fixture. Tidak ada proyek cloud, kredensial, atau persistensi token yang diaktifkan.

## Toolchain yang ditemukan

- Flutter 3.44.8 stable; Dart 3.12.2 (bundel Flutter).
- Android SDK 36.0.0, platform android-36.1, build tools 36.0.0; lokasi D:/Android/Sdk.
- Flutter doctor memilih Java Android Studio JBR 25.0.3. Template mengompilasi Java/Kotlin untuk Java 17; kompatibilitas Gradle belum dibuktikan dengan build Android.
- minSdk 24 dari flutter.minSdkVersion; persyaratan seluruh plugin perlu diverifikasi saat build Android.
- Tidak ada perangkat Android/AVD. Sebagian lisensi Android belum diterima. Visual Studio tidak diperlukan untuk target Android.

## Menjalankan

Dari root workspace:

```powershell
flutter pub get
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test integration_test
flutter devices
flutter run -d <id-perangkat-android>
```

Untuk lisensi, jalankan sendiri `flutter doctor --android-licenses`, baca setiap lisensi dan jawab `y` jika menyetujui. Lalu `flutter doctor -v`. Siapkan emulator dari Android Studio > Device Manager atau sambungkan ponsel dengan USB debugging, lalu periksa `flutter devices`.

Dependensi PRD dikunci di pubspec.lock. Jangan upgrade saat build. SDK Supabase, secure storage, SQLite, dan konektivitas sudah dideklarasikan untuk tahap selanjutnya tetapi belum diinisialisasi/dipakai. Tidak ada token disimpan melalui SharedPreferences.

## Tinjauan

Buka demo lokal. Fixture memakai 9 November 2026 pukul 18.00 WIB, bukan jam perangkat. T01 240 menit, T02 120 menit, T03 180 menit; kapasitas bersih 420 menit. Implementasi dan hasil pengujian per tahap dicatat di [progress](docs/PROGRESS.md).

Android smoke test, plugin nyata, APK, keamanan/RLS dan transaksi backend belum diverifikasi. Signing release masih template debug dan bukan konfigurasi rilis produksi.
