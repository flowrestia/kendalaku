package test

import (
	"testing"

	"github.com/flowrestia/kendalaku/backend/internal/domain"
)

// TestValidTransitions menguji semua transisi status yang sah menurut aturan bisnis
func TestValidTransitions(t *testing.T) {
	tests := []struct {
		name                string
		statusLama          string
		statusBaru          string
		catatanPenyelesaian string
	}{
		{
			name:                "baru ke sedang_diproses",
			statusLama:          domain.StatusBaru,
			statusBaru:          domain.StatusSedangDiproses,
			catatanPenyelesaian: "",
		},
		{
			name:                "baru ke ditolak",
			statusLama:          domain.StatusBaru,
			statusBaru:          domain.StatusDitolak,
			catatanPenyelesaian: "",
		},
		{
			name:                "sedang_diproses ke menunggu_informasi",
			statusLama:          domain.StatusSedangDiproses,
			statusBaru:          domain.StatusMenungguInformasi,
			catatanPenyelesaian: "",
		},
		{
			name:                "sedang_diproses ke selesai (ada catatan)",
			statusLama:          domain.StatusSedangDiproses,
			statusBaru:          domain.StatusSelesai,
			catatanPenyelesaian: "Barang berhasil diganti dan dikemas ulang.",
		},
		{
			name:                "sedang_diproses ke ditolak",
			statusLama:          domain.StatusSedangDiproses,
			statusBaru:          domain.StatusDitolak,
			catatanPenyelesaian: "",
		},
		{
			name:                "menunggu_informasi kembali ke sedang_diproses",
			statusLama:          domain.StatusMenungguInformasi,
			statusBaru:          domain.StatusSedangDiproses,
			catatanPenyelesaian: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := domain.ValidateStatusTransition(tt.statusLama, tt.statusBaru, tt.catatanPenyelesaian)
			if err != nil {
				t.Errorf("Ekspektasi transisi valid, namun mendapat error: %v", err)
			}
		})
	}
}

// TestInvalidTransitions menguji penolakan transisi status ilegal
func TestInvalidTransitions(t *testing.T) {
	tests := []struct {
		name                string
		statusLama          string
		statusBaru          string
		catatanPenyelesaian string
		expectedErrMsg      string
	}{
		{
			name:                "status sama tidak boleh diubah",
			statusLama:          domain.StatusBaru,
			statusBaru:          domain.StatusBaru,
			catatanPenyelesaian: "",
			expectedErrMsg:      "status baru sama dengan status saat ini",
		},
		{
			name:                "baru lompat langsung ke selesai (ilegal)",
			statusLama:          domain.StatusBaru,
			statusBaru:          domain.StatusSelesai,
			catatanPenyelesaian: "Selesai langsung",
			expectedErrMsg:      "transisi status dari 'baru' ke 'selesai' tidak diizinkan",
		},
		{
			name:                "baru lompat ke menunggu_informasi (ilegal)",
			statusLama:          domain.StatusBaru,
			statusBaru:          domain.StatusMenungguInformasi,
			catatanPenyelesaian: "",
			expectedErrMsg:      "transisi status dari 'baru' ke 'menunggu_informasi' tidak diizinkan",
		},
		{
			name:                "menunggu_informasi langsung ke selesai (ilegal)",
			statusLama:          domain.StatusMenungguInformasi,
			statusBaru:          domain.StatusSelesai,
			catatanPenyelesaian: "Sudah beres",
			expectedErrMsg:      "transisi status dari 'menunggu_informasi' ke 'selesai' tidak diizinkan",
		},
		{
			name:                "menunggu_informasi ke ditolak (ilegal)",
			statusLama:          domain.StatusMenungguInformasi,
			statusBaru:          domain.StatusDitolak,
			catatanPenyelesaian: "",
			expectedErrMsg:      "transisi status dari 'menunggu_informasi' ke 'ditolak' tidak diizinkan",
		},
		{
			name:                "status akhir selesai tidak boleh diubah lagi",
			statusLama:          domain.StatusSelesai,
			statusBaru:          domain.StatusSedangDiproses,
			catatanPenyelesaian: "",
			expectedErrMsg:      "kendala telah berada pada status akhir (selesai/ditolak) dan tidak dapat diubah lagi",
		},
		{
			name:                "status akhir ditolak tidak boleh diubah lagi",
			statusLama:          domain.StatusDitolak,
			statusBaru:          domain.StatusBaru,
			catatanPenyelesaian: "",
			expectedErrMsg:      "kendala telah berada pada status akhir (selesai/ditolak) dan tidak dapat diubah lagi",
		},
		{
			name:                "status selesai WAJIB punya catatan penyelesaian",
			statusLama:          domain.StatusSedangDiproses,
			statusBaru:          domain.StatusSelesai,
			catatanPenyelesaian: "", // kosong
			expectedErrMsg:      "catatan penyelesaian wajib diisi jika status diubah menjadi selesai",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := domain.ValidateStatusTransition(tt.statusLama, tt.statusBaru, tt.catatanPenyelesaian)
			if err == nil {
				t.Fatalf("Ekspektasi transisi gagal/ditolak, namun berhasil tanpa error")
			}
			if err.Error() != tt.expectedErrMsg {
				t.Errorf("Pesan error berbeda.\nDiharapkan: %s\nDidapat: %s", tt.expectedErrMsg, err.Error())
			}
		})
	}
}
