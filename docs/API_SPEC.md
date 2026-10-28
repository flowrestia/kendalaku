# KendalaKu - Spesifikasi Kontrak REST API v1

Format Respon Standar:
Semua endpoint mengembalikan struktur JSON konsisten:
```json
{
  "success": true,
  "data": ...,
  "error": null
}
```
Jika terjadi kegagalan/error:
```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "VALIDATION_ERROR | NOT_FOUND | UNAUTHORIZED | INVALID_TRANSITION",
    "message": "Pesan deskriptif dalam Bahasa Indonesia"
  }
}
```

---

## 1. Autentikasi (`/api/v1/auth`)

### `POST /api/v1/auth/login`
- **Request Body**:
  ```json
  {
    "email": "admin@kendalaku.com",
    "password": "password123"
  }
  ```
- **Response `200 OK`**:
  ```json
  {
    "success": true,
    "data": {
      "token": "eyJhbGciOi...",
      "user": {
        "id": 1,
        "nama": "Administrator",
        "email": "admin@kendalaku.com",
        "role": "admin"
      }
    },
    "error": null
  }
  ```

### `GET /api/v1/auth/me`
- **Headers**: `Authorization: Bearer <token>`
- **Response `200 OK`**: Info profile pengguna yang sedang login.

---

## 2. Kategori Kendala (`/api/v1/categories`)

- `GET /api/v1/categories`: Ambil semua kategori (support query `?aktif=true`).
- `POST /api/v1/categories`: Tambah kategori baru (Role: Admin).
- `PUT /api/v1/categories/:id`: Perbarui kategori (nama, warna_hex, ikon, tenggat_jam, aktif).
- `DELETE /api/v1/categories/:id`: Hapus kategori (hanya jika belum memiliki kendala terkait; jika sudah digunakan, tolak dan arahkan untuk nonaktifkan).

---

## 3. Pesanan Simulasi & Petugas (`/api/v1/orders`, `/api/v1/users`)

- `GET /api/v1/orders`: Daftar pesanan simulasi untuk dropdown pencarian saat membuat kendala.
- `GET /api/v1/users`: Daftar staf/petugas untuk pilihan delegasi kendala (`assigned_to`).

---

## 4. Kendala Pesanan (`/api/v1/issues`)

### `GET /api/v1/issues`
- **Query Params**:
  - `page` (default 1), `limit` (default 10)
  - `search` (mencari pada kode_kendala, judul, nomor pesanan, nama pelanggan)
  - `status` (`baru,sedang_diproses,...`)
  - `prioritas` (`rendah,sedang,tinggi,kritis`)
  - `category_id` (integer)
  - `assigned_to` (user id)
  - `from` & `to` (filter rentang tanggal `created_at`)
  - `is_archived` (boolean, default false)
  - `is_overdue` (boolean, filter kendala yang melewati tenggat)
- **Response Fields Termasuk Relasi (JOIN Tunggal & Konsisten)**:
  - `kode_pesanan` (string): Nomor invoice/kode pesanan terkait.
  - `nama_pelanggan` (string): Nama pemesan.
  - `category_nama` (string): Nama kategori kendala.
  - `category_warna_hex` (string): Warna identitas kategori (contoh `#EF4444`, default `#4F46E5`).
  - `category_ikon` (string): Nama ikon kategori (contoh `alarm_rounded`, default `warning_amber_rounded`).
  - `assigned_nama` (string): Nama petugas yang ditugaskan (atau `"-"` jika belum ada).
  - `created_by_nama` (string): Nama pembuat laporan kendala.
  - `is_overdue` (boolean): `true` jika status belum selesai/ditolak dan waktu sekarang melewati `tenggat_at`.
  *(Catatan: Field alias lama seperti `nama_kategori`, `warna_kategori`, `ikon_kategori`, `nama_petugas`, `nama_pembuat` telah dihapus demi kebersihan payload JSON).*

### `POST /api/v1/issues`
- **Request Body**:
  ```json
  {
    "order_id": 1,
    "category_id": 2,
    "judul": "Barang pecah belah saat dipacking",
    "deskripsi": "Ditemukan retakan pada wadah kaca produk sebelum dikirim.",
    "prioritas": "tinggi",
    "assigned_to": 2,
    "tenggat_at": "2026-10-27T10:00:00Z" // opsional, otomatis dari SLA kategori jika kosong
  }
  ```

### `GET /api/v1/issues/:id`
- Mengembalikan detail kendala lengkap dengan field relasi (`kode_pesanan`, `nama_pelanggan`, `category_nama`, `category_warna_hex`, `category_ikon`, `assigned_nama`, `created_by_nama`), dan daftar lampiran.

