package database

import (
	"database/sql"
	"fmt"
	"log"
	"strings"

	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/mysql"
	_ "github.com/golang-migrate/migrate/v4/source/file"
)

func RunMigrations(migrationDSN, migrationsPath, dbName string) error {
	migrationDB, err := sql.Open("mysql", migrationDSN)
	if err != nil {
		return fmt.Errorf("gagal membuka koneksi migrasi: %w", err)
	}
	defer migrationDB.Close()

	driver, err := mysql.WithInstance(migrationDB, &mysql.Config{})
	if err != nil {
		return fmt.Errorf("gagal membuat driver migrasi: %w", err)
	}

	m, err := migrate.NewWithDatabaseInstance(
		"file://"+migrationsPath,
		dbName,
		driver,
	)
	if err != nil {
		return fmt.Errorf("gagal inisialisasi golang-migrate: %w", err)
	}

	if err := m.Up(); err != nil && err != migrate.ErrNoChange {
		if strings.Contains(strings.ToLower(err.Error()), "dirty") {
			return fmt.Errorf("DATABASE DIRTY STATE TERDETEKSI: %w\n-> Solusi: Jalankan migrasi force atau bersihkan database dengan:\n   mysql --port=3307 -u root -e \"DROP DATABASE IF EXISTS %s; CREATE DATABASE %s CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;\"", err, dbName, dbName)
		}
		return fmt.Errorf("migrasi database gagal: %w", err)
	}

	log.Println("[INFO] Database migrasi berhasil dijalankan (up to date)")
	return nil
}
