package test

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/flowrestia/kendalaku/backend/internal/domain"
	"github.com/flowrestia/kendalaku/backend/internal/service"
)

func TestFormatIssuesShareText_BasicAndFormatting(t *testing.T) {
	now := time.Date(2026, 10, 27, 10, 0, 0, 0, time.UTC)
	tenggatOverdue := now.Add(-3 * time.Hour)
	tenggatFuture := now.Add(4 * time.Hour)

	items := []domain.OrderIssue{
		{
			ID:            1,
			KodeKendala:   "KND-001",
			Prioritas:     "kritis",
			Judul:         "Paket Rusak Parah",
			KodePesanan:   "ORD-101",
			NamaPelanggan: "Budi Santoso",
			Status:        "baru",
			AssignedNama:  "Ahmad",
			TenggatAt:     tenggatOverdue,
			IsOverdue:     true,
		},
		{
			ID:            2,
			KodeKendala:   "KND-002",
			Prioritas:     "sedang",
			Judul:         "Keterlambatan Pengiriman",
			KodePesanan:   "ORD-102",
			NamaPelanggan: "Siti Rahma",
			Status:        "sedang_diproses",
			AssignedNama:  "Doni",
			TenggatAt:     tenggatFuture,
			IsOverdue:     false,
		},
	}

	filter := domain.IssueFilter{
		Status: "baru",
	}

	res := service.FormatIssuesShareText(items, 2, filter, true, now)

	if res.Count != 2 {
		t.Errorf("Ekspektasi total count 2, didapat %d", res.Count)
	}
	if res.Truncated {
		t.Errorf("Ekspektasi truncated false saat item <= 20")
	}

	text := res.Text
	// 1. Judul dan header WhatsApp
	if !strings.Contains(text, "*DAFTAR KENDALA LAYANAN - KENDALAKU*") {
		t.Errorf("Header tidak sesuai format: %s", text)
	}
	if !strings.Contains(text, "Waktu Cetak: 27/10/2026 17:00 WIB") {
		t.Errorf("Waktu cetak WIB salah (UTC 10:00 -> WIB 17:00): %s", text)
	}

	// 2. Format *tebal* kode kendala & prioritas
	if !strings.Contains(text, "1. *[KND-001]* *[KRITIS]* Paket Rusak Parah") {
		t.Errorf("Format item 1 salah: %s", text)
	}
	// 3. Nama pelanggan ditampilkan jika includeCustomer = true
	if !strings.Contains(text, "ORD-101 (Budi Santoso)") {
		t.Errorf("Nama pelanggan tidak muncul saat include_customer=true: %s", text)
	}

	// 4. Keterangan terlambat / sisa jam
	if !strings.Contains(text, "Terlambat 3 jam") {
		t.Errorf("Keterangan terlambat jam salah: %s", text)
	}
	if !strings.Contains(text, "Sisa 4 jam") {
		t.Errorf("Keterangan sisa jam salah: %s", text)
	}
}

func TestFormatIssuesShareText_IncludeCustomerFalse(t *testing.T) {
	now := time.Date(2026, 10, 27, 10, 0, 0, 0, time.UTC)
	items := []domain.OrderIssue{
		{
			ID:            1,
			KodeKendala:   "KND-001",
			Prioritas:     "tinggi",
			Judul:         "Salah Produk",
			KodePesanan:   "ORD-202",
			NamaPelanggan: "Rahman Hakim",
			Status:        "baru",
			AssignedNama:  "Admin",
			TenggatAt:     now.Add(2 * time.Hour),
		},
	}

	res := service.FormatIssuesShareText(items, 1, domain.IssueFilter{}, false, now)

	// Nama pelanggan TIDAK boleh ada dalam teks saat includeCustomer=false
	if strings.Contains(res.Text, "Rahman Hakim") {
		t.Errorf("Nama pelanggan bocor saat include_customer=false: %s", res.Text)
	}
	if !strings.Contains(res.Text, "Pesanan: ORD-202\n") {
		t.Errorf("Nomor pesanan harus tetap tampil tanpa nama pelanggan: %s", res.Text)
	}
}

