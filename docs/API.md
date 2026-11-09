# Kontrak API & RPC Backend WaktuTugas

Dokumen ini merangkum seluruh prosedur RPC transaksional (*Remote Procedure Call*) pada database PostgreSQL / Supabase untuk aplikasi **WaktuTugas**. Seluruh mutasi dieksekusi secara atomik dengan mekanisme *optimistic locking* (`expected_revision`).

> **Status verifikasi (8 November 2026):** kontrak dan migrasi telah ditinjau, tetapi RPC belum benar-benar diuji karena Docker Engine lokal tidak aktif. `supabase test db` gagal terkoneksi ke PostgreSQL lokal. Karena itu tidak ada RPC/AC backend yang ditandai lulus pada dokumen ini.

Nama argumen aktual pada migrasi menggunakan awalan `p_` untuk menghindari ambiguitas PostgreSQL (misalnya `p_expected_revision`); klien Flutter mengirim nama tersebut.

---

## 1. Kebijakan Keamanan & Otorisasi
- **Role:** Seluruh endpoint RPC hanya dapat diakses oleh pengguna terautentikasi (`authenticated`). Panggilan tanpa token valid akan mengembalikan error `UNAUTHENTICATED` (`P0001`).
- **Isolasi Akun:** Data difilter ketat berdasarkan `auth.uid() = user_id`. Pengguna tidak dapat membaca atau memodifikasi data akun lain (`AC01`).
- **Pembatasan Direct Writes:** Operasi `INSERT`, `UPDATE`, dan `DELETE` langsung pada tabel dinonaktifkan dari REST API. Semua perubahan data wajib melalui fungsi RPC di bawah ini.

---

## 2. Pemetaan Kode Error (Error Codes)

| Kode Error | SQLSTATE | Deskripsi | Tindakan Klien (Frontend) |
| :--- | :--- | :--- | :--- |
| `UNAUTHENTICATED` | `P0001` | Sesi login tidak ditemukan atau kedaluwarsa | Arahkan pengguna ke layar `/login` |
| `STALE_REVISION` | `P0002` | `expected_revision` tidak cocok dengan revisi server | Tampilkan peringatan, muat ulang snapshot, dan hitung pratinjau baru |
| `VALIDATION_ERROR` | `P0003` | Validasi input gagal (nama kosong, rentang terbalik, dll.) | Tampilkan pesan error spesifik dekat field formulir |
| `NOT_FOUND` | `P0004` | Data entitas tidak ditemukan atau bukan milik akun ini | Tampilkan pesan bahwa data telah dihapus |
| `SESSION_ALREADY_CLOSED` | `P0005` | Sesi belajar sudah ditutup sebelumnya | Kunci tombol aksi progres dan refresh state |

---

## 3. Daftar Prosedur RPC

### 3.1 `get_planner_snapshot`
Membaca seluruh data pengguna (tugas, waktu luang, kegiatan, dan sesi) beserta revisi data saat ini.
* **Metode:** `POST /rest/v1/rpc/get_planner_snapshot`
* **Argumen:** Tidak ada (identitas diambil dari JWT `auth.uid()`).
* **Format Respons:**
```json
{
  "revision": 12,
  "tasks": [
    {
      "id": "uuid",
      "title": "Tugas Praktikum PBP",
      "course": "Pemrograman Berbasis Platform",
      "deadline_at": "2026-11-11T11:00:00Z",
      "remaining_minutes": 240,
      "created_at": "2026-11-09T08:00:00Z"
    }
  ],
  "time_windows": [
    {
      "id": "uuid",
      "weekday": 1,
      "date": null,
      "start_minute": 1140,
      "end_minute": 1320
    }
  ],
  "activities": [
    {
      "id": "uuid",
      "kind": "routine",
      "label": "Kuliah PBP",
      "weekday": 1,
      "date": null,
      "start_minute": 780,
      "end_minute": 960
    }
  ],
  "sessions": [
    {
      "id": "uuid",
      "task_id": "uuid",
      "starts_at": "2026-11-09T12:00:00Z",
      "ends_at": "2026-11-09T13:00:00Z",
      "status": "planned",
      "remaining_after": null,
      "closed_at": null
    }
  ]
}
```

---

### 3.2 `save_task`
Menambah tugas baru atau memperbarui tugas yang ada.
* **Metode:** `POST /rest/v1/rpc/save_task`
* **Argumen:**
  * `task_id` (`uuid`, nullable): `null` untuk tugas baru, UUID untuk edit.
  * `title` (`text`, required): 1–120 karakter.
  * `course` (`text`, nullable): Maksimal 100 karakter.
  * `deadline_at` (`timestamptz`, required): Waktu tenggat pengumpulan.
  * `remaining_minutes` (`integer`, required): Sisa estimasi pengerjaan ($\ge 0$).
  * `expected_revision` (`bigint`, required): Revisi lokal saat ini.
