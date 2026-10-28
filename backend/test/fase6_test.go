package test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"

	"github.com/flowrestia/kendalaku/backend/internal/config"
	"github.com/flowrestia/kendalaku/backend/internal/domain"
	"github.com/flowrestia/kendalaku/backend/pkg/database"
)

func TestFase6Features(t *testing.T) {
	r := setupTestRouter(t)

	// 1. Login Admin
	adminPayload := map[string]string{
		"email":    "admin@kendalaku.com",
		"password": "password123",
	}
	bAdmin, _ := json.Marshal(adminPayload)
	reqAdminLogin, _ := http.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewBuffer(bAdmin))
	reqAdminLogin.Header.Set("Content-Type", "application/json")
	wAdminLogin := httptest.NewRecorder()
	r.ServeHTTP(wAdminLogin, reqAdminLogin)

	var adminLoginResp struct {
		Success bool `json:"success"`
		Data    struct {
			Token string `json:"token"`
			User  struct {
				ID   uint64 `json:"id"`
				Nama string `json:"nama"`
				Role string `json:"role"`
			} `json:"user"`
		} `json:"data"`
	}
	_ = json.Unmarshal(wAdminLogin.Body.Bytes(), &adminLoginResp)
	adminToken := adminLoginResp.Data.Token

	// 2. Login Petugas (Rina Petugas, id 2)
	petugasPayload := map[string]string{
		"email":    "petugas1@kendalaku.com",
		"password": "password123",
	}
	bPetugas, _ := json.Marshal(petugasPayload)
	reqPetugasLogin, _ := http.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewBuffer(bPetugas))
	reqPetugasLogin.Header.Set("Content-Type", "application/json")
	wPetugasLogin := httptest.NewRecorder()
	r.ServeHTTP(wPetugasLogin, reqPetugasLogin)

	var petugasLoginResp struct {
		Success bool `json:"success"`
		Data    struct {
			Token string `json:"token"`
			User  struct {
				ID   uint64 `json:"id"`
				Nama string `json:"nama"`
				Role string `json:"role"`
			} `json:"user"`
		} `json:"data"`
	}
	_ = json.Unmarshal(wPetugasLogin.Body.Bytes(), &petugasLoginResp)
	petugasToken := petugasLoginResp.Data.Token
	petugasID := petugasLoginResp.Data.User.ID

	// 3. Ambil daftar kendala
	reqIssues, _ := http.NewRequest(http.MethodGet, "/api/v1/issues?limit=50", nil)
	reqIssues.Header.Set("Authorization", "Bearer "+adminToken)
	wIssues := httptest.NewRecorder()
	r.ServeHTTP(wIssues, reqIssues)

	var issuesResp struct {
		Data struct {
			Items []domain.OrderIssue `json:"items"`
		} `json:"data"`
	}
	_ = json.Unmarshal(wIssues.Body.Bytes(), &issuesResp)
	if len(issuesResp.Data.Items) == 0 {
		t.Fatalf("Data kendala kosong di database")
	}

	// Cari kendala yang BUKAN milik petugas 1 (assigned_to != petugasID)
	var otherIssueID uint64
	var finalIssueID uint64

	for _, item := range issuesResp.Data.Items {
		if item.Status == domain.StatusSelesai || item.Status == domain.StatusDitolak {
			finalIssueID = item.ID
		}
		if (item.AssignedTo == nil || *item.AssignedTo != petugasID) && item.Status != domain.StatusSelesai && item.Status != domain.StatusDitolak {
			otherIssueID = item.ID
		}
	}

	// A. TEST HAK AKSES ROLE (Petugas ditolak 403 FORBIDDEN pada kendala orang lain)
	if otherIssueID > 0 {
		// Petugas coba transisi status kendala orang lain -> harus 403 FORBIDDEN
		transBody := map[string]string{
			"status_baru":      "sedang_diproses",
			"catatan_tindakan": "Uji transisi oleh petugas",
		}
		bTrans, _ := json.Marshal(transBody)
		reqTrans, _ := http.NewRequest(http.MethodPost, "/api/v1/issues/"+jsonNumber(otherIssueID)+"/transitions", bytes.NewBuffer(bTrans))
		reqTrans.Header.Set("Authorization", "Bearer "+petugasToken)
		reqTrans.Header.Set("Content-Type", "application/json")
		wTrans := httptest.NewRecorder()
		r.ServeHTTP(wTrans, reqTrans)
		if wTrans.Code != http.StatusForbidden {
			t.Errorf("Petugas harus ditolak 403 saat transisi kendala orang lain, didapat: %d, body: %s", wTrans.Code, wTrans.Body.String())
		}
	}

	// B. TEST KOMENTAR (Membaca dan membuat komentar)
	firstIssue := issuesResp.Data.Items[0]
	// GET comments
	reqGetComments, _ := http.NewRequest(http.MethodGet, "/api/v1/issues/"+jsonNumber(firstIssue.ID)+"/comments", nil)
	reqGetComments.Header.Set("Authorization", "Bearer "+petugasToken)
	wGetComments := httptest.NewRecorder()
	r.ServeHTTP(wGetComments, reqGetComments)
	if wGetComments.Code != http.StatusOK {
		t.Fatalf("GET /issues/:id/comments gagal: status=%d, body=%s", wGetComments.Code, wGetComments.Body.String())
	}

	// POST comment oleh petugas (semua user login boleh)
	commentBody := map[string]string{
		"isi": "Ini komentar pengujian dari petugas lapangan.",
	}
	bComm, _ := json.Marshal(commentBody)
	reqPostComm, _ := http.NewRequest(http.MethodPost, "/api/v1/issues/"+jsonNumber(firstIssue.ID)+"/comments", bytes.NewBuffer(bComm))
	reqPostComm.Header.Set("Authorization", "Bearer "+petugasToken)
	reqPostComm.Header.Set("Content-Type", "application/json")
	wPostComm := httptest.NewRecorder()
	r.ServeHTTP(wPostComm, reqPostComm)
	if wPostComm.Code != http.StatusCreated {
		t.Fatalf("POST /issues/:id/comments gagal: status=%d, body=%s", wPostComm.Code, wPostComm.Body.String())
	}

	// POST comment kosong -> 400 Bad Request
	badComm, _ := json.Marshal(map[string]string{"isi": ""})
	reqBadComm, _ := http.NewRequest(http.MethodPost, "/api/v1/issues/"+jsonNumber(firstIssue.ID)+"/comments", bytes.NewBuffer(badComm))
	reqBadComm.Header.Set("Authorization", "Bearer "+petugasToken)
	reqBadComm.Header.Set("Content-Type", "application/json")
	wBadComm := httptest.NewRecorder()
	r.ServeHTTP(wBadComm, reqBadComm)
	if wBadComm.Code != http.StatusBadRequest {
		t.Errorf("Ekspektasi 400 pada komentar kosong, didapat: %d", wBadComm.Code)
	}

	// C. TEST REASSIGN
	// Non-admin coba reassign -> 403 Forbidden dari middleware RequireRole
	reassignPayload := map[string]interface{}{
		"assigned_to": 3, // Budi Penanganan
		"catatan":     "Dialihkan untuk pembagian beban kerja",
	}
	bReassign, _ := json.Marshal(reassignPayload)
	reqReassignPetugas, _ := http.NewRequest(http.MethodPatch, "/api/v1/issues/"+jsonNumber(firstIssue.ID)+"/assign", bytes.NewBuffer(bReassign))
	reqReassignPetugas.Header.Set("Authorization", "Bearer "+petugasToken)
	reqReassignPetugas.Header.Set("Content-Type", "application/json")
	wReassignPetugas := httptest.NewRecorder()
	r.ServeHTTP(wReassignPetugas, reqReassignPetugas)
	if wReassignPetugas.Code != http.StatusForbidden {
		t.Errorf("Petugas non-admin harus ditolak 403 saat reassign, didapat: %d", wReassignPetugas.Code)
	}

	// Reassign kendala berstatus final (selesai/ditolak) -> 422 Unprocessable Entity
	if finalIssueID > 0 {
		reqReassignFinal, _ := http.NewRequest(http.MethodPatch, "/api/v1/issues/"+jsonNumber(finalIssueID)+"/assign", bytes.NewBuffer(bReassign))
		reqReassignFinal.Header.Set("Authorization", "Bearer "+adminToken)
		reqReassignFinal.Header.Set("Content-Type", "application/json")
		wReassignFinal := httptest.NewRecorder()
		r.ServeHTTP(wReassignFinal, reqReassignFinal)
		if wReassignFinal.Code != http.StatusUnprocessableEntity {
			t.Errorf("Reassign kendala status final harus mengembalikan 422, didapat: %d", wReassignFinal.Code)
		}
	}

	// Reassign ke petugas tidak valid (user id 999999) -> 422
	badUserPayload := map[string]interface{}{
		"assigned_to": 999999,
		"catatan":     "User tidak ada",
	}
	bBadUser, _ := json.Marshal(badUserPayload)
	reqReassignBadUser, _ := http.NewRequest(http.MethodPatch, "/api/v1/issues/"+jsonNumber(firstIssue.ID)+"/assign", bytes.NewBuffer(bBadUser))
	reqReassignBadUser.Header.Set("Authorization", "Bearer "+adminToken)
	reqReassignBadUser.Header.Set("Content-Type", "application/json")
	wReassignBadUser := httptest.NewRecorder()
	r.ServeHTTP(wReassignBadUser, reqReassignBadUser)
	if wReassignBadUser.Code != http.StatusUnprocessableEntity {
		t.Errorf("Reassign ke user non-existent harus mengembalikan 422, didapat: %d", wReassignBadUser.Code)
	}

	// Reassign valid oleh Admin
	var activeIssueID uint64
	for _, it := range issuesResp.Data.Items {
		if it.Status != domain.StatusSelesai && it.Status != domain.StatusDitolak {
			activeIssueID = it.ID
			break
		}
	}
	if activeIssueID > 0 {
		reqValidReassign, _ := http.NewRequest(http.MethodPatch, "/api/v1/issues/"+jsonNumber(activeIssueID)+"/assign", bytes.NewBuffer(bReassign))
		reqValidReassign.Header.Set("Authorization", "Bearer "+adminToken)
		reqValidReassign.Header.Set("Content-Type", "application/json")
		wValidReassign := httptest.NewRecorder()
		r.ServeHTTP(wValidReassign, reqValidReassign)
		if wValidReassign.Code != http.StatusOK {
			t.Fatalf("Reassign valid oleh admin gagal: status=%d, body=%s", wValidReassign.Code, wValidReassign.Body.String())
		}
	}

	// D. TEST DUE-SOON & DASHBOARD SUMMARY JATUH TEMPO SEGERA
	// Skenario: masukkan data kendala uji dengan tenggat di masa lalu, dekat (< 24 jam), dan jauh (> 24 jam)
	cfg := config.LoadConfig()
	testDB, err := database.InitDB(cfg.DSN())
	if err == nil {
		defer testDB.Close()
		// Bersihkan kendala uji sebelumnya jika ada
		_, _ = testDB.Exec("DELETE FROM order_issues WHERE kode_kendala IN ('TEST-DUE-PAST', 'TEST-DUE-NEAR', 'TEST-DUE-FAR')")

		// 1. Tenggat di masa lalu (tenggat_at = UTC_TIMESTAMP() - INTERVAL 2 HOUR)
		_, errPast := testDB.Exec(`
			INSERT INTO order_issues (kode_kendala, order_id, category_id, judul, deskripsi, prioritas, status, tenggat_at, assigned_to, is_archived, created_by, created_at, updated_at)
			VALUES ('TEST-DUE-PAST', 1, 1, 'Uji Tenggat Lewat', 'Tenggat 2 jam lalu', 'tinggi', 'sedang_diproses', UTC_TIMESTAMP() - INTERVAL 2 HOUR, 2, 0, 1, UTC_TIMESTAMP() - INTERVAL 5 HOUR, UTC_TIMESTAMP())`)
		if errPast != nil {
			t.Logf("Warning insert TEST-DUE-PAST: %v", errPast)
		}

		// 2. Tenggat dekat (< 24 jam, tenggat_at = UTC_TIMESTAMP() + INTERVAL 5 HOUR)
		_, errNear := testDB.Exec(`
			INSERT INTO order_issues (kode_kendala, order_id, category_id, judul, deskripsi, prioritas, status, tenggat_at, assigned_to, is_archived, created_by, created_at, updated_at)
			VALUES ('TEST-DUE-NEAR', 1, 1, 'Uji Tenggat Dekat', 'Tenggat 5 jam ke depan', 'kritis', 'baru', UTC_TIMESTAMP() + INTERVAL 5 HOUR, 2, 0, 1, UTC_TIMESTAMP(), UTC_TIMESTAMP())`)
		if errNear != nil {
			t.Logf("Warning insert TEST-DUE-NEAR: %v", errNear)
		}

		// 3. Tenggat jauh (> 24 jam, tenggat_at = UTC_TIMESTAMP() + INTERVAL 48 HOUR)
		_, errFar := testDB.Exec(`
			INSERT INTO order_issues (kode_kendala, order_id, category_id, judul, deskripsi, prioritas, status, tenggat_at, assigned_to, is_archived, created_by, created_at, updated_at)
			VALUES ('TEST-DUE-FAR', 1, 1, 'Uji Tenggat Jauh', 'Tenggat 48 jam ke depan', 'rendah', 'baru', UTC_TIMESTAMP() + INTERVAL 48 HOUR, 2, 0, 1, UTC_TIMESTAMP(), UTC_TIMESTAMP())`)
		if errFar != nil {
			t.Logf("Warning insert TEST-DUE-FAR: %v", errFar)
		}

		defer func() {
			_, _ = testDB.Exec("DELETE FROM order_issues WHERE kode_kendala IN ('TEST-DUE-PAST', 'TEST-DUE-NEAR', 'TEST-DUE-FAR')")
		}()
	}

	// Panggil GET /dashboard/due-soon?hours=24
	reqDueSoon, _ := http.NewRequest(http.MethodGet, "/api/v1/dashboard/due-soon?hours=24", nil)
	reqDueSoon.Header.Set("Authorization", "Bearer "+adminToken)
	wDueSoon := httptest.NewRecorder()
	r.ServeHTTP(wDueSoon, reqDueSoon)
	if wDueSoon.Code != http.StatusOK {
		t.Fatalf("GET /dashboard/due-soon gagal: status=%d", wDueSoon.Code)
	}

	var dueSoonResp struct {
		Success bool                `json:"success"`
		Data    []domain.OrderIssue `json:"data"`
	}
	if err := json.Unmarshal(wDueSoon.Body.Bytes(), &dueSoonResp); err != nil {
		t.Fatalf("Gagal unmarshal due-soon response: %v", err)
	}

	// Pastikan hanya yang dekat (TEST-DUE-NEAR) yang muncul, dan TEST-DUE-PAST serta TEST-DUE-FAR TIDAK muncul
	hasNear := false
	for _, it := range dueSoonResp.Data {
		if it.KodeKendala == "TEST-DUE-PAST" {
			t.Errorf("BUG: Kendala yang sudah lewat (TEST-DUE-PAST) tidak boleh muncul di due-soon!")
		}
		if it.KodeKendala == "TEST-DUE-FAR" {
			t.Errorf("BUG: Kendala dengan tenggat > 24 jam (TEST-DUE-FAR) tidak boleh muncul di due-soon 24 jam!")
		}
		if it.KodeKendala == "TEST-DUE-NEAR" {
			hasNear = true
		}
	}
	if !hasNear {
		t.Errorf("Kendala dengan tenggat dekat (TEST-DUE-NEAR) harus muncul di due-soon 24 jam!")
	}

	// Cek GET /dashboard/summary memiliki field jatuh_tempo_segera yang nilainya SAMA PERSIS dengan jumlah item due-soon 24 jam
	reqSummary, _ := http.NewRequest(http.MethodGet, "/api/v1/dashboard/summary", nil)
	reqSummary.Header.Set("Authorization", "Bearer "+adminToken)
	wSummary := httptest.NewRecorder()
	r.ServeHTTP(wSummary, reqSummary)
	if wSummary.Code != http.StatusOK {
		t.Fatalf("GET /dashboard/summary gagal: status=%d", wSummary.Code)
	}

	var sumResp struct {
		Data struct {
			JatuhTempoSegera int `json:"jatuh_tempo_segera"`
		} `json:"data"`
	}
	if err := json.Unmarshal(wSummary.Body.Bytes(), &sumResp); err != nil {
		t.Fatalf("Gagal unmarshal dashboard summary: %v", err)
	}

	if sumResp.Data.JatuhTempoSegera != len(dueSoonResp.Data) {
		t.Errorf("Inkonsistensi: jatuh_tempo_segera (%d) tidak sama dengan jumlah item due-soon 24 jam (%d)", sumResp.Data.JatuhTempoSegera, len(dueSoonResp.Data))
	}
	t.Logf("[SUCCESS] Dashboard Summary Jatuh Tempo Segera (%d) konsisten dengan due-soon count (%d)", sumResp.Data.JatuhTempoSegera, len(dueSoonResp.Data))

	// E. TEST PETUGAS DITOLAK 403 PADA KENDALA ORANG LAIN
	if otherIssueID > 0 {
		updatePayload := map[string]interface{}{
			"judul":     "Judul Diperbarui",
			"deskripsi": "Coba ubah tanpa izin",
			"prioritas": "sedang",
		}
		bUpd, _ := json.Marshal(updatePayload)
		reqUpd, _ := http.NewRequest(http.MethodPut, "/api/v1/issues/"+jsonNumber(otherIssueID), bytes.NewBuffer(bUpd))
		reqUpd.Header.Set("Authorization", "Bearer "+petugasToken)
		reqUpd.Header.Set("Content-Type", "application/json")
		wUpd := httptest.NewRecorder()
		r.ServeHTTP(wUpd, reqUpd)
		if wUpd.Code != http.StatusForbidden {
			t.Errorf("Petugas harus ditolak 403 saat update kendala orang lain, didapat: %d", wUpd.Code)
		}

		// Admin coba update kendala yang sama -> lolos (200)
		reqUpdAdmin, _ := http.NewRequest(http.MethodPut, "/api/v1/issues/"+jsonNumber(otherIssueID), bytes.NewBuffer(bUpd))
		reqUpdAdmin.Header.Set("Authorization", "Bearer "+adminToken)
		reqUpdAdmin.Header.Set("Content-Type", "application/json")
		wUpdAdmin := httptest.NewRecorder()
		r.ServeHTTP(wUpdAdmin, reqUpdAdmin)
		if wUpdAdmin.Code != http.StatusOK {
			t.Errorf("Admin harus lolos update kendala, didapat: %d", wUpdAdmin.Code)
		}
	}
}

func jsonNumber(n uint64) string {
	return strconv.FormatUint(n, 10)
}
