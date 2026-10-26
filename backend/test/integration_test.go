package test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"

	"github.com/flowrestia/kendalaku/backend/internal/config"
	"github.com/flowrestia/kendalaku/backend/internal/domain"
	"github.com/flowrestia/kendalaku/backend/internal/handler"
	"github.com/flowrestia/kendalaku/backend/internal/middleware"
	"github.com/flowrestia/kendalaku/backend/internal/repository/mysql"
	"github.com/flowrestia/kendalaku/backend/internal/service"
	"github.com/flowrestia/kendalaku/backend/pkg/database"
	"github.com/flowrestia/kendalaku/backend/pkg/jwt"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func setupTestRouter(t *testing.T) *gin.Engine {
	gin.SetMode(gin.TestMode)
	_ = godotenv.Load(filepath.Join("..", ".env"))
	cfg := config.LoadConfig()

	db, err := database.InitDB(cfg.DSN())
	if err != nil {
		t.Skipf("Lewati integration test karena database tidak terjangkau: %v", err)
	}

	migrationsDir := filepath.Join("..", "migrations")
	_ = database.RunMigrations(cfg.MigrationDSN(), migrationsDir, cfg.DBName)
	_ = database.SeedDatabase(db)

	tokenMaker := jwt.NewTokenMaker(cfg.JWTSecret)
	repo := mysql.NewRepository(db)
	svc := service.NewService(repo, tokenMaker, cfg.JWTExpiryHours)
	h := handler.NewHandler(svc)

	r := gin.New()
	api := r.Group("/api/v1")
	{
		api.POST("/auth/login", h.Login)
		protected := api.Group("")
		protected.Use(middleware.AuthMiddleware(tokenMaker))
		{
			protected.GET("/issues", h.ListIssues)
			protected.POST("/issues/:id/transitions", h.TransitionStatus)
		}
	}

	return r
}

func TestLiveEndpoints(t *testing.T) {
	r := setupTestRouter(t)

	// 1. Test POST /api/v1/auth/login
	loginPayload := map[string]string{
		"email":    "admin@kendalaku.com",
		"password": "password123",
	}
	bodyBytes, _ := json.Marshal(loginPayload)
	req, _ := http.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewBuffer(bodyBytes))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("Login gagal, status: %d, body: %s", w.Code, w.Body.String())
	}

	var loginResp struct {
		Success bool `json:"success"`
		Data    struct {
			Token string      `json:"token"`
			User  domain.User `json:"user"`
		} `json:"data"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &loginResp); err != nil {
		t.Fatalf("Gagal unmarshal login resp: %v", err)
	}

	if loginResp.Data.Token == "" {
		t.Fatalf("Token JWT kosong pada response login")
	}
	t.Logf("[SUCCESS] Login berhasil: user=%s, role=%s", loginResp.Data.User.Email, loginResp.Data.User.Role)

	// 2. Test GET /api/v1/issues
	reqIssues, _ := http.NewRequest(http.MethodGet, "/api/v1/issues?limit=5", nil)
	reqIssues.Header.Set("Authorization", "Bearer "+loginResp.Data.Token)
	wIssues := httptest.NewRecorder()
	r.ServeHTTP(wIssues, reqIssues)

	if wIssues.Code != http.StatusOK {
		t.Fatalf("GET /issues gagal, status: %d, body: %s", wIssues.Code, wIssues.Body.String())
	}

	var issuesResp struct {
		Success bool `json:"success"`
		Data    struct {
			Items []domain.OrderIssue `json:"items"`
			Total int                 `json:"total"`
		} `json:"data"`
	}
	if err := json.Unmarshal(wIssues.Body.Bytes(), &issuesResp); err != nil {
		t.Fatalf("Gagal unmarshal issues resp: %v", err)
	}

	if issuesResp.Data.Total == 0 || len(issuesResp.Data.Items) == 0 {
		t.Fatalf("Daftar issues kosong, ekspektasi ada data hasil seed")
	}
	t.Logf("[SUCCESS] GET /issues berhasil: Total=%d, sample item=%s [%s]", issuesResp.Data.Total, issuesResp.Data.Items[0].KodeKendala, issuesResp.Data.Items[0].Status)

	// 3. Test Invalid Status Transition: cari kendala dengan status 'baru' lalu transisikan langsung ke 'selesai' (wajib 422)
	var newIssueID uint64
	for _, it := range issuesResp.Data.Items {
		if it.Status == domain.StatusBaru {
			newIssueID = it.ID
			break
		}
	}
	if newIssueID == 0 {
		newIssueID = issuesResp.Data.Items[0].ID
	}

	invalidTransitionPayload := map[string]string{
		"status_baru":          domain.StatusSelesai,
		"catatan_tindakan":     "Paksa loncat dari baru ke selesai",
		"catatan_penyelesaian": "Catatan penyelesaian fiktif",
	}
	transBytes, _ := json.Marshal(invalidTransitionPayload)
	reqTrans, _ := http.NewRequest(http.MethodPost, "/api/v1/issues/1/transitions", bytes.NewBuffer(transBytes))
	reqTrans.Header.Set("Authorization", "Bearer "+loginResp.Data.Token)
	reqTrans.Header.Set("Content-Type", "application/json")
	wTrans := httptest.NewRecorder()
	r.ServeHTTP(wTrans, reqTrans)

	// Harus mengembalikan 422 Unprocessable Entity
	if wTrans.Code != http.StatusUnprocessableEntity {
		t.Fatalf("Ekspektasi transisi ilegal menghasilkan 422, didapat: %d (Body: %s)", wTrans.Code, wTrans.Body.String())
	}
	t.Logf("[SUCCESS] Transisi status ilegal berhasil ditolak dengan 422: %s", wTrans.Body.String())
}