* **Respons:** `bigint` (Revisi baru server).

---

### 3.3 `delete_task`
Menghapus tugas dan seluruh sesi terkait.
* **Metode:** `POST /rest/v1/rpc/delete_task`
* **Argumen:**
  * `task_id` (`uuid`, required): ID tugas yang akan dihapus.
  * `confirm_delete` (`boolean`, required): Harus bernilai `true`.
  * `expected_revision` (`bigint`, required): Revisi lokal saat ini.
* **Respons:** `bigint` (Revisi baru server).

---

### 3.4 `save_time_window`
Menambah atau memperbarui rentang waktu luang yang diizinkan.
* **Metode:** `POST /rest/v1/rpc/save_time_window`
* **Argumen:**
  * `id` (`uuid`, nullable): `null` untuk baru, UUID untuk edit.
  * `weekday` (`smallint`, nullable): 1–7 (Senin–Minggu).
  * `date` (`date`, nullable): Tanggal spesifik (`YYYY-MM-DD`).
  * `start_minute` (`integer`, required): 0–1439.
  * `end_minute` (`integer`, required): 1–1440 (`end > start`).
  * `expected_revision` (`bigint`, required): Revisi lokal.
* *Catatan:* Tepat satu dari `weekday` atau `date` harus diisi.
* **Respons:** `bigint` (Revisi baru server).

---

### 3.5 `delete_time_window`
Menghapus rentang waktu luang.
* **Metode:** `POST /rest/v1/rpc/delete_time_window`
* **Argumen:** `id` (`uuid`), `expected_revision` (`bigint`).
* **Respons:** `bigint` (Revisi baru server).

---

### 3.6 `save_activity`
Menambah atau memperbarui kegiatan (rutinitas, acara sekali, atau blokir waktu).
* **Metode:** `POST /rest/v1/rpc/save_activity`
* **Argumen:**
  * `id` (`uuid`, nullable): `null` untuk baru, UUID untuk edit.
  * `kind` (`text`, required): `'routine'`, `'event'`, atau `'blocked'`.
  * `label` (`text`, required): Maksimal 120 karakter.
  * `weekday` (`smallint`, nullable): Diisi jika `kind = 'routine'`.
  * `date` (`date`, nullable): Diisi jika `kind IN ('event', 'blocked')`.
  * `start_minute` (`integer`, required): 0–1439.
  * `end_minute` (`integer`, required): 1–1440 (`end > start`).
  * `expected_revision` (`bigint`, required): Revisi lokal.
* **Respons:** `bigint` (Revisi baru server).

---

### 3.7 `delete_activity`
Menghapus kegiatan atau penutupan waktu.
* **Metode:** `POST /rest/v1/rpc/delete_activity`
* **Argumen:** `id` (`uuid`), `expected_revision` (`bigint`).
* **Respons:** `bigint` (Revisi baru server).

---

### 3.8 `record_progress`
Mencatat progres penyelesaian sesi belajar yang telah dimulai/berlalu.
* **Metode:** `POST /rest/v1/rpc/record_progress`
* **Argumen:**
  * `session_id` (`uuid`, required): ID sesi yang ditutup.
  * `status` (`text`, required): `'completed'` atau `'missed'`.
  * `remaining_after` (`integer`, nullable): Sisa durasi tugas setelah sesi (wajib $\ge 0$ jika `completed`, `null` jika `missed`).
  * `expected_revision` (`bigint`, required): Revisi lokal.
* **Respons:** `bigint` (Revisi baru server).

---

### 3.9 `confirm_schedule`
Mengonfirmasi jadwal baru hasil perhitungan pratinjau (*planner preview*).
* **Metode:** `POST /rest/v1/rpc/confirm_schedule`
* **Argumen:**
  * `input_revision` (`bigint`, required): Revisi yang mendasari perhitungan pratinjau.
  * `window_start` (`timestamptz`, required): Waktu awal jendela perencanaan.
  * `window_end` (`timestamptz`, required): Waktu akhir jendela perencanaan.
  * `sessions` (`jsonb array`, required): Daftar sesi kandidat baru.
    * Format elemen: `{"task_id": "uuid", "starts_at": "timestamptz", "ends_at": "timestamptz"}`.
* **Perilaku Atomik:**
  1. Membatalkan (mengubah status menjadi `'cancelled'`) seluruh sesi `planned` masa depan yang belum berjalan.
  2. Memasukkan seluruh sesi kandidat baru sebagai `planned`.
  3. Mempertahankan riwayat sesi `completed` dan `missed`.
  4. Menaikkan revisi server sebesar $+1$.
* **Respons:** `bigint` (Revisi baru server).
