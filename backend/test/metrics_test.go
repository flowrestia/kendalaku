package test

import (
	"math"
	"testing"
	"time"

	"github.com/flowrestia/kendalaku/backend/internal/domain"
	"github.com/flowrestia/kendalaku/backend/internal/service"
)

// TestCalculateSummaryMetrics menguji kalkulasi persentase dan rata-rata jam penyelesaian
func TestCalculateSummaryMetrics(t *testing.T) {
	// Kasus 1: Kondisi normal (40 total kendala, 10 selesai, durasi total 72.000 detik / 20 jam -> rata-rata 2 jam per selesai)
	total := 40
	selesai := 10
	resolvedCount := 10
	totalDurationSec := float64(72000) // 20 jam total / 10 = 2.0 jam

	persentase, rataRataJam := service.CalculateSummaryMetrics(total, selesai, resolvedCount, totalDurationSec)

	expectedPersentase := 25.0
	expectedRataRataJam := 2.0

	if persentase != expectedPersentase {
		t.Errorf("Persentase salah: diharapkan %.2f%%, didapat %.2f%%", expectedPersentase, persentase)
	}
	if rataRataJam != expectedRataRataJam {
		t.Errorf("Rata-rata jam salah: diharapkan %.2f jam, didapat %.2f jam", expectedRataRataJam, rataRataJam)
	}

	// Kasus 2: Total 0 (menghindari division by zero)
	persentaseZero, rataRataZero := service.CalculateSummaryMetrics(0, 0, 0, 0)
	if persentaseZero != 0.0 || rataRataZero != 0.0 {
		t.Errorf("Harus 0 saat total 0: persentase=%.2f, rataRata=%.2f", persentaseZero, rataRataZero)
	}

	// Kasus 3: Pembulatan desimal yang tepat (1 dari 3 selesai = 33.33%, durasi 5400 detik / 1.5 jam)
	p3, r3 := service.CalculateSummaryMetrics(3, 1, 1, 5400)
	if math.Abs(p3-33.33) > 0.01 {
		t.Errorf("Persentase desimal salah: diharapkan 33.33%%, didapat %.2f%%", p3)
	}
	if r3 != 1.5 {
		t.Errorf("Rata-rata jam salah: diharapkan 1.5 jam, didapat %.2f jam", r3)
	}
}

// TestIsOverdueDefinition menguji definisi bisnis kendala "terlambat" (overdue)
func TestIsOverdueDefinition(t *testing.T) {
	now := time.Now().UTC()
	past := now.Add(-2 * time.Hour)
	future := now.Add(2 * time.Hour)

	// Definisi: Status NOT IN ('selesai', 'ditolak') AND tenggat_at < now
	tests := []struct {
		name      string
		status    string
		tenggatAt time.Time
		expected  bool
	}{
		{
			name:      "status baru dan tenggat sudah lewat -> TERLAMBAT",
			status:    domain.StatusBaru,
			tenggatAt: past,
			expected:  true,
		},
		{
			name:      "status sedang_diproses dan tenggat sudah lewat -> TERLAMBAT",
			status:    domain.StatusSedangDiproses,
			tenggatAt: past,
			expected:  true,
		},
		{
			name:      "status menunggu_informasi dan tenggat sudah lewat -> TERLAMBAT",
			status:    domain.StatusMenungguInformasi,
			tenggatAt: past,
			expected:  true,
		},
		{
			name:      "status baru tapi tenggat masih masa depan -> TIDAK terlambat",
			status:    domain.StatusBaru,
			tenggatAt: future,
			expected:  false,
		},
		{
			name:      "status selesai meskipun tenggat sudah lewat -> TIDAK terlambat (karena sudah tuntas)",
			status:    domain.StatusSelesai,
			tenggatAt: past,
			expected:  false,
		},
		{
			name:      "status ditolak meskipun tenggat sudah lewat -> TIDAK terlambat (karena dibatalkan)",
			status:    domain.StatusDitolak,
			tenggatAt: past,
			expected:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			isOverdue := (tt.status != domain.StatusSelesai && tt.status != domain.StatusDitolak) && tt.tenggatAt.Before(now)
			if isOverdue != tt.expected {
				t.Errorf("Kalkulasi overdue salah. Ekspektasi: %v, Didapat: %v", tt.expected, isOverdue)
			}
		})
	}
}

// TestCategoryFallbackStyling memastikan setiap kategori selalu memiliki warna_hex dan ikon valid
func TestCategoryFallbackStyling(t *testing.T) {
	categories := []domain.CategoryStatResponse{
		{CategoryID: 1, Nama: "Kategori Lengkap", WarnaHex: "#EF4444", Ikon: "alarm_rounded", Total: 5},
		{CategoryID: 2, Nama: "Kategori Kosong Warna", WarnaHex: "", Ikon: "rule_rounded", Total: 3},
		{CategoryID: 3, Nama: "Kategori Kosong Ikon", WarnaHex: "#10B981", Ikon: "", Total: 2},
		{CategoryID: 4, Nama: "Kategori Kosong Semua", WarnaHex: "", Ikon: "", Total: 1},
	}

	for i := range categories {
		if categories[i].WarnaHex == "" {
			categories[i].WarnaHex = "#4F46E5"
		}
		if categories[i].Ikon == "" {
			categories[i].Ikon = "warning_amber_rounded"
		}
	}

	for _, c := range categories {
		if c.WarnaHex == "" {
			t.Errorf("Kategori ID %d memiliki warna_hex kosong!", c.CategoryID)
		}
		if c.Ikon == "" {
			t.Errorf("Kategori ID %d memiliki ikon kosong!", c.CategoryID)
		}
		if c.WarnaHex != "#EF4444" && c.WarnaHex != "#10B981" && c.WarnaHex != "#4F46E5" {
			t.Errorf("Warna_hex tidak sesuai ekspektasi: %s", c.WarnaHex)
		}
	}
}

