-- 000001_init_schema.up.sql

CREATE TABLE IF NOT EXISTS users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nama VARCHAR(100) NOT NULL,
    email VARCHAR(191) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('admin', 'petugas') NOT NULL DEFAULT 'petugas',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS problem_categories (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nama VARCHAR(100) NOT NULL,
    warna_hex VARCHAR(7) NOT NULL DEFAULT '#4F46E5',
    ikon VARCHAR(50) NOT NULL DEFAULT 'warning_amber_rounded',
    tenggat_jam INT NOT NULL DEFAULT 24,
    aktif TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS orders (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    kode_pesanan VARCHAR(50) NOT NULL UNIQUE,
    nama_pelanggan VARCHAR(150) NOT NULL,
    produk TEXT NOT NULL,
    jumlah INT NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS order_issues (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    kode_kendala VARCHAR(30) NOT NULL UNIQUE,
    order_id BIGINT UNSIGNED NOT NULL,
    category_id BIGINT UNSIGNED NOT NULL,
    judul VARCHAR(200) NOT NULL,
    deskripsi TEXT NOT NULL,
    prioritas ENUM('rendah', 'sedang', 'tinggi', 'kritis') NOT NULL DEFAULT 'sedang',
    status ENUM('baru', 'sedang_diproses', 'menunggu_informasi', 'selesai', 'ditolak') NOT NULL DEFAULT 'baru',
    tenggat_at DATETIME NOT NULL,
    assigned_to BIGINT UNSIGNED NULL,
    catatan_penyelesaian TEXT NULL,
    is_archived TINYINT(1) NOT NULL DEFAULT 0,
    created_by BIGINT UNSIGNED NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    resolved_at DATETIME NULL,
    
    CONSTRAINT fk_issues_order FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE RESTRICT,
    CONSTRAINT fk_issues_category FOREIGN KEY (category_id) REFERENCES problem_categories(id) ON DELETE RESTRICT,
    CONSTRAINT fk_issues_assigned FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT fk_issues_creator FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT,
    
    INDEX idx_order_issues_status (status),
    INDEX idx_order_issues_category (category_id),
    INDEX idx_order_issues_assigned (assigned_to),
    INDEX idx_order_issues_tenggat (tenggat_at),
    INDEX idx_order_issues_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS issue_transactions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    issue_id BIGINT UNSIGNED NOT NULL,
    status_sebelumnya VARCHAR(30) NOT NULL,
    status_baru VARCHAR(30) NOT NULL,
    catatan_tindakan TEXT NOT NULL,
    oleh_user_id BIGINT UNSIGNED NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_trans_issue FOREIGN KEY (issue_id) REFERENCES order_issues(id) ON DELETE CASCADE,
    CONSTRAINT fk_trans_user FOREIGN KEY (oleh_user_id) REFERENCES users(id) ON DELETE RESTRICT,
    
    INDEX idx_issue_transactions_issue (issue_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS issue_attachments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    issue_id BIGINT UNSIGNED NOT NULL,
    nama_file VARCHAR(255) NOT NULL,
    path VARCHAR(500) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_attach_issue FOREIGN KEY (issue_id) REFERENCES order_issues(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