### `PUT /api/v1/issues/:id`
- Memperbarui data kendala (judul, deskripsi, prioritas, penugasan, tenggat_at).

### `DELETE /api/v1/issues/:id`
- Hanya diizinkan jika status kendala masih `"baru"` dan dilakukan oleh admin. Status lain hanya bisa diarsipkan.

### `GET /api/v1/share/issues`
- Menghasilkan ringkasan daftar kendala siap kirim ke WhatsApp (format teks *tebal* Markdown WA).
- **Query Parameters**:
  - Semua filter query pada `GET /issues` (`search`, `status`, `prioritas`, `category_id`, `assigned_to`, `from`, `to`, `is_overdue`). Khusus `assigned_to` mendukung nilai `"me"`.
  - `ids` (string, opsional): Daftar ID yang dipilih dipisah koma (contoh: `ids=1,2,5`).
  - `include_customer` (boolean, opsional, default `true`): Menyertakan nama pelanggan di samping kode pesanan. Jika `false`, hanya nomor pesanan yang tampil.
- **Urutan Pengurutan (Sorting Bisnis)**:
  1. Terlambat terlebih dahulu (`is_overdue = true`).
  2. Prioritas tingkat keparahan (`kritis` > `tinggi` > `sedang` > `rendah`).
  3. Tenggat waktu SLA terdekat (`tenggat_at` ASC).
- **Pembatasan (Truncation)**: Maksimal 20 kendala per pesan. Jika total hasil > 20, ditambahkan baris `_+N kendala lainnya, lihat di aplikasi_` dan flag `truncated: true`.
- **Response Data (`ShareTextResponse`)**:
  ```json
  {
    "success": true,
    "data": {
      "text": "*DAFTAR KENDALA LAYANAN - KENDALAKU*\nWaktu Cetak: 27/10/2026 18:30 WIB\n...",
      "count": 25,
      "truncated": true
    },
    "error": null
  }
  ```

### `PATCH /api/v1/issues/:id/archive`
- Mengubah flag `is_archived: true` atau `false`.

---

## 5. Transisi Status Penanganan (`/api/v1/issues/:id/transitions`)

### `POST /api/v1/issues/:id/transitions`
- **Request Body**:
  ```json
  {
    "status_baru": "sedang_diproses",
    "catatan_tindakan": "Petugas mulai memeriksa fisik barang di gudang.",
    "catatan_penyelesaian": "" // Wajib jika status_baru = "selesai"
  }
  ```
- **Aturan Respon**:
  - `200 OK`: Status berhasil diubah dan transaksi riwayat tercatat.
  - `422 Unprocessable Entity`: Transisi status tidak sah atau catatan penyelesaian kosong saat status selesai.
  ```json
  {
    "success": false,
    "data": null,
    "error": {
      "code": "INVALID_STATUS_TRANSITION",
      "message": "Transisi status dari 'baru' ke 'selesai' tidak diizinkan."
    }
  }
  ```

### `GET /api/v1/issues/:id/transitions`
- Mengambil timeline riwayat tindakan lengkap beserta waktu dan nama petugas.

### `GET /api/v1/issues/:id/comments`
- Semua user login dapat membaca komentar pada kendala.
- Diurutkan berdasarkan waktu pembuatan secara kronologis (`created_at ASC`).
- Response:
  ```json
  {
    "success": true,
    "data": [
      {
        "id": 1,
        "issue_id": 10,
        "user_id": 1,
        "user_nama": "Administrator",
        "tipe": "sistem",
        "isi": "Dipindahkan dari Rina Petugas ke Doni Petugas. Alasan: Realloc",
        "created_at": "2026-10-27T10:00:00Z"
      }
    ],
    "error": null
  }
  ```

### `POST /api/v1/issues/:id/comments`
- Semua user login dapat mengirim komentar pada kendala.
- Body:
  ```json
  {
    "isi": "Pelanggan sudah mengonfirmasi alamat baru via telepon."
  }
  ```
- Validasi: `isi` wajib, maksimal 1000 karakter.

### `PATCH /api/v1/issues/:id/assign`
- Khusus role **Admin**. Role Petugas akan menerima response `403 FORBIDDEN`.
- Body:
  ```json
  {
    "assigned_to": 3,
    "catatan": "Dialihkan karena beban kerja tinggi"
  }
  ```
- Validasi:
  - Kendala berstatus `selesai` atau `ditolak` tidak dapat dialihkan (balas `422 UNPROCESSABLE_ENTITY`).
  - `assigned_to` harus merujuk ke user dengan role `petugas` yang aktif di database.
