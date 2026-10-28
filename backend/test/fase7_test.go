package test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/flowrestia/kendalaku/backend/internal/domain"
)

func TestChangePasswordEndpoints(t *testing.T) {
	r := setupTestRouter(t)

	// Helper login untuk mendapatkan token
	login := func(email, password string) string {
		payload := map[string]string{
			"email":    email,
			"password": password,
		}
		bodyBytes, _ := json.Marshal(payload)
		req, _ := http.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewBuffer(bodyBytes))
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		if w.Code != http.StatusOK {
			t.Fatalf("Login gagal untuk %s: status=%d, body=%s", email, w.Code, w.Body.String())
		}

		var res struct {
			Data struct {
				Token string `json:"token"`
			} `json:"data"`
		}
		_ = json.Unmarshal(w.Body.Bytes(), &res)
		return res.Data.Token
	}

	testEmail := "admin@kendalaku.com"
	initialPassword := "password123"
	token := login(testEmail, initialPassword)

	// Pastikan t.Cleanup mengembalikan password semula
	t.Cleanup(func() {
		// Pulihkan password ke initialPassword jika berubah
		payload := map[string]string{
			"email":    testEmail,
			"password": "newpassword456",
		}
		bodyBytes, _ := json.Marshal(payload)
		req, _ := http.NewRequest(http.MethodPost, "/api/v1/auth/login", bytes.NewBuffer(bodyBytes))
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		if w.Code == http.StatusOK {
			var res struct {
				Data struct {
					Token string `json:"token"`
				} `json:"data"`
			}
			_ = json.Unmarshal(w.Body.Bytes(), &res)
			recoveryToken := res.Data.Token
			if recoveryToken != "" {
				restoreReq := domain.ChangePasswordRequest{
					PasswordLama: "newpassword456",
					PasswordBaru: initialPassword,
				}
				b, _ := json.Marshal(restoreReq)
				reqRestore, _ := http.NewRequest(http.MethodPut, "/api/v1/auth/password", bytes.NewBuffer(b))
				reqRestore.Header.Set("Content-Type", "application/json")
				reqRestore.Header.Set("Authorization", "Bearer "+recoveryToken)
				wRestore := httptest.NewRecorder()
				r.ServeHTTP(wRestore, reqRestore)
			}
		}
	})


	// 1. Password lama salah -> ditolak 422
	{
		reqBody := domain.ChangePasswordRequest{
			PasswordLama: "passwordsalah123",
			PasswordBaru: "newpassword456",
		}
		b, _ := json.Marshal(reqBody)
		req, _ := http.NewRequest(http.MethodPut, "/api/v1/auth/password", bytes.NewBuffer(b))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+token)
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		if w.Code != http.StatusUnprocessableEntity {
			t.Errorf("Ekspektasi 422 untuk password lama salah, dapat: %d, body: %s", w.Code, w.Body.String())
		}
	}

	// 2. Password baru terlalu pendek (< 8 karakter) -> ditolak 422
	{
		reqBody := domain.ChangePasswordRequest{
			PasswordLama: initialPassword,
			PasswordBaru: "short",
		}
		b, _ := json.Marshal(reqBody)
		req, _ := http.NewRequest(http.MethodPut, "/api/v1/auth/password", bytes.NewBuffer(b))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+token)
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		if w.Code != http.StatusUnprocessableEntity {
			t.Errorf("Ekspektasi 422 untuk password baru < 8 karakter, dapat: %d, body: %s", w.Code, w.Body.String())
		}
	}

	// 3. Password baru sama dengan password lama -> ditolak 422
	{
		reqBody := domain.ChangePasswordRequest{
			PasswordLama: initialPassword,
			PasswordBaru: initialPassword,
		}
		b, _ := json.Marshal(reqBody)
		req, _ := http.NewRequest(http.MethodPut, "/api/v1/auth/password", bytes.NewBuffer(b))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+token)
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		if w.Code != http.StatusUnprocessableEntity {
			t.Errorf("Ekspektasi 422 untuk password baru sama dengan lama, dapat: %d, body: %s", w.Code, w.Body.String())
		}
	}

	// 4. Ganti password sukses (200)
	newPassword := "newpassword456"
	{
		reqBody := domain.ChangePasswordRequest{
			PasswordLama: initialPassword,
			PasswordBaru: newPassword,
		}
		b, _ := json.Marshal(reqBody)
		req, _ := http.NewRequest(http.MethodPut, "/api/v1/auth/password", bytes.NewBuffer(b))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+token)
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		if w.Code != http.StatusOK {
			t.Fatalf("Ekspektasi 200 untuk ganti password sukses, dapat: %d, body: %s", w.Code, w.Body.String())
		}
	}

	// 5. Verifikasi login berhasil dengan password baru
	{
		newLoginToken := login(testEmail, newPassword)
		if newLoginToken == "" {
			t.Fatalf("Login dengan password baru harus berhasil dan menghasilkan token")
		}

		// Kembalikan ke password semula di sini juga agar state bersih
		restoreReq := domain.ChangePasswordRequest{
			PasswordLama: newPassword,
			PasswordBaru: initialPassword,
		}
		b, _ := json.Marshal(restoreReq)
		req, _ := http.NewRequest(http.MethodPut, "/api/v1/auth/password", bytes.NewBuffer(b))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+newLoginToken)
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		if w.Code != http.StatusOK {
			t.Fatalf("Gagal memulihkan password akun demo: status=%d, body=%s", w.Code, w.Body.String())
		}

		// Cek login kembali normal dengan initialPassword
		verifiedToken := login(testEmail, initialPassword)
		if verifiedToken == "" {
			t.Fatalf("Akun demo harus bisa login kembali dengan password lama")
		}
	}
}
