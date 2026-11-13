# Pengingat tenggat lewat WhatsApp

Pengguna akun daring membuka **Akun Anda → Pengingat WhatsApp**, memasukkan nomor Indonesia berawalan `08` atau `+628`, lalu memasukkan kode dari WhatsApp. Setelah nomor terverifikasi, pengguna dapat mengaktifkan atau mematikan pengingat. Mengganti nomor mereset verifikasi dan mematikan pengingat. Nomor tersimpan dalam format internasional dan ditampilkan tersamar. Kode berlaku 10 menit, dapat dipakai sekali, dan diblokir setelah lima percobaan salah. Pengiriman ulang dibatasi satu permintaan per menit per akun serta tiga per jam per akun dan per nomor.

## Siapkan pengirim OpenWA

1. Gunakan [OpenWA v0.30.0](https://github.com/rmyndharis/OpenWA) atau versi kompatibel yang mendukung `Idempotency-Key` untuk `send-text`. Sediakan origin HTTPS yang dapat dijangkau Supabase. Di dashboard OpenWA, buat dan mulai satu sesi khusus WaktuTugas. Pada WhatsApp **nomor pengirim**, buka **Perangkat tertaut → Tautkan perangkat**, pindai QR, lalu pastikan sesi berstatus `ready`. Nomor penerima hanya menerima pesan. [Panduan menautkan sesi](https://docs.open-wa.org/getting-started/first-session)
2. Buat API key dengan role `operator` dan `allowedSessions` yang berisi satu UUID sesi pengirim. Di dashboard gunakan pengaturan API keys, atau dengan admin key panggil `POST /api/auth/api-keys` dengan body `{"name":"WaktuTugas","role":"operator","allowedSessions":["<UUID sesi pengirim>"]}`. Simpan key operator lewat pengelola secrets. [Panduan API key OpenWA](https://docs.open-wa.org/guides/authentication)
3. Nonaktifkan logging body di reverse proxy dan `DATABASE_LOGGING` di OpenWA. Batasi akses ke penyimpanan dan dashboard gateway, dan atur retensi pesan sesuai kebutuhan. OpenWA menyimpan riwayat pesan yang dikirim lewat API, sehingga kode yang masih berupa isi pesan dan nomor penerima ada di riwayat gateway serta di WhatsApp. Di sisi WaktuTugas, database hanya menyimpan HMAC kode, dan fungsi tidak mencatat nomor lengkap, kode, isi pesan, atau ID pesan OpenWA yang dapat memuat nomor. [Penyimpanan pesan OpenWA](https://github.com/rmyndharis/OpenWA/blob/main/docs/05-database-design.md)

## Siapkan Supabase tujuan

1. Tautkan CLI ke proyek tujuan dengan akses operator, lalu jalankan `supabase migration list --remote` dan `supabase db push --dry-run`. Cocokkan migrasi dasar **001–003** dengan tabel dan RPC aktual sebelum melanjutkan. Jika ledger dan skema tidak cocok, selesaikan selisihnya sebelum menerapkan **004**. Setelah pratinjau ditinjau, jalankan `supabase db push`.
2. Di dashboard **Edge Functions → Secrets**, set nilai berikut. Gunakan nilai acak yang terpisah dengan minimal 32 karakter untuk kedua secret WaktuTugas. Runtime Supabase memasok `SUPABASE_URL` dan `SUPABASE_SERVICE_ROLE_KEY` untuk akses backend. APK tetap hanya memakai URL proyek dan publishable key.

   | Secret | Nilai |
   | --- | --- |
   | `OPENWA_URL` | Origin HTTPS, misalnya `https://wa.example.org`, tanpa path `/api` |
   | `OPENWA_SESSION_ID` | UUID sesi pengirim yang berstatus `ready` |
   | `OPENWA_API_KEY` | Key operator yang dibatasi ke sesi itu |
   | `WHATSAPP_CODE_SECRET` | Kunci HMAC untuk OTP dan pembatasan per nomor |
   | `WHATSAPP_CRON_SECRET` | Kunci terpisah untuk autentikasi panggilan Cron |

3. Deploy `supabase functions deploy whatsapp-settings --no-verify-jwt` dan `supabase functions deploy send-task-reminders --no-verify-jwt`. Fungsi pengaturan memvalidasi bearer token ke Supabase Auth dan memakai identitas dari Auth. Fungsi Cron menolak permintaan tanpa shared secret yang cocok. Jangan memakai service-role key sebagai autentikasi Cron atau memasukkannya ke aplikasi.
4. Di Supabase Vault, buat `whatsapp_project_url` berisi origin proyek `https://<project-ref>.supabase.co` dan `whatsapp_cron_secret` dengan nilai yang sama seperti secret Edge Function. Jalankan [SQL aktivasi Cron](../supabase/cron/whatsapp-reminders.sql) melalui SQL Editor. Pastikan job `send-task-reminders` aktif dengan jadwal `* * * * *`. Untuk menghentikan job, jalankan `SELECT cron.unschedule('send-task-reminders');`. Saat merotasi secret Cron, perbarui Vault dan Edge Function bersamaan. [Penjadwalan Edge Functions](https://supabase.com/docs/guides/functions/schedule-functions)

## Pengiriman dan verifikasi operasional

Cron memeriksa tugas setiap menit, mulai pada ambang 24 jam sebelum tenggat. Keterlambatan Cron dan percobaan ulang dibatasi sampai 15 menit setelah ambang tersebut. Pekerja mengklaim maksimal 10 pekerjaan per panggilan, dengan maksimal empat percobaan per pengingat. Setiap kombinasi tugas dan tenggat punya satu catatan dan satu kunci idempotensi. Pekerja membaca ulang status tugas, tenggat, dan pengaturan penerima sebelum memanggil OpenWA. Tenggat baru bisa menghasilkan pengingat baru. Setelah panggilan gateway dimulai, perubahan tugas atau pengaturan tidak bisa menarik kembali pesan yang sudah berjalan.

Respons OpenWA `201` dengan ID pesan ditandai `accepted`. Status itu berarti gateway menerima pesan. Untuk uji penerimaan, gunakan nomor uji yang menyetujui pengiriman, masukkan OTP dari perangkat penerima, aktifkan pengingat, buat tugas dengan sisa positif dan tenggat sekitar 24 jam ke depan, lalu tutup aplikasi. Periksa bahwa satu pesan tiba di WhatsApp penerima. Jika gateway melaporkan hasil pengiriman tidak pasti, catatan ditandai `uncertain`; periksa chat pengirim sebelum melakukan pengiriman manual. Pengiriman ulang otomatis tetap memakai kunci yang sama. [Kontrak pengiriman dan idempotensi OpenWA](https://docs.open-wa.org/guides/sending-messages#retry-a-send-without-duplicating-it)

## Uji lokal

Jalankan `supabase start`, `supabase migration up`, lalu `supabase test db`. Tes HTTP memakai Supabase lokal dan mock respons OpenWA, tanpa mengirim WhatsApp. Di PowerShell, ambil service-role key **lokal** langsung ke lingkungan proses tanpa mencetaknya:

```powershell
$env:WA_TEST_SUPABASE_URL = 'http://127.0.0.1:54321'
$line = supabase status -o env 2>$null | Where-Object { $_ -match '^SERVICE_ROLE_KEY=' }
$env:WA_TEST_SERVICE_ROLE_KEY = ($line -split '=', 2)[1].Trim('"')
try {
  node --test supabase/functions/whatsapp.test.mjs
} finally {
  Remove-Item Env:WA_TEST_SERVICE_ROLE_KEY
}
```

Tes unit mock dapat dijalankan tanpa Supabase lokal, tetapi skenario dua akun akan dilewati. Tes Flutter untuk halaman pengaturan ada di `test/ui/whatsapp_screen_test.dart`.