- Eksekusi transaksi atomik:
  1. Perbarui kolom `assigned_to` pada `order_issues`.
  2. Tambahkan komentar dengan `tipe: 'sistem'` berbunyi: `"Dipindahkan dari [Nama Lama] ke [Nama Baru]"` (+ catatan jika ada).

### Aturan Hak Akses Role
- **Admin**: Akses penuh ke semua operasi (CRUD kategori, reassign kendala, hapus kendala, arsip kendala, ubah status kendala manapun).
- **Petugas**:
  - Boleh membuat kendala baru (`POST /issues`).
  - Hanya boleh mengubah data kendala (`PUT /issues/:id`) dan melakukan transisi status (`POST /issues/:id/transitions`) jika kendala tersebut ditugaskan ke dirinya (`assigned_to == user.ID`).
  - Jika bukan miliknya, server membalas `403 FORBIDDEN` dengan format error standar:
    ```json
    {
      "success": false,
      "data": null,
      "error": {
        "code": "FORBIDDEN",
        "message": "Anda hanya diizinkan memperbarui kendala yang ditugaskan kepada Anda"
      }
    }
    ```
  - Ditolak dari: reassign (`PATCH /assign`), arsip (`PATCH /archive`), hapus (`DELETE /issues/:id`), dan CRUD kategori.

---

## 6. Dashboard & Analitik (`/api/v1/dashboard`)

### `GET /api/v1/dashboard/summary`
- Mengembalikan metrik ringkasan kinerja penanganan kendala:
  - `total`: Total kendala aktif (tidak diarsip).
  - `baru`, `sedang_diproses`, `menunggu_informasi`, `selesai`, `ditolak`.
  - `terlambat`: Total kendala belum selesai/ditolak yang melewati `tenggat_at`.
  - `jatuh_tempo_segera`: Total kendala belum selesai/ditolak yang tenggat waktunya dalam kurun waktu 24 jam ke depan.
  - `rata_rata_waktu_jam`: Rata-rata durasi penyelesaian (jam) untuk kendala berstatus selesai.
  - `persentase_selesai`: Persentase kendala berstatus selesai dari total kendala (%).

### `GET /api/v1/dashboard/due-soon?hours=24`
- Mengambil daftar kendala aktif (belum selesai/ditolak) yang jatuh tempo antara saat ini dan `hours` jam ke depan (default `hours=24`).
- Diurutkan berdasarkan `tenggat_at ASC` (yang paling segera jatuh tempo berada di urutan pertama).

### `GET /api/v1/dashboard/by-category`
- Mengembalikan distribusi kendala per kategori (`category_id`, `nama`, `warna_hex`, `ikon`, `total`, `persentase`) untuk visualisasi Donut Chart.

### `GET /api/v1/dashboard/trend?period=7d|30d|12m`
- Query param: `period` (`7d` [default], `30d`, atau `12m`).
- Mengembalikan deret waktu:
  ```json
  [
    {
      "label": "2026-10-20",
      "tanggal": "2026-10-20",
      "total_masuk": 4,
      "total_selesai": 2
    }
  ]
  ```

---

## 7. Rekap Laporan & Ekspor CSV (`/api/v1/reports`)

### `GET /api/v1/reports/recap?from=YYYY-MM-DD&to=YYYY-MM-DD`
- Query params: `from` dan `to` (opsional rentang tanggal pelaporan).
- Response:
  ```json
  {
    "total_kendala": 40,
    "kategori_paling_sering": "Pesanan Terlambat Diproses",
    "rekap_status": {
      "baru": 10,
      "sedang_diproses": 12,
      "menunggu_informasi": 8,
      "selesai": 7,
      "ditolak": 3
    },
    "per_kategori": [
      {
        "category_id": 1,
        "nama": "Pesanan Terlambat Diproses",
        "warna_hex": "#EF4444",
        "total": 12,
        "status": {
          "baru": 3,
          "sedang_diproses": 4,
          "menunggu_informasi": 2,
          "selesai": 2,
          "ditolak": 1
        }
      }
    ]
  }
  ```

### `GET /api/v1/reports/export.csv?from=YYYY-MM-DD&to=YYYY-MM-DD`
- Mengembalikan file CSV streaming dengan header HTTP:
  - `Content-Disposition: attachment; filename=laporan_kendala.csv`
  - `Content-Type: text/csv; charset=utf-8`
  - Dilengkapi byte order mark (UTF-8 BOM `\xEF\xBB\xBF`) agar langsung terbaca rapi dengan aksen karakter di Microsoft Excel dan Google Sheets.

---

## 8. Riwayat Aktivitas (`/api/v1/activities`)

### `GET /api/v1/activities?limit=20`
- Query param: `limit` (default 20, max 100).
- Mengembalikan log aktivitas transisi penanganan kendala dari seluruh tim (audit trail).
