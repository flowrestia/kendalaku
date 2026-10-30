











































































































package test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/flowrestia/kendalaku/backend/pkg/response"
	"github.com/gin-gonic/gin"
)

func TestEmptyIssuesListForAdmin(t *testing.T) {
	r := setupTestRouter(t)

	// Login sebagai Admin (admin tidak memiliki issue yang di-assign ke dirinya secara default)
	loginPayload := map[string]string{
		"email":    "admin@kendalaku.com",
		"password": "password123",
	}
	body, _ := json.Marshal(loginPayload)
	req, _ := http.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("Login admin gagal: status=%d, body=%s", w.Code, w.Body.String())
	}

	var loginRes struct {
		Data struct {
			Token string `json:"token"`
		} `json:"data"`
	}
	_ = json.Unmarshal(w.Body.Bytes(), &loginRes)
	token := loginRes.Data.Token

	// GET /api/v1/issues?assigned_to=me
	reqIssues, _ := http.NewRequest(http.MethodGet, "/api/v1/issues?assigned_to=me", nil)
	reqIssues.Header.Set("Authorization", "Bearer "+token)
	wIssues := httptest.NewRecorder()
	r.ServeHTTP(wIssues, reqIssues)

	if wIssues.Code != http.StatusOK {
		t.Fatalf("GET /issues?assigned_to=me gagal: status=%d, body=%s", wIssues.Code, wIssues.Body.String())
	}

	rawBody := wIssues.Body.String()
	if strings.Contains(rawBody, `"items":null`) {
		t.Fatalf("Respons mengandung '\"items\":null', seharusnya '\"items\":[]': %s", rawBody)
	}
	if !strings.Contains(rawBody, `"items":[]`) {
		t.Fatalf("Respons tidak mengandung '\"items\":[]': %s", rawBody)
	}

	var res struct {
		Success bool `json:"success"`
		Data    struct {
			Items []interface{} `json:"items"`
			Total int           `json:"total"`
		} `json:"data"`
	}
	if err := json.Unmarshal(wIssues.Body.Bytes(), &res); err != nil {
		t.Fatalf("Gagal unmarshal JSON: %v", err)
	}

	if res.Data.Items == nil {
		t.Fatalf("res.Data.Items bernilai nil, seharusnya slice kosong []")
	}
}

