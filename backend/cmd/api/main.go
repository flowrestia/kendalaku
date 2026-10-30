package main

import (
	"log"
	"path/filepath"

	"github.com/flowrestia/kendalaku/backend/internal/config"
	"github.com/flowrestia/kendalaku/backend/internal/handler"
	"github.com/flowrestia/kendalaku/backend/internal/repository/mysql"
	"github.com/flowrestia/kendalaku/backend/internal/service"
	"github.com/flowrestia/kendalaku/backend/pkg/database"
	"github.com/flowrestia/kendalaku/backend/pkg/jwt"
	"github.com/gin-gonic/gin"
)

func main() {
	cfg := config.LoadConfig()

	if cfg.GinMode != "" {
		gin.SetMode(cfg.GinMode)
	} else if cfg.AppEnv == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	// Inisialisasi Database
	log.Printf("[INFO] Menghubungkan ke MySQL di %s:%s (DB: %s)...", cfg.DBHost, cfg.DBPort, cfg.DBName)
	db, err := database.InitDB(cfg.DSN())
	if err != nil {
		log.Fatalf("[FATAL] Gagal menghubungkan ke database: %v", err)
	}
	defer db.Close()

	// Jalankan database migration otomatis (up) dengan multiStatements DSN
	migrationsDir := filepath.Join(".", "migrations")
	if err := database.RunMigrations(cfg.MigrationDSN(), migrationsDir, cfg.DBName); err != nil {
		log.Fatalf("[FATAL] Migrasi database gagal: %v", err)
	}

	// Jalankan database seed idempotent
	if err := database.SeedDatabase(db); err != nil {
		log.Fatalf("[FATAL] Seeding database gagal: %v", err)
	}

	// Inisialisasi Layer Architecture: Repo -> Service -> Handler
	tokenMaker := jwt.NewTokenMaker(cfg.JWTSecret)
	repo := mysql.NewRepository(db)
	svc := service.NewService(repo, tokenMaker, cfg.JWTExpiryHours)
	h := handler.NewHandler(svc)

	// Inisialisasi Router Gin
	r := handler.SetupRouter(h, tokenMaker)

	log.Printf("[INFO] Server KendalaKu aktif mendengarkan pada port :%s", cfg.AppPort)
	if err := r.Run(":" + cfg.AppPort); err != nil {
		log.Fatalf("[FATAL] Gagal menjalankan HTTP server: %v", err)
	}
}
