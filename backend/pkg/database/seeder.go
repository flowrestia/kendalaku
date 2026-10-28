package database

import (
	"fmt"
	"log"
	"math/rand"
	"time"

	"github.com/flowrestia/kendalaku/backend/internal/domain"
	"github.com/flowrestia/kendalaku/backend/pkg/hash"
	"github.com/jmoiron/sqlx"
)

func SeedDatabase(db *sqlx.DB) error {
	log.Println("[INFO] Memeriksa dan menjalankan database seeder idempotent...")

	// 1. Seed Users (1 admin, 2 petugas)
	passwordDefault, _ := hash.MakePassword("password123")
	usersData := []struct {
		Email string
		Nama  string
		Role  string
	}{
		{"admin@kendalaku.com", "Sonny (Admin Operasional)", domain.RoleAdmin},
		{"petugas1@kendalaku.com", "Rina Petugas", domain.RolePetugas},
		{"petugas2@kendalaku.com", "Budi Penanganan", domain.RolePetugas},
	}

	userMap := make(map[string]uint64)
	for _, u := range usersData {
		var id uint64
		err := db.Get(&id, "SELECT id FROM users WHERE email = ?", u.Email)
		if err != nil {
			// Belum ada, masukkan
			res, err := db.Exec(
				"INSERT INTO users (nama, email, password_hash, role, created_at) VALUES (?, ?, ?, ?, NOW())",
				u.Nama, u.Email, passwordDefault, u.Role,
			)
			if err != nil {
				return fmt.Errorf("gagal insert user %s: %w", u.Email, err)
			}
			newID, _ := res.LastInsertId()
			userMap[u.Email] = uint64(newID)
		} else {
			userMap[u.Email] = id
		}
	}

	// 2. Seed 6 Kategori Masalah
	categoriesData := []struct {
		Nama       string
		WarnaHex   string
		Ikon       string
		TenggatJam int
	}{
		{"Pesanan Terlambat Diproses", "#EF4444", "alarm_rounded", 12},
		{"Tidak Dapat Dikemas", "#F59E0B", "inventory_2_rounded", 24},
		{"Bukti Pengiriman Belum Lengkap", "#3B82F6", "receipt_long_rounded", 36},
		{"Pesanan Dibatalkan/Diubah", "#8B5CF6", "cancel_presentation_rounded", 18},
		{"Data Pesanan Tidak Sesuai", "#EC4899", "rule_rounded", 24},
		{"Kerusakan Barang di Gudang", "#10B981", "broken_image_rounded", 48},
	}

	var categoryIDs []uint64
	for _, cat := range categoriesData {
		var id uint64
		err := db.Get(&id, "SELECT id FROM problem_categories WHERE nama = ?", cat.Nama)
		if err != nil {
			res, err := db.Exec(
				"INSERT INTO problem_categories (nama, warna_hex, ikon, tenggat_jam, aktif, created_at, updated_at) VALUES (?, ?, ?, ?, 1, NOW(), NOW())",
				cat.Nama, cat.WarnaHex, cat.Ikon, cat.TenggatJam,
			)
			if err != nil {
				return fmt.Errorf("gagal insert kategori %s: %w", cat.Nama, err)
			}
			newID, _ := res.LastInsertId()
			categoryIDs = append(categoryIDs, uint64(newID))
		} else {
			categoryIDs = append(categoryIDs, id)
		}
	}

	// 3. Seed 20 Pesanan Simulasi
	ordersData := []struct {
		Kode     string
		Customer string
		Produk   string
		Jumlah   int
	}{
		{"ORD-2026-0001", "Andi Pratama", "Laptop Sleeve 14 Inch + Mouse Wireless", 2},
		{"ORD-2026-0002", "Siti Rahmawati", "Keyboard Mechanical RGB Blue Switch", 1},
		{"ORD-2026-0003", "Dewi Lestari", "Earphone TWS ANC Bass Boost", 1},
		{"ORD-2026-0004", "Bambang Wijaya", "Monitor 24 Inch IPS 144Hz", 1},
		{"ORD-2026-0005", "Rizky Firmansyah", "Webcam Full HD 1080p With Tripod", 3},
		{"ORD-2026-0006", "Maya Anggraini", "USB Hub 7-in-1 Type-C Aluminum", 2},
		{"ORD-2026-0007", "Doni Prasetyo", "Powerbank 20000mAh Fast Charging", 2},
		{"ORD-2026-0008", "Eka Putri", "Desk Mat Gaming Minimalis 90x40cm", 1},
		{"ORD-2026-0009", "Fajar Hidayat", "Stand Laptop Ergonomis Lipat", 2},
		{"ORD-2026-0010", "Gita Gutawa", "Kabel HDMI 2.1 Ultra High Speed 3M", 4},
		{"ORD-2026-0011", "Hendra Saputra", "Mikrofon Kondensor USB Podcast", 1},
		{"ORD-2026-0012", "Indah Permatasari", "Cooling Pad Laptop 6 Fan Silent", 1},
		{"ORD-2026-0013", "Joko Susilo", "Lampu Monitor Screenbar LED", 1},
		{"ORD-2026-0014", "Kartika Sari", "Kacamata Anti Radiasi Blue Light", 2},
		{"ORD-2026-0015", "Lukman Hakim", "Harddisk Eksternal 2TB USB 3.0", 1},
		{"ORD-2026-0016", "Mega Utami", "Mousepad Ergonomic Wrist Rest", 3},
		{"ORD-2026-0017", "Nadia Safitri", "Kabel Type-C to Lightning Braided 2M", 5},
		{"ORD-2026-0018", "Oki Setiawan", "Speaker Bluetooth Portable Waterproof", 1},
		{"ORD-2026-0019", "Pandu Wicaksono", "Smart Watch Tracker Fitness", 1},
		{"ORD-2026-0020", "Qori Sandioriva", "Tas Ransel Laptop Anti Maling", 1},
	}

	var orderIDs []uint64
	for _, ord := range ordersData {
		var id uint64
		err := db.Get(&id, "SELECT id FROM orders WHERE kode_pesanan = ?", ord.Kode)
		if err != nil {
			res, err := db.Exec(
				"INSERT INTO orders (kode_pesanan, nama_pelanggan, produk, jumlah, created_at) VALUES (?, ?, ?, ?, NOW())",
				ord.Kode, ord.Customer, ord.Produk, ord.Jumlah,
			)
			if err != nil {
				return fmt.Errorf("gagal insert order %s: %w", ord.Kode, err)
			}
			newID, _ := res.LastInsertId()
			orderIDs = append(orderIDs, uint64(newID))
		} else {
			orderIDs = append(orderIDs, id)
		}
	}

	// 4. Seed 40 Kendala Realistis (dengan variasi sebaran 60 hari terakhir)
	var issueCount int
	err := db.Get(&issueCount, "SELECT COUNT(*) FROM order_issues")
	if err == nil && issueCount < 40 {
		adminID := userMap["admin@kendalaku.com"]
		petugas1ID := userMap["petugas1@kendalaku.com"]
	petugas2ID := userMap["petugas2@kendalaku.com"]
	petugasList := []uint64{petugas1ID, petugas2ID}

	now := time.Now().UTC()
	rng := rand.New(rand.NewSource(42)) // seed acak deterministik

	statuses := []string{
		domain.StatusBaru,
		domain.StatusSedangDiproses,
		domain.StatusMenungguInformasi,
		domain.StatusSelesai,
		domain.StatusDitolak,
	}

	prioritasList := []string{
		domain.PrioritasRendah,
		domain.PrioritasSedang,
		domain.PrioritasTinggi,
		domain.PrioritasKritis,
	}

	judulSamples := []string{
		"Packing kayu retak saat proses wrapping",
		"Stok gudang fisik selisih dengan pesanan sistem",
		"Resi pengiriman tidak dapat dilacak di kurir",
		"Pelanggan meminta perubahan alamat pengiriman mendadak",
		"Segel kemasan terbuka sebelum pengiriman kurir",
		"Label resi basah akibat kebocoran AC gudang",
		"Item bonus headset belum dimasukkan dalam paket",
		"Warna produk tidak sesuai catatan pembeli",
		"Dimensi paket melebihi batas toleransi regulasi kurir",
		"Verifikasi pembayaran tertahan di gateway pihak ketiga",
	}

	for i := 1; i <= 40; i++ {
		kodeKendala := fmt.Sprintf("KDL-202610-%04d", i)

		// Cek apakah kode sudah ada
		var existsID uint64
		err := db.Get(&existsID, "SELECT id FROM order_issues WHERE kode_kendala = ?", kodeKendala)
		if err == nil {
			continue // Lewati jika sudah ada
		}

		orderID := orderIDs[(i-1)%len(orderIDs)]
		categoryID := categoryIDs[(i-1)%len(categoryIDs)]
		status := statuses[rng.Intn(len(statuses))]
		prioritas := prioritasList[rng.Intn(len(prioritasList))]
		assignedTo := petugasList[rng.Intn(len(petugasList))]

		var createdTime time.Time
		var tenggatTime time.Time

		if status == domain.StatusSelesai || status == domain.StatusDitolak {
			// Kendala lampau (selesai atau ditolak) dalam rentang 1-45 hari lalu
			daysAgo := 1 + rng.Intn(45)
			createdTime = now.AddDate(0, 0, -daysAgo).Add(time.Duration(rng.Intn(12)) * time.Hour)
			tenggatTime = createdTime.Add(time.Duration(24+rng.Intn(48)) * time.Hour)
		} else {
			// Kendala aktif: variasikan agar sebagian baru masuk dan sebagian punya tenggat aman di masa depan
			// Sekitar 70% aktif punya tenggat di masa depan (tidak terlambat), 30% terlambat
			isOverdueSample := (rng.Float64() < 0.25)
			if isOverdueSample {
				// Terlambat: dibuat 2-4 hari lalu dengan tenggat 24 jam lalu
				createdTime = now.AddDate(0, 0, -(2 + rng.Intn(3))).Add(time.Duration(rng.Intn(6)) * time.Hour)
				tenggatTime = now.Add(-time.Duration(6+rng.Intn(24)) * time.Hour)
			} else {
				// Tidak terlambat: dibuat hari ini atau 1-2 hari lalu dengan tenggat 1-3 hari ke depan
				createdTime = now.Add(-time.Duration(rng.Intn(36)) * time.Hour)
				tenggatTime = now.Add(time.Duration(12+rng.Intn(72)) * time.Hour)
			}
		}

		var resolvedTime *time.Time
		var catatanPenyelesaian *string

		if status == domain.StatusSelesai {
			resTime := createdTime.Add(time.Duration(6+rng.Intn(30)) * time.Hour)
			resolvedTime = &resTime
			catatan := fmt.Sprintf("Kendala berhasil diselesaikan oleh petugas pada %s. Paket telah dikirim ulang.", resTime.Format("02/01/2006"))
			catatanPenyelesaian = &catatan
		} else if status == domain.StatusDitolak {
			catatan := "Kendala dibatalkan/ditolak karena konfirmasi pesanan telah kadaluwarsa dari pembeli."
			catatanPenyelesaian = &catatan
		}

		judul := judulSamples[rng.Intn(len(judulSamples))]
		deskripsi := fmt.Sprintf("Ditemukan kendala teknis pada penanganan pesanan nomor %d. Mohon ditindaklanjuti segera oleh tim gudang.", orderID)

		res, err := db.Exec(`
			INSERT INTO order_issues 
			(kode_kendala, order_id, category_id, judul, deskripsi, prioritas, status, tenggat_at, assigned_to, catatan_penyelesaian, is_archived, created_by, created_at, updated_at, resolved_at)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?)`,
			kodeKendala, orderID, categoryID, judul, deskripsi, prioritas, status, tenggatTime, assignedTo, catatanPenyelesaian, adminID, createdTime, createdTime, resolvedTime,
		)
		if err != nil {
			return fmt.Errorf("gagal insert issue %s: %w", kodeKendala, err)
		}

		issueID, _ := res.LastInsertId()

		// Masukkan riwayat transaksi status awal
		_, _ = db.Exec(`
			INSERT INTO issue_transactions (issue_id, status_sebelumnya, status_baru, catatan_tindakan, oleh_user_id, created_at)
			VALUES (?, '', 'baru', 'Kendala dilaporkan ke sistem KendalaKu', ?, ?)`,
			issueID, adminID, createdTime,
		)

		if status != domain.StatusBaru {
			_, _ = db.Exec(`
				INSERT INTO issue_transactions (issue_id, status_sebelumnya, status_baru, catatan_tindakan, oleh_user_id, created_at)
				VALUES (?, 'baru', ?, 'Pembaruan status operasional penanganan kendala', ?, ?)`,
				issueID, status, assignedTo, createdTime.Add(2*time.Hour),
			)
		}
	}
	} else {
		log.Println("[INFO] Database sudah memiliki data kendala (total:", issueCount, "), periksa update jatuh tempo segera.")
	}

	// 5. Pastikan ada kendala aktif yang jatuh tempo segera (dalam kurun > sekarang dan <= sekarang + 24 jam)
	var dueSoonCount int
	_ = db.Get(&dueSoonCount, "SELECT COUNT(*) FROM order_issues WHERE is_archived = 0 AND status NOT IN ('selesai', 'ditolak') AND tenggat_at > UTC_TIMESTAMP() AND tenggat_at <= UTC_TIMESTAMP() + INTERVAL 24 HOUR")
	if dueSoonCount < 2 {
		// Update 2 kendala aktif agar tenggatnya jatuh dalam 6 jam dan 18 jam ke depan dari saat ini
		var activeIDs []uint64
		_ = db.Select(&activeIDs, "SELECT id FROM order_issues WHERE is_archived = 0 AND status NOT IN ('selesai', 'ditolak') ORDER BY id ASC LIMIT 2")
		if len(activeIDs) > 0 {
			_, _ = db.Exec("UPDATE order_issues SET tenggat_at = UTC_TIMESTAMP() + INTERVAL 6 HOUR WHERE id = ?", activeIDs[0])
		}
		if len(activeIDs) > 1 {
			_, _ = db.Exec("UPDATE order_issues SET tenggat_at = UTC_TIMESTAMP() + INTERVAL 18 HOUR WHERE id = ?", activeIDs[1])
		}
	}

	// 6. Seed contoh komentar (Fase 6)
	var commentCount int
	_ = db.Get(&commentCount, "SELECT COUNT(*) FROM issue_comments")
	if commentCount == 0 {
		var firstIssueID uint64
		_ = db.Get(&firstIssueID, "SELECT id FROM order_issues ORDER BY id ASC LIMIT 1")
		if firstIssueID > 0 {
			adminID := userMap["admin@kendalaku.com"]
			petugas1ID := userMap["petugas1@kendalaku.com"]

			_, _ = db.Exec(`
				INSERT INTO issue_comments (issue_id, user_id, tipe, isi, created_at) VALUES 
				(?, ?, 'komentar', 'Mohon konfirmasi ulang ke pihak kurir mengenai nomor resi paket ini.', UTC_TIMESTAMP()),
				(?, ?, 'komentar', 'Sudah saya hubungi via WhatsApp, kurir sedang mengecek ulang di hub transit.', DATE_ADD(UTC_TIMESTAMP(), INTERVAL 10 MINUTE)),
				(?, ?, 'sistem', 'Dipindahkan dari Belum Ditugaskan (-) ke Rina Petugas. Catatan: Prioritas tindak lanjut cepat', DATE_ADD(UTC_TIMESTAMP(), INTERVAL 15 MINUTE))`,
				firstIssueID, adminID,
				firstIssueID, petugas1ID,
				firstIssueID, adminID,
			)
		}
	}

	log.Println("[INFO] Database seeder berhasil selesai (40 kendala realistis tersimpan)")
	return nil
}
