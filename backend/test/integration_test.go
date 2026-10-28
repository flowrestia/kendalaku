package test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
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
	if migErr := database.RunMigrations(cfg.MigrationDSN(), migrationsDir, cfg.DBName); migErr != nil {
		t.Logf("[MIGRATION WARNING] %v", migErr)
	}
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
			protected.POST("/issues", h.CreateIssue)
			protected.GET("/issues/:id", h.GetIssueDetail)
			protected.PUT("/issues/:id", h.UpdateIssue)
			protected.POST("/issues/:id/transitions", h.TransitionStatus)
			protected.GET("/share/issues", h.ShareText)

			// Fase 3
			protected.GET("/dashboard/summary", h.GetDashboardSummary)
			protected.GET("/dashboard/by-category", h.GetDashboardByCategory)
			protected.GET("/dashboard/trend", h.GetDashboardTrend)
			protected.GET("/reports/recap", h.GetReportRecap)
			protected.GET("/reports/export.csv", h.ExportReportCSV)
			protected.GET("/activities", h.GetActivityLogs)
			// Fase 6
			protected.GET("/issues/:id/comments", h.GetComments)
			protected.POST("/issues/:id/comments", h.CreateComment)
			protected.PATCH("/issues/:id/assign", middleware.RequireRole(domain.RoleAdmin), h.ReassignIssue)
			protected.PATCH("/issues/:id/archive", middleware.RequireRole(domain.RoleAdmin), h.ArchiveIssue)
			protected.DELETE("/issues/:id", middleware.RequireRole(domain.RoleAdmin), h.DeleteIssue)
			protected.GET("/dashboard/due-soon", h.GetIssuesDueSoon)
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

	// Verifikasi field relasi hasil JOIN pada GET /issues
	firstItem := issuesResp.Data.Items[0]
	if firstItem.CategoryNama == "" || firstItem.KodePesanan == "" || firstItem.NamaPelanggan == "" {
		t.Fatalf("Field relasi kosong pada GET /issues: category_nama=%q, kode_pesanan=%q, nama_pelanggan=%q",
			firstItem.CategoryNama, firstItem.KodePesanan, firstItem.NamaPelanggan)
	}
	t.Logf("[SUCCESS] GET /issues memiliki field relasi lengkap: category=%s, order=%s, customer=%s, assigned=%s",
		firstItem.CategoryNama, firstItem.KodePesanan, firstItem.NamaPelanggan, firstItem.AssignedNama)

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

	// 4. Test GET /api/v1/dashboard/summary
	reqSummary, _ := http.NewRequest(http.MethodGet, "/api/v1/dashboard/summary", nil)
	reqSummary.Header.Set("Authorization", "Bearer "+loginResp.Data.Token)
	wSummary := httptest.NewRecorder()
	r.ServeHTTP(wSummary, reqSummary)
	if wSummary.Code != http.StatusOK {
		t.Fatalf("GET /dashboard/summary gagal: %d, body: %s", wSummary.Code, wSummary.Body.String())
	}
	t.Logf("[SUCCESS] GET /dashboard/summary: %s", wSummary.Body.String())

	// 5. Test GET /api/v1/dashboard/by-category
	reqCat, _ := http.NewRequest(http.MethodGet, "/api/v1/dashboard/by-category", nil)
	reqCat.Header.Set("Authorization", "Bearer "+loginResp.Data.Token)
	wCat := httptest.NewRecorder()
	r.ServeHTTP(wCat, reqCat)
	if wCat.Code != http.StatusOK {
		t.Fatalf("GET /dashboard/by-category gagal: %d", wCat.Code)
	}
	var catResp struct {
		Success bool                         `json:"success"`
		Data    []domain.CategoryStatResponse `json:"data"`
	}
	_ = json.Unmarshal(wCat.Body.Bytes(), &catResp)
	for _, c := range catResp.Data {
		if c.WarnaHex == "" {
			t.Errorf("Kategori %s (ID %d) warna_hex kosong!", c.Nama, c.CategoryID)
		}
		if c.Ikon == "" {
			t.Errorf("Kategori %s (ID %d) ikon kosong!", c.Nama, c.CategoryID)
		}
	}
	t.Logf("[SUCCESS] GET /dashboard/by-category: %d kategori valid dengan warna & ikon", len(catResp.Data))

	// 6. Test GET /api/v1/dashboard/trend?period=7d, 30d, 12m (harus tepat 7, 30, dan 12 titik)
	periodsTest := []struct {
		period        string
		expectedCount int
	}{
		{"7d", 7},
		{"30d", 30},
		{"12m", 12},
	}
	for _, pt := range periodsTest {
		reqT, _ := http.NewRequest(http.MethodGet, "/api/v1/dashboard/trend?period="+pt.period, nil)
		reqT.Header.Set("Authorization", "Bearer "+loginResp.Data.Token)
		wT := httptest.NewRecorder()
		r.ServeHTTP(wT, reqT)
		if wT.Code != http.StatusOK {
			t.Fatalf("GET /dashboard/trend?period=%s gagal: %d", pt.period, wT.Code)
		}
		var tResp struct {
			Success bool                        `json:"success"`
			Data    []domain.TrendPointResponse `json:"data"`
		}
		_ = json.Unmarshal(wT.Body.Bytes(), &tResp)
		if len(tResp.Data) != pt.expectedCount {
			t.Fatalf("Jumlah titik trend %s salah: diharapkan %d, didapat %d", pt.period, pt.expectedCount, len(tResp.Data))
		}
		t.Logf("[SUCCESS] GET /dashboard/trend?period=%s menghasilkan tepat %d titik", pt.period, len(tResp.Data))
	}

	// 7. Test GET /api/v1/reports/recap
	reqRecap, _ := http.NewRequest(http.MethodGet, "/api/v1/reports/recap", nil)
	reqRecap.Header.Set("Authorization", "Bearer "+loginResp.Data.Token)
	wRecap := httptest.NewRecorder()
	r.ServeHTTP(wRecap, reqRecap)
	if wRecap.Code != http.StatusOK {
		t.Fatalf("GET /reports/recap gagal: %d", wRecap.Code)
	}
	t.Logf("[SUCCESS] GET /reports/recap: %s", wRecap.Body.String())

	// 8. Test GET /api/v1/reports/export.csv
	reqCSV, _ := http.NewRequest(http.MethodGet, "/api/v1/reports/export.csv", nil)
	reqCSV.Header.Set("Authorization", "Bearer "+loginResp.Data.Token)
	wCSV := httptest.NewRecorder()
	r.ServeHTTP(wCSV, reqCSV)
	if wCSV.Code != http.StatusOK {
		t.Fatalf("GET /reports/export.csv gagal: %d", wCSV.Code)
	}
	// Periksa header Content-Disposition dan encoding UTF-8 BOM
	disp := wCSV.Header().Get("Content-Disposition")
	if disp == "" {
		t.Errorf("Header Content-Disposition tidak ada pada CSV export")
	}
	bodyBytesCSV := wCSV.Body.Bytes()
	if len(bodyBytesCSV) < 3 || bodyBytesCSV[0] != 0xEF || bodyBytesCSV[1] != 0xBB || bodyBytesCSV[2] != 0xBF {
		t.Errorf("Format CSV tidak mengandung UTF-8 BOM")
	}
	t.Logf("[SUCCESS] GET /reports/export.csv: bytes=%d, Content-Disposition=%s", len(bodyBytesCSV), disp)

	// 9. Test GET /api/v1/activities
	reqAct, _ := http.NewRequest(http.MethodGet, "/api/v1/activities", nil)
	reqAct.Header.Set("Authorization", "Bearer "+loginResp.Data.Token)
	wAct := httptest.NewRecorder()
	r.ServeHTTP(wAct, reqAct)
	if wAct.Code != http.StatusOK {
		t.Fatalf("GET /activities gagal: %d", wAct.Code)
	}
	t.Logf("[SUCCESS] GET /activities: %s", wAct.Body.String())

	// 10. Test GET /api/v1/share/issues (Fase 6B: Validasi path baru dan respons 200 dengan text, count, truncated)
	reqShare, _ := http.NewRequest(http.MethodGet, "/api/v1/share/issues?include_customer=true&assigned_to=me", nil)
	reqShare.Header.Set("Authorization", "Bearer "+loginResp.Data.Token)
	wShare := httptest.NewRecorder()
	r.ServeHTTP(wShare, reqShare)
	if wShare.Code != http.StatusOK {
		t.Fatalf("GET /share/issues gagal: status=%d, body=%s", wShare.Code, wShare.Body.String())
	}

	var shareResp struct {
		Success bool `json:"success"`
		Data    struct {
			Text      string `json:"text"`
			Count     int    `json:"count"`
			Truncated bool   `json:"truncated"`
		} `json:"data"`
	}
	if err := json.Unmarshal(wShare.Body.Bytes(), &shareResp); err != nil {
		t.Fatalf("Unmarshal respon share gagal: %v", err)
	}
	if !shareResp.Success {
		t.Errorf("Ekspektasi success=true pada GET /share/issues")
	}
	if !strings.Contains(shareResp.Data.Text, "DAFTAR KENDALA LAYANAN - KENDALAKU") {
		t.Errorf("Field text tidak memuat header WhatsApp: %s", shareResp.Data.Text)
	}
	t.Logf("[SUCCESS] GET /share/issues: count=%d, truncated=%v", shareResp.Data.Count, shareResp.Data.Truncated)

	// 11. Test GET /api/v1/issues/abc (Validasi bahwa non-numeric ID menghasilkan respons 'ID kendala tidak valid')
	reqInvalidID, _ := http.NewRequest(http.MethodGet, "/api/v1/issues/abc", nil)
	reqInvalidID.Header.Set("Authorization", "Bearer "+loginResp.Data.Token)
	wInvalidID := httptest.NewRecorder()
	r.ServeHTTP(wInvalidID, reqInvalidID)
	if wInvalidID.Code != http.StatusBadRequest {
		t.Fatalf("GET /issues/abc harus mengembalikan 400 Bad Request, didapat: %d", wInvalidID.Code)
	}
	if !strings.Contains(wInvalidID.Body.String(), "ID kendala tidak valid") {
		t.Errorf("Respon /issues/abc harus memuat pesan 'ID kendala tidak valid', didapat: %s", wInvalidID.Body.String())
	}
	t.Logf("[SUCCESS] GET /issues/abc: 400 Bad Request 'ID kendala tidak valid'")
}
