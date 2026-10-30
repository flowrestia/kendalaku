package handler

import (
	"net/http"

	"github.com/flowrestia/kendalaku/backend/internal/domain"
	"github.com/flowrestia/kendalaku/backend/internal/middleware"
	"github.com/flowrestia/kendalaku/backend/pkg/jwt"
	"github.com/flowrestia/kendalaku/backend/pkg/response"
	"github.com/gin-gonic/gin"
)

// SetupRouter menginisialisasi router Gin dengan middleware, penanganan 404/405 standar, dan seluruh rute API
func SetupRouter(h *Handler, tokenMaker *jwt.TokenMaker) *gin.Engine {
	r := gin.New()
	r.HandleMethodNotAllowed = true

	r.Use(gin.Logger())
	r.Use(response.CustomRecovery())
	r.Use(middleware.CORSMiddleware())

	// NoRoute handler standar (404)
	r.NoRoute(func(c *gin.Context) {
		c.JSON(http.StatusNotFound, response.APIResponse{
			Success: false,
			Data:    nil,
			Error: &response.ErrorDetail{
				Code:    "NOT_FOUND",
				Message: "Endpoint tidak ditemukan",
			},
		})
	})

	// NoMethod handler standar (405)
	r.NoMethod(func(c *gin.Context) {
		c.JSON(http.StatusMethodNotAllowed, response.APIResponse{
			Success: false,
			Data:    nil,
			Error: &response.ErrorDetail{
				Code:    "METHOD_NOT_ALLOWED",
				Message: "Metode HTTP tidak diizinkan",
			},
		})
	})

	// Health check endpoint
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "healthy", "service": "KendalaKu API"})
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
			protected.PUT("/auth/password", h.ChangePassword)
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
			protected.PATCH("/issues/:id/archive", middleware.RequireRole(domain.RoleAdmin), h.ArchiveIssue)
			protected.DELETE("/issues/:id", middleware.RequireRole(domain.RoleAdmin), h.DeleteIssue)

			// Fase 6: Reassign & Komentar
			protected.PATCH("/issues/:id/assign", middleware.RequireRole(domain.RoleAdmin), h.ReassignIssue)
			protected.GET("/issues/:id/comments", h.GetComments)
			protected.POST("/issues/:id/comments", h.CreateComment)

			// Share WhatsApp (Fase 6B)
			protected.GET("/share/issues", h.ShareText)

			// Status Transitions & Riwayat
			protected.POST("/issues/:id/transitions", h.TransitionStatus)
			protected.GET("/issues/:id/transitions", h.GetIssueTransitions)

			// Fase 3 & Fase 6: Dashboard & Analitik
			protected.GET("/dashboard/summary", h.GetDashboardSummary)
			protected.GET("/dashboard/by-category", h.GetDashboardByCategory)
			protected.GET("/dashboard/trend", h.GetDashboardTrend)
			protected.GET("/dashboard/due-soon", h.GetIssuesDueSoon)

			// Fase 3: Rekap Laporan & Ekspor CSV
			protected.GET("/reports/recap", h.GetReportRecap)
			protected.GET("/reports/export.csv", h.ExportReportCSV)

			// Fase 3: Riwayat Aktivitas Seluruh Kendala
			protected.GET("/activities", h.GetActivityLogs)
		}
	}

	return r
}

