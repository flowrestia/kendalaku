# KendalaKu - Sistem Manajemen Penanganan Kendala Pesanan

Aplikasi penanganan kendala pemrosesan pesanan (order issues tracking system) dengan arsitektur bersih: Go (Handler -> Service -> Repository) + MySQL/MariaDB dan Flutter Mobile/Desktop.

---

## 1. Akun Pengguna Demo

Data seeder menyediakan 3 akun awal untuk pengujian:

| Role | Nama | Email | Kata Sandi | Hak Akses |
|---|---|---|---|---|
| **Admin** | Sonny (Admin Operasional) | `admin@kendalaku.com` | `password123` | Akses penuh CRUD kategori, hapus kendala baru, semua aksi petugas |
| **Petugas** | Rina Petugas | `petugas1@kendalaku.com` | `password123` | Buat kendala, ubah kendala, delegasi, transaksi status |
| **Petugas** | Budi Penanganan | `petugas2@kendalaku.com` | `password123` | Buat kendala, ubah kendala, delegasi, transaksi status |

---

## 2. Cara Menjalankan Backend Secara Lokal (Tanpa Docker / Menggunakan XAMPP)

### Prasyarat:
1. **Go 1.22+** terpasang (`go version`).
2. **MySQL / MariaDB** (misalnya via XAMPP) aktif di port `3307` (atau port default Anda).

### Langkah-langkah:

1. **Siapkan Database MySQL/MariaDB:**
   Pastikan database `kendalaku` sudah dibuat dengan charset `utf8mb4`:
   ```bash
   mysql --port=3307 -u root -e "CREATE DATABASE IF NOT EXISTS kendalaku CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
   ```

2. **Salin dan Sesuaikan Konfigurasi Environment:**
   Di folder `backend/`:
   ```bash
   cp .env.example .env
   ```
   Isi file `backend/.env`:
   ```env
   APP_ENV=development
   APP_PORT=8080

   # Database Configuration (XAMPP MariaDB)
   DB_HOST=127.0.0.1
   DB_PORT=3307
   DB_USER=root
   DB_PASSWORD=
   DB_NAME=kendalaku

   # JWT Secret Key
   JWT_SECRET=kendalaku_jwt_super_secret_key_2026
   JWT_EXPIRY_HOURS=72
   ```

3. **Jalankan Migrasi Database & Seeder Otomatis:**
   Backend KendalaKu secara otomatis mengeksekusi migrasi tabel (`migrations/000001_init_schema.up.sql`) dan seeder idempotent saat pertama kali startup:
   ```bash
   cd backend
   go run ./cmd/api
   ```
   Output log yang sukses:
   ```text
   [INFO] Menghubungkan ke MySQL di 127.0.0.1:3307 (DB: kendalaku)...
   [INFO] Terhubung ke database MySQL dengan sukses
   [INFO] Database migrasi berhasil dijalankan (up to date)
   [INFO] Memeriksa dan menjalankan database seeder idempotent...
   [INFO] Database seeder berhasil selesai (40 kendala realistis tersimpan)
   [INFO] Server KendalaKu aktif mendengarkan pada port :8080
   ```

4. **Menjalankan Unit Test & Integration Test:**
   ```bash
   cd backend
   go test -v ./...
   ```
   Pengujian mencakup:
   - Seluruh permutasi validasi transisi status (sah dan tidak sah).
   - Validasi aturan mutlak catatan penyelesaian saat status selesai.
   - Live endpoint test: Login, GET /issues, dan penolakan HTTP 422 untuk status transisi ilegal.

---

## 3. Opsi Menjalankan Menggunakan Docker Compose

Jika menggunakan Docker Desktop:
```bash
docker compose up -d
```
Service MySQL 8 dan backend container akan berjalan otomatis dengan database migration & seeder.

---

## 4. Endpoints Utama API v1

- **Auth**:
  - `POST /api/v1/auth/login` (Body: `{ "email": "admin@kendalaku.com", "password": "password123" }`)
  - `GET /api/v1/auth/me` (Header: `Authorization: Bearer <token>`)
  - `GET /api/v1/users`
- **Kategori Kendala**:
  - `GET /api/v1/categories`
  - `POST /api/v1/categories` (Admin)
  - `PUT /api/v1/categories/:id` (Admin)
  - `DELETE /api/v1/categories/:id` (Admin)
- **Pesanan Simulasi**:
  - `GET /api/v1/orders`
- **Kendala Pesanan**:
  - `GET /api/v1/issues` (Filter: search, status, prioritas, category_id, assigned_to, from, to)
  - `POST /api/v1/issues`
  - `GET /api/v1/issues/:id`
  - `PUT /api/v1/issues/:id`
  - `PATCH /api/v1/issues/:id/archive`
  - `DELETE /api/v1/issues/:id` (Admin, hanya untuk status baru)
- **Status Transisi**:
  - `POST /api/v1/issues/:id/transitions`
  - `GET /api/v1/issues/:id/transitions`