func TestRouterErrorHandling(t *testing.T) {
	r := setupTestRouter(t)

	// 1. Rute tidak ada -> 404 JSON standar
	t.Run("Route NotFound returns 404 JSON", func(t *testing.T) {
		req, _ := http.NewRequest(http.MethodGet, "/api/v1/route-yang-tidak-pernah-ada-12345", nil)
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		if w.Code != http.StatusNotFound {
			t.Fatalf("Status expected 404, got %d", w.Code)
		}

		var apiRes response.APIResponse
		if err := json.Unmarshal(w.Body.Bytes(), &apiRes); err != nil {
			t.Fatalf("Gagal unmarshal 404 response: %v", err)
		}

		if apiRes.Success {
			t.Errorf("Expected success = false")
		}
		if apiRes.Error == nil || apiRes.Error.Code != "NOT_FOUND" {
			t.Errorf("Expected error.code = 'NOT_FOUND', got %v", apiRes.Error)
		}
		if apiRes.Error.Message != "Endpoint tidak ditemukan" {
			t.Errorf("Expected error.message = 'Endpoint tidak ditemukan', got '%s'", apiRes.Error.Message)
		}
	})

	// 2. Method salah -> 405 JSON standar
	t.Run("Method Not Allowed returns 405 JSON", func(t *testing.T) {
		// Endpoint /api/v1/auth/login hanya menerima POST, kita kirim PUT
		req, _ := http.NewRequest(http.MethodPut, "/api/v1/auth/login", bytes.NewBuffer([]byte("{}")))
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		if w.Code != http.StatusMethodNotAllowed {
			t.Fatalf("Status expected 405, got %d. Body: %s", w.Code, w.Body.String())
		}

		var apiRes response.APIResponse
		if err := json.Unmarshal(w.Body.Bytes(), &apiRes); err != nil {
			t.Fatalf("Gagal unmarshal 405 response: %v", err)
		}

		if apiRes.Success {
			t.Errorf("Expected success = false")
		}
		if apiRes.Error == nil || apiRes.Error.Code != "METHOD_NOT_ALLOWED" {
			t.Errorf("Expected error.code = 'METHOD_NOT_ALLOWED', got %v", apiRes.Error)
		}
		if apiRes.Error.Message != "Metode HTTP tidak diizinkan" {
			t.Errorf("Expected error.message = 'Metode HTTP tidak diizinkan', got '%s'", apiRes.Error.Message)
		}
	})

	// 3. Panic buatan -> 500 JSON standar tanpa stack trace ke klien
	t.Run("Panic Recovery returns 500 JSON without stack trace", func(t *testing.T) {
		// Daftarkan handler panic buatan ke router
		r.GET("/test-panic-endpoint", func(c *gin.Context) {
			panic("crash server tak terduga dengan detail sensitif database")
		})

		req, _ := http.NewRequest(http.MethodGet, "/test-panic-endpoint", nil)
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		if w.Code != http.StatusInternalServerError {
			t.Fatalf("Status expected 500, got %d", w.Code)
		}

		bodyStr := w.Body.String()
		if strings.Contains(bodyStr, "crash server tak terduga") {
			t.Errorf("Pesan panic asli bocor ke klien: %s", bodyStr)
		}
		if strings.Contains(bodyStr, "goroutine") || strings.Contains(bodyStr, "debug.Stack") {
			t.Errorf("Stack trace bocor ke klien: %s", bodyStr)
		}

		var apiRes response.APIResponse
		if err := json.Unmarshal(w.Body.Bytes(), &apiRes); err != nil {
			t.Fatalf("Gagal unmarshal 500 response: %v", err)
		}

		if apiRes.Success {
			t.Errorf("Expected success = false")
		}
		if apiRes.Error == nil || apiRes.Error.Code != "INTERNAL_ERROR" {
			t.Errorf("Expected error.code = 'INTERNAL_ERROR', got %v", apiRes.Error)
		}
		if apiRes.Error.Message != "Terjadi kesalahan pada server" {
			t.Errorf("Expected error.message = 'Terjadi kesalahan pada server', got '%s'", apiRes.Error.Message)
		}
	})

	// 4. Validasi password pendek -> pesan ramah tanpa kata "Key:" atau "Field validation"
	t.Run("Password validation error returns friendly message without leak", func(t *testing.T) {
		// Login untuk mendapatkan token
		loginPayload := map[string]string{
			"email":    "admin@kendalaku.com",
			"password": "password123",
		}
		body, _ := json.Marshal(loginPayload)
		req, _ := http.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewBuffer(body))
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		var loginRes struct {
			Data struct {
				Token string `json:"token"`
			} `json:"data"`
		}
		_ = json.Unmarshal(w.Body.Bytes(), &loginRes)
		token := loginRes.Data.Token

		// Ubah password dengan password baru terlalu pendek (< 8 karakter)
		changePayload := map[string]string{
			"password_lama": "password123",
			"password_baru": "short",
		}
		changeBody, _ := json.Marshal(changePayload)
		reqChange, _ := http.NewRequest(http.MethodPut, "/api/v1/auth/password", bytes.NewBuffer(changeBody))
		reqChange.Header.Set("Content-Type", "application/json")
		reqChange.Header.Set("Authorization", "Bearer "+token)
		wChange := httptest.NewRecorder()
		r.ServeHTTP(wChange, reqChange)

		if wChange.Code != http.StatusUnprocessableEntity {
			t.Fatalf("Expected 422 Unprocessable Entity, got %d. Body: %s", wChange.Code, wChange.Body.String())
		}

		bodyStr := wChange.Body.String()
		if strings.Contains(bodyStr, "Key:") {
			t.Errorf("Body bocor mengandung kata 'Key:': %s", bodyStr)
		}
		if strings.Contains(bodyStr, "Field validation") {
			t.Errorf("Body bocor mengandung kata 'Field validation': %s", bodyStr)
		}
		if !strings.Contains(bodyStr, "Kata sandi baru minimal 8 karakter") {
			t.Errorf("Body tidak memuat pesan ramah 'Kata sandi baru minimal 8 karakter': %s", bodyStr)
		}
	})
}