func TestFormatIssuesShareText_SortingOrder(t *testing.T) {
	now := time.Date(2026, 10, 27, 10, 0, 0, 0, time.UTC)

	// Buat 4 item:
	// Item A: tidak terlambat, prioritas kritis, tenggat 5 jam lagi
	// Item B: terlambat, prioritas sedang, tenggat 2 jam lalu
	// Item C: terlambat, prioritas kritis, tenggat 1 jam lalu
	// Item D: tidak terlambat, prioritas rendah, tenggat 1 jam lagi
	items := []domain.OrderIssue{
		{
			ID:          1,
			KodeKendala: "KND-A",
			Prioritas:   "kritis",
			TenggatAt:   now.Add(5 * time.Hour),
			IsOverdue:   false,
		},
		{
			ID:          2,
			KodeKendala: "KND-B",
			Prioritas:   "sedang",
			TenggatAt:   now.Add(-2 * time.Hour),
			IsOverdue:   true,
		},
		{
			ID:          3,
			KodeKendala: "KND-C",
			Prioritas:   "kritis",
			TenggatAt:   now.Add(-1 * time.Hour),
			IsOverdue:   true,
		},
		{
			ID:          4,
			KodeKendala: "KND-D",
			Prioritas:   "rendah",
			TenggatAt:   now.Add(1 * time.Hour),
			IsOverdue:   false,
		},
	}

	// Aturan: Terlambat dulu (C & B), diurutkan berdasarkan prioritas (kritis C > sedang B).
	// Lalu tidak terlambat (A & D), diurutkan berdasarkan prioritas (kritis A > rendah D).
	// Urutan ekspektasi: C, B, A, D
	res := service.FormatIssuesShareText(items, len(items), domain.IssueFilter{}, true, now)

	posC := strings.Index(res.Text, "KND-C")
	posB := strings.Index(res.Text, "KND-B")
	posA := strings.Index(res.Text, "KND-A")
	posD := strings.Index(res.Text, "KND-D")

	if !(posC < posB && posB < posA && posA < posD) {
		t.Errorf("Urutan pengurutan salah! Posisi C=%d, B=%d, A=%d, D=%d\nOutput: %s", posC, posB, posA, posD, res.Text)
	}
}

func TestFormatIssuesShareText_Limit20AndTruncation(t *testing.T) {
	now := time.Date(2026, 10, 27, 10, 0, 0, 0, time.UTC)

	// Buat 25 item
	var items []domain.OrderIssue
	for i := 1; i <= 25; i++ {
		items = append(items, domain.OrderIssue{
			ID:          uint64(i),
			KodeKendala: fmt.Sprintf("KND-%03d", i),
			Prioritas:   "sedang",
			Judul:       fmt.Sprintf("Kendala Nomor %d", i),
			KodePesanan: fmt.Sprintf("ORD-%03d", i),
			Status:      "baru",
			TenggatAt:   now.Add(time.Duration(i) * time.Hour),
		})
	}

	res := service.FormatIssuesShareText(items, 25, domain.IssueFilter{}, true, now)

	if !res.Truncated {
		t.Errorf("Ekspektasi truncated=true saat item > 20")
	}
	if res.Count != 25 {
		t.Errorf("Count harus tetap 25, didapat %d", res.Count)
	}

	// Item ke-20 harus ada, tapi item ke-21 tidak boleh ada
	if !strings.Contains(res.Text, "20. *[KND-020]*") {
		t.Errorf("Item ke-20 harus tercantum di teks")
	}
	if strings.Contains(res.Text, "21. *[KND-021]*") {
		t.Errorf("Item ke-21 tidak boleh ada karena batas maksimal 20 item")
	}

	// Cek catatan baris pemotongan
	if !strings.Contains(res.Text, "_+5 kendala lainnya, lihat di aplikasi_") {
		t.Errorf("Pesan pemotongan tidak sesuai: %s", res.Text)
	}
}

func TestFormatIssuesShareText_FilteredIDs(t *testing.T) {
	now := time.Date(2026, 10, 27, 10, 0, 0, 0, time.UTC)

	items := []domain.OrderIssue{
		{
			ID:          10,
			KodeKendala: "KND-010",
			Prioritas:   "tinggi",
			Judul:       "Hanya Item 10",
			KodePesanan: "ORD-010",
			TenggatAt:   now.Add(2 * time.Hour),
		},
	}

	filter := domain.IssueFilter{
		IDs: []uint64{10},
	}

	res := service.FormatIssuesShareText(items, 1, filter, true, now)

	if !strings.Contains(res.Text, "1 item dipilih") {
		t.Errorf("Ringkasan filter ID terpilih tidak muncul: %s", res.Text)
	}
	if !strings.Contains(res.Text, "KND-010") {
		t.Errorf("Item KND-010 harus ada di output: %s", res.Text)
	}
}
