package main

import (
	"log"
	"path/filepath"

	"github.com/flowrestia/kendalaku/backend/internal/config"
	"github.com/flowrestia/kendalaku/backend/internal/domain"
	"github.com/flowrestia/kendalaku/backend/internal/handler"
	"github.com/flowrestia/kendalaku/backend/internal/middleware"
	"github.com/flowrestia/kendalaku/backend/internal/repository/mysql"
	"github.com/flowrestia/kendalaku/backend/internal/service"
	"github.com/flowrestia/kendalaku/backend/pkg/database"
	"github.com/flowrestia/kendalaku/backend/pkg/jwt"
	"github.com/gin-gonic/gin"
)

func main() {
	cfg := config.LoadConfig()

	if cfg.AppEnv == "production" {
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
	r := gin.New()
	r.Use(gin.Logger())
	r.Use(gin.Recovery())
	r.Use(middleware.CORSMiddleware())

	// Health check endpoint
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "healthy", "service": "KendalaKu API"})
	})

	api := r.Group("/api/v1")
	{
		// Auth Routes (Publik)
		auth := api.Group("/auth")
		{
			auth.POST("/login", h.Login)
		}

		// Protected Routes (Membutuhkan Bearer Token)
		protected := api.Group("")
		protected.Use(middleware.AuthMiddleware(tokenMaker))
		{
			// Auth Profile & Users
			protected.GET("/auth/me", h.GetMe)
			protected.GET("/users", h.GetUsers)

			// Problem Categories
			protected.GET("/categories", h.GetCategories)
			protected.POST("/categories", middleware.RequireRole(domain.RoleAdmin), h.CreateCategory)
			protected.PUT("/categories/:id", middleware.RequireRole(domain.RoleAdmin), h.UpdateCategory)
			protected.DELETE("/categories/:id", middleware.RequireRole(domain.RoleAdmin), h.DeleteCategory)

			// Orders Simulasi
			protected.GET("/orders", h.GetOrders)

			// Order Issues CRUD
			protected.GET("/issues", h.ListIssues)
			protected.POST("/issues", h.CreateIssue)
			protected.GET("/issues/:id", h.GetIssueDetail)
			protected.PUT("/issues/:id", h.UpdateIssue)
			protected.PATCH("/issues/:id/archive", h.ArchiveIssue)
			protected.DELETE("/issues/:id", middleware.RequireRole(domain.RoleAdmin), h.DeleteIssue)

			// Status Transitions & Riwayat
			protected.POST("/issues/:id/transitions", h.TransitionStatus)
			protected.GET("/issues/:id/transitions", h.GetIssueTransitions)
		}
	}

	log.Printf("[INFO] Server KendalaKu aktif mendengarkan pada port :%s", cfg.AppPort)
	if err := r.Run(":" + cfg.AppPort); err != nil {
		log.Fatalf("[FATAL] Gagal menjalankan HTTP server: %v", err)
	}
}
