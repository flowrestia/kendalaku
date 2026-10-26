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
- Mengembalikan detail kendala, data pesanan simulasi, info pelapor & petugas, serta lampiran.

### `PUT /api/v1/issues/:id`
- Memperbarui data kendala (judul, deskripsi, prioritas, penugasan, tenggat_at).

### `DELETE /api/v1/issues/:id`
- Hanya diizinkan jika status kendala masih `"baru"` dan dilakukan oleh admin. Status lain hanya bisa diarsipkan.

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

---

## 6. Dashboard & Analitik (`/api/v1/dashboard`)

- `GET /api/v1/dashboard/summary`:
  - Total kendala, baru, sedang diproses, selesai, dan total terlambat (overdue).
  - Rata-rata waktu penyelesaian (dalam jam) dan persentase kendala terselesaikan.
- `GET /api/v1/dashboard/by-category`:
  - Jumlah dan persentase kendala per kategori (untuk donat chart).
- `GET /api/v1/dashboard/trend?period=7d|30d|12m`:
  - Data time-series jumlah kendala masuk dan kendala selesai.
- `GET /api/v1/dashboard/attention`:
  - Daftar kendala yang melewati tenggat atau memiliki prioritas kritis.

---

## 7. Laporan & Ekspor (`/api/v1/reports`)

- `GET /api/v1/reports/recap?from=&to=`:
  - Matriks rekapitulasi performa kendala per kategori dan per status.
- `GET /api/v1/reports/export.csv?from=&to=`:
  - Download file spreadsheet CSV data kendala lengkap dengan header resmi.
