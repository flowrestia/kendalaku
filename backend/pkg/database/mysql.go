package database

import (
	"log"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"github.com/jmoiron/sqlx"
)

func InitDB(dsn string) (*sqlx.DB, error) {
	db, err := sqlx.Open("mysql", dsn)
	if err != nil {
		return nil, err
	}

	// Konfigurasi pool koneksi
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(10)
	db.SetConnMaxLifetime(15 * time.Minute)
	db.SetConnMaxIdleTime(5 * time.Minute)

	if err := db.Ping(); err != nil {
		return nil, err
	}

	// Pastikan sesi MySQL/MariaDB selalu dalam zona waktu UTC (+00:00)
	if _, err := db.Exec("SET time_zone = '+00:00'"); err != nil {
		log.Printf("[WARN] Tidak dapat menyetel SET time_zone: %v", err)
	}

	log.Println("[INFO] Terhubung ke database MySQL dengan sukses (Timezone: UTC)")
	return db, nil
}
