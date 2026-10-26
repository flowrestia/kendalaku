package config

import (
	"fmt"
	"log"
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

type Config struct {
	AppEnv         string
	AppPort        string
	DBHost         string
	DBPort         string
	DBUser         string
	DBPassword     string
	DBName         string
	JWTSecret      string
	JWTExpiryHours int
}

func LoadConfig() *Config {
	// Memuat .env jika tersedia (tidak error jika tidak ada, misalnya di Docker)
	_ = godotenv.Load()

	expiryHours, err := strconv.Atoi(getEnv("JWT_EXPIRY_HOURS", "72"))
	if err != nil {
		expiryHours = 72
	}

	cfg := &Config{
		AppEnv:         getEnv("APP_ENV", "development"),
		AppPort:        getEnv("APP_PORT", "8080"),
		DBHost:         getEnv("DB_HOST", "127.0.0.1"),
		DBPort:         getEnv("DB_PORT", "3307"),
		DBUser:         getEnv("DB_USER", "kendalaku_user"),
		DBPassword:     getEnv("DB_PASSWORD", "kendalaku_pass"),
		DBName:         getEnv("DB_NAME", "kendalaku_db"),
		JWTSecret:      getEnv("JWT_SECRET", "kendalaku_jwt_super_secret_key_2026"),
		JWTExpiryHours: expiryHours,
	}

	if cfg.JWTSecret == "" {
		log.Println("[WARN] JWT_SECRET kosong, menggunakan fallback rahasia default")
		cfg.JWTSecret = "kendalaku_jwt_super_secret_key_2026"
	}

	return cfg
}

func (c *Config) DSN() string {
	// parseTime=true dan loc=UTC wajib sesuai aturan spesifikasi UTC MySQL
	return fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?charset=utf8mb4&parseTime=true&loc=UTC",
		c.DBUser, c.DBPassword, c.DBHost, c.DBPort, c.DBName)
}

func (c *Config) MigrationDSN() string {
	// Khusus migrasi golang-migrate: tambahkan multiStatements=true agar dapat mengeksekusi multiple DDL statements
	return fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?charset=utf8mb4&parseTime=true&loc=UTC&multiStatements=true",
		c.DBUser, c.DBPassword, c.DBHost, c.DBPort, c.DBName)
}

func getEnv(key, defaultVal string) string {
	if val, ok := os.LookupEnv(key); ok {
		return val
	}
	return defaultVal
}
