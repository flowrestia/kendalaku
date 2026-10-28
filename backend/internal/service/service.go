package service

import (
	"bytes"
	"encoding/csv"
	"errors"
	"fmt"
	"math"
	"sort"
	"strings"
	"time"

	"github.com/flowrestia/kendalaku/backend/internal/domain"
	"github.com/flowrestia/kendalaku/backend/internal/repository/mysql"
	"github.com/flowrestia/kendalaku/backend/pkg/hash"
	"github.com/flowrestia/kendalaku/backend/pkg/jwt"
)

type Service struct {
	repo       *mysql.Repository
	tokenMaker *jwt.TokenMaker
	jwtExpiry  int
}

func NewService(repo *mysql.Repository, tokenMaker *jwt.TokenMaker, jwtExpiry int) *Service {
	return &Service{
		repo:       repo,
		tokenMaker: tokenMaker,
		jwtExpiry:  jwtExpiry,
	}
}

// ---------------- AUTH SERVICE ----------------

func (s *Service) Login(req domain.LoginRequest) (*domain.LoginResponse, error) {
	user, err := s.repo.GetUserByEmail(req.Email)
	if err != nil {
		return nil, errors.New("email atau kata sandi tidak sesuai")
	}

	if !hash.CheckPassword(req.Password, user.PasswordHash) {
		return nil, errors.New("email atau kata sandi tidak sesuai")
	}

	token, err := s.tokenMaker.GenerateToken(user.ID, user.Email, user.Nama, user.Role, s.jwtExpiry)
	if err != nil {
		return nil, fmt.Errorf("gagal membuat token autentikasi: %w", err)
	}

	return &domain.LoginResponse{
		Token: token,
		User:  *user,
	}, nil
}

func (s *Service) GetUserProfile(userID uint64) (*domain.User, error) {
	return s.repo.GetUserByID(userID)
}

func (s *Service) GetAllUsers() ([]domain.User, error) {
	return s.repo.GetAllUsers()
}

// ---------------- PROBLEM CATEGORY SERVICE ----------------

func (s *Service) GetAllCategories(onlyActive bool) ([]domain.ProblemCategory, error) {
	return s.repo.GetAllCategories(onlyActive)
}

func (s *Service) CreateCategory(req domain.CategoryRequest) (*domain.ProblemCategory, error) {
	aktif := true
	if req.Aktif != nil {
		aktif = *req.Aktif
	}

	cat := &domain.ProblemCategory{
		Nama:       req.Nama,
		WarnaHex:   req.WarnaHex,
		Ikon:       req.Ikon,
		TenggatJam: req.TenggatJam,
		Aktif:      aktif,
	}

	id, err := s.repo.CreateCategory(cat)
	if err != nil {
		return nil, err
	}

	return s.repo.GetCategoryByID(id)
}

func (s *Service) UpdateCategory(id uint64, req domain.CategoryRequest) (*domain.ProblemCategory, error) {
	existing, err := s.repo.GetCategoryByID(id)
	if err != nil {
		return nil, errors.New("kategori tidak ditemukan")
	}

	aktif := existing.Aktif
	if req.Aktif != nil {
		aktif = *req.Aktif
	}

	cat := &domain.ProblemCategory{
		Nama:       req.Nama,
		WarnaHex:   req.WarnaHex,
		Ikon:       req.Ikon,
		TenggatJam: req.TenggatJam,
		Aktif:      aktif,
	}

	if err := s.repo.UpdateCategory(id, cat); err != nil {
		return nil, err
	}

	return s.repo.GetCategoryByID(id)
}

func (s *Service) DeleteCategory(id uint64) error {
	_, err := s.repo.GetCategoryByID(id)
	if err != nil {
		return errors.New("kategori tidak ditemukan")
	}
	return s.repo.DeleteCategory(id)
}

// ---------------- ORDER SIMULASI SERVICE ----------------

func (s *Service) GetAllOrders() ([]domain.Order, error) {
	return s.repo.GetAllOrders()
}

// ---------------- ORDER ISSUES SERVICE ----------------

func (s *Service) CreateIssue(req domain.CreateIssueRequest, creatorID uint64) (*domain.OrderIssue, error) {
	// 1. Verifikasi order dan kategori
	_, err := s.repo.GetOrderByID(req.OrderID)
	if err != nil {
		return nil, errors.New("pesanan simulasi tidak ditemukan")
	}

	category, err := s.repo.GetCategoryByID(req.CategoryID)
	if err != nil {
		return nil, errors.New("kategori masalah tidak ditemukan")
	}
	if !category.Aktif {
		return nil, errors.New("kategori masalah sedang nonaktif dan tidak dapat digunakan")
	}

	// 2. Hitung tenggat_at otomatis jika tidak dispesifikasikan (created_at + tenggat_jam kategori)
	now := time.Now().UTC()
	tenggatAt := now.Add(time.Duration(category.TenggatJam) * time.Hour)
	if req.TenggatAt != nil && !req.TenggatAt.IsZero() {
		tenggatAt = req.TenggatAt.UTC()
	}

	// 3. Mulai Database Transaction untuk atomic code generation + issue insert + transaction record
	tx, err := s.repo.BeginTx()
	if err != nil {
		return nil, fmt.Errorf("gagal memulai transaksi database: %w", err)
	}
	defer tx.Rollback()

	// Kode kendala otomatis KDL-YYYYMM-XXXX
	kodeKendala, err := s.repo.GenerateNextIssueCode(tx)
	if err != nil {
		return nil, fmt.Errorf("gagal membuat kode kendala: %w", err)
	}

	issue := &domain.OrderIssue{
		KodeKendala: kodeKendala,
		OrderID:     req.OrderID,
		CategoryID:  req.CategoryID,
		Judul:       req.Judul,
		Deskripsi:   req.Deskripsi,
		Prioritas:   req.Prioritas,
		Status:      domain.StatusBaru,
		TenggatAt:   tenggatAt,
		AssignedTo:  req.AssignedTo,
		CreatedBy:   creatorID,
	}

	issueID, err := s.repo.CreateIssue(tx, issue)
	if err != nil {
		return nil, fmt.Errorf("gagal menyimpan data kendala: %w", err)
	}

	// Catat riwayat transaksi awal
	err = s.repo.RecordTransaction(tx, issueID, "", domain.StatusBaru, "Kendala dilaporkan ke sistem KendalaKu", creatorID)
	if err != nil {
		return nil, fmt.Errorf("gagal mencatat riwayat kendala: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("gagal commit transaksi database: %w", err)
	}

	return s.repo.GetIssueByID(issueID)
}

func (s *Service) GetIssueDetail(id uint64) (*domain.OrderIssue, error) {
	issue, err := s.repo.GetIssueByID(id)
	if err != nil {
		return nil, errors.New("kendala tidak ditemukan")
	}
	return issue, nil
}

func (s *Service) ListIssues(filter domain.IssueFilter) (*domain.PaginatedResult, error) {
	items, total, err := s.repo.ListIssues(filter)
	if err != nil {
		return nil, err
	}

	totalPages := 0
	if filter.Limit > 0 {
		totalPages = (total + filter.Limit - 1) / filter.Limit
	}

	return &domain.PaginatedResult{
		Items:      items,
		Total:      total,
		Page:       filter.Page,
		Limit:      filter.Limit,
		TotalPages: totalPages,
	}, nil
}

func (s *Service) UpdateIssue(id uint64, req domain.UpdateIssueRequest, userRole string, userID uint64) (*domain.OrderIssue, error) {
	existing, err := s.repo.GetIssueByID(id)
	if err != nil {
		return nil, errors.New("kendala tidak ditemukan")
	}

	// Aturan Hak Akses: Petugas hanya boleh mengubah kendala yang ditugaskan kepada dirinya
	if userRole != domain.RoleAdmin {
		if existing.AssignedTo == nil || *existing.AssignedTo != userID {
			return nil, domain.ErrForbidden
		}
	}

	if existing.Status == domain.StatusSelesai || existing.Status == domain.StatusDitolak {
		return nil, errors.New("kendala berstatus selesai atau ditolak tidak dapat diubah lagi")
	}

	if err := s.repo.UpdateIssue(id, &req); err != nil {
		return nil, err
	}

	return s.repo.GetIssueByID(id)
}

func (s *Service) ArchiveIssue(id uint64, isArchived bool) error {
	_, err := s.repo.GetIssueByID(id)
	if err != nil {
		return errors.New("kendala tidak ditemukan")
	}
	return s.repo.SetArchiveStatus(id, isArchived)
}

func (s *Service) DeleteIssue(id uint64, userRole string) error {
	existing, err := s.repo.GetIssueByID(id)
	if err != nil {
		return errors.New("kendala tidak ditemukan")
	}

	// Aturan bisnis: Hapus permanen HANYA untuk status 'baru' oleh admin.
	// Kendala berstatus selesai/ditolak/diproses tidak boleh dihapus permanen, hanya diarsipkan.
	if userRole != domain.RoleAdmin {
		return errors.New("hanya administrator yang dapat menghapus data kendala")
	}

	if existing.Status != domain.StatusBaru {
		return errors.New("hanya kendala dengan status 'baru' yang boleh dihapus permanen. Kendala berstatus lain hanya boleh diarsipkan.")
	}

	return s.repo.DeleteIssue(id)
}

// ---------------- TRANSISI STATUS PENANGANAN SERVICE ----------------

func (s *Service) TransitionStatus(issueID uint64, req domain.TransitionStatusRequest, userID uint64, userRole string) (*domain.OrderIssue, error) {
	// Mulai Database Transaction dengan SELECT ... FOR UPDATE
	tx, err := s.repo.BeginTx()
	if err != nil {
		return nil, fmt.Errorf("gagal memulai transaksi: %w", err)
	}
	defer tx.Rollback()

	existing, err := s.repo.GetIssueByIDForUpdate(tx, issueID)
	if err != nil {
		return nil, errors.New("kendala tidak ditemukan")
	}

	// Aturan Hak Akses: Petugas hanya boleh memproses transisi pada kendala yang ditugaskan kepada dirinya
	if userRole != domain.RoleAdmin {
		if existing.AssignedTo == nil || *existing.AssignedTo != userID {
			return nil, domain.ErrForbidden
		}
	}

	// 1. Validasi State Machine & Catatan Penyelesaian
	if err := domain.ValidateStatusTransition(existing.Status, req.StatusBaru, req.CatatanPenyelesaian); err != nil {
		return nil, err
	}

	// 2. Persiapkan waktu penyelesaian
	var resolvedAt *time.Time
	var catatanPenyelesaian *string

	if req.StatusBaru == domain.StatusSelesai {
		now := time.Now().UTC()
		resolvedAt = &now
		catatanPenyelesaian = &req.CatatanPenyelesaian
	} else if req.StatusBaru == domain.StatusDitolak && req.CatatanPenyelesaian != "" {
		catatanPenyelesaian = &req.CatatanPenyelesaian
	}

	// 3. Update issue status dalam transaksi
	queryUpdate := `UPDATE order_issues 
					SET status = ?, catatan_penyelesaian = COALESCE(?, catatan_penyelesaian), resolved_at = ?, updated_at = NOW()
					WHERE id = ?`
	_, err = tx.Exec(queryUpdate, req.StatusBaru, catatanPenyelesaian, resolvedAt, issueID)
	if err != nil {
		return nil, fmt.Errorf("gagal update status kendala: %w", err)
	}

	// 4. Masukkan riwayat issue_transactions dalam transaksi yang sama
	err = s.repo.RecordTransaction(tx, issueID, existing.Status, req.StatusBaru, req.CatatanTindakan, userID)
	if err != nil {
		return nil, fmt.Errorf("gagal mencatat riwayat transaksi: %w", err)
	}

	// Commit transaksi
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("gagal commit transaksi: %w", err)
	}

	return s.repo.GetIssueByID(issueID)
}

func (s *Service) GetIssueTransitions(issueID uint64) ([]domain.IssueTransaction, error) {
	_, err := s.repo.GetIssueByID(issueID)
	if err != nil {
		return nil, errors.New("kendala tidak ditemukan")
	}
	return s.repo.GetTransactionsByIssueID(issueID)
}

// ---------------- FASE 3: DASHBOARD & REPORT SERVICE ----------------

// CalculateSummaryMetrics menghitung persentase selesai dan rata-rata waktu penyelesaian dalam jam
func CalculateSummaryMetrics(total, selesai, resolvedCount int, totalDurationSec float64) (persentase float64, rataRataJam float64) {
	if total > 0 {
		persentase = math.Round((float64(selesai)/float64(total))*10000) / 100 // 2 digit desimal
	}
	if resolvedCount > 0 && totalDurationSec > 0 {
		avgSec := totalDurationSec / float64(resolvedCount)
		rataRataJam = math.Round((avgSec/3600.0)*100) / 100 // jam dengan 2 digit desimal
	}
	return persentase, rataRataJam
}

func (s *Service) GetDashboardSummary() (*domain.DashboardSummaryResponse, error) {
	raw, err := s.repo.GetDashboardSummaryStats()
	if err != nil {
		return nil, fmt.Errorf("gagal mengambil statistik ringkasan: %w", err)
	}

	var durationSec float64
	if raw.TotalDurationSec.Valid {
		durationSec = raw.TotalDurationSec.Float64
	}

	persentase, rataRataJam := CalculateSummaryMetrics(raw.Total, raw.Selesai, raw.ResolvedCount, durationSec)

	return &domain.DashboardSummaryResponse{
		TotalKendala:              raw.Total,
		Baru:                      raw.Baru,
		SedangDiproses:            raw.SedangDiproses,
		MenungguInformasi:         raw.MenungguInformasi,
		Selesai:                   raw.Selesai,
		Ditolak:                   raw.Ditolak,
		Terlambat:                 raw.Terlambat,
		JatuhTempoSegera:          raw.JatuhTempoSegera,
		RataRataWaktuPenyelesaian: rataRataJam,
		PersentaseSelesai:         persentase,
	}, nil
}

func (s *Service) GetCategoryStats() ([]domain.CategoryStatResponse, error) {
	list, err := s.repo.GetCategoryStats()
	if err != nil {
		return nil, fmt.Errorf("gagal mengambil statistik kategori: %w", err)
	}

	totalAll := 0
	for _, it := range list {
		totalAll += it.Total
	}

	for i := range list {
		if list[i].WarnaHex == "" {
			list[i].WarnaHex = "#4F46E5"
		}
		if list[i].Ikon == "" {
			list[i].Ikon = "warning_amber_rounded"
		}
		if totalAll > 0 {
			list[i].Persentase = math.Round((float64(list[i].Total)/float64(totalAll))*10000) / 100
		}
	}

	return list, nil
}

func (s *Service) GetTrendData(period string) ([]domain.TrendPointResponse, error) {
	now := time.Now().UTC()

	switch period {
	case "7d", "":
		rows, err := s.repo.GetTrendData7Days()
		if err != nil {
			return nil, fmt.Errorf("gagal mengambil tren: %w", err)
		}
		rowMap := make(map[string]mysql.TrendRow)
		for _, r := range rows {
			rowMap[r.DateGroup] = r
		}

		result := make([]domain.TrendPointResponse, 7)
		for i := 6; i >= 0; i-- {
			dt := now.AddDate(0, 0, -i).Format("2006-01-02")
			r := rowMap[dt]
			result[6-i] = domain.TrendPointResponse{
				Label:        dt,
				Tanggal:      dt,
				TotalMasuk:   r.TotalMasuk,
				TotalSelesai: r.TotalSelesai,
			}
		}
		return result, nil

	case "30d":
		rows, err := s.repo.GetTrendData30Days()
		if err != nil {
			return nil, fmt.Errorf("gagal mengambil tren: %w", err)
		}
		rowMap := make(map[string]mysql.TrendRow)
		for _, r := range rows {
			rowMap[r.DateGroup] = r
		}

		result := make([]domain.TrendPointResponse, 30)
		for i := 29; i >= 0; i-- {
			dt := now.AddDate(0, 0, -i).Format("2006-01-02")
			r := rowMap[dt]
			result[29-i] = domain.TrendPointResponse{
				Label:        dt,
				Tanggal:      dt,
				TotalMasuk:   r.TotalMasuk,
				TotalSelesai: r.TotalSelesai,
			}
		}
		return result, nil

	case "12m":
		rows, err := s.repo.GetTrendData12Months()
		if err != nil {
			return nil, fmt.Errorf("gagal mengambil tren: %w", err)
		}
		rowMap := make(map[string]mysql.TrendRow)
		for _, r := range rows {
			rowMap[r.DateGroup] = r
		}

		result := make([]domain.TrendPointResponse, 12)
		for i := 11; i >= 0; i-- {
			dt := now.AddDate(0, -i, 0).Format("2006-01")
			r := rowMap[dt]
			result[11-i] = domain.TrendPointResponse{
				Label:        dt,
				Tanggal:      dt,
				TotalMasuk:   r.TotalMasuk,
				TotalSelesai: r.TotalSelesai,
			}
		}
		return result, nil

	default:
		return nil, errors.New("parameter period tidak valid, gunakan: 7d, 30d, atau 12m")
	}
}

func (s *Service) GetReportRecap(from, to string) (*domain.ReportRecapResponse, error) {
	issues, err := s.repo.GetIssuesForReport(from, to)
	if err != nil {
		return nil, fmt.Errorf("gagal mengambil data laporan: %w", err)
	}

	var rekapStatus domain.StatusBreakdown
	categoryMap := make(map[uint64]*domain.CategoryRecapItem)

	for _, it := range issues {
		switch it.Status {
		case domain.StatusBaru:
			rekapStatus.Baru++
		case domain.StatusSedangDiproses:
			rekapStatus.SedangDiproses++
		case domain.StatusMenungguInformasi:
			rekapStatus.MenungguInformasi++
		case domain.StatusSelesai:
			rekapStatus.Selesai++
		case domain.StatusDitolak:
			rekapStatus.Ditolak++
		}

		item, exists := categoryMap[it.CategoryID]
		if !exists {
			item = &domain.CategoryRecapItem{
				CategoryID: it.CategoryID,
				Nama:       it.CategoryNama,
				WarnaHex:   it.CategoryWarnaHex,
				Total:      0,
			}
			categoryMap[it.CategoryID] = item
		}
		item.Total++

		switch it.Status {
		case domain.StatusBaru:
			item.Status.Baru++
		case domain.StatusSedangDiproses:
			item.Status.SedangDiproses++
		case domain.StatusMenungguInformasi:
			item.Status.MenungguInformasi++
		case domain.StatusSelesai:
			item.Status.Selesai++
		case domain.StatusDitolak:
			item.Status.Ditolak++
		}
	}

	var perKategori []domain.CategoryRecapItem
	var topCategory *string
	maxCount := -1

	// Urutkan kategori berdasarkan total terbanyak
	for _, item := range categoryMap {
		perKategori = append(perKategori, *item)
		if item.Total > maxCount {
			maxCount = item.Total
			catName := item.Nama
			topCategory = &catName
		}
	}

	return &domain.ReportRecapResponse{
		TotalKendala:         len(issues),
		KategoriPalingSering: topCategory,
		RekapStatus:          rekapStatus,
		PerKategori:          perKategori,
	}, nil
}

func (s *Service) ExportReportCSV(from, to string) (*bytes.Buffer, error) {
	issues, err := s.repo.GetIssuesForReport(from, to)
	if err != nil {
		return nil, fmt.Errorf("gagal mengambil data untuk ekspor: %w", err)
	}

	buf := new(bytes.Buffer)
	// UTF-8 BOM agar rapi saat dibuka di Microsoft Excel
	buf.Write([]byte{0xEF, 0xBB, 0xBF})

	writer := csv.NewWriter(buf)

	// Header Kolom CSV
	header := []string{
		"Kode Kendala",
		"Nomor Pesanan",
		"Nama Pelanggan",
		"Kategori",
		"Judul Kendala",
		"Prioritas",
		"Status",
		"Petugas Penanganan",
		"Pelapor",
		"Tenggat Waktu",
		"Status Terlambat",
		"Tanggal Dilaporkan",
		"Tanggal Selesai",
		"Catatan Penyelesaian",
	}
	if err := writer.Write(header); err != nil {
		return nil, err
	}

	for _, it := range issues {
		isOverdueStr := "Tidak"
		if it.IsOverdue {
			isOverdueStr = "Ya"
		}

		resolvedStr := "-"
		if it.ResolvedAt != nil {
			resolvedStr = it.ResolvedAt.Format("2006-01-02 15:04:05")
		}

		catatan := "-"
		if it.CatatanPenyelesaian != nil && *it.CatatanPenyelesaian != "" {
			catatan = *it.CatatanPenyelesaian
		}

		row := []string{
			it.KodeKendala,
			it.KodePesanan,
			it.NamaPelanggan,
			it.CategoryNama,
			it.Judul,
			it.Prioritas,
			it.Status,
			it.AssignedNama,
			it.CreatedByNama,
			it.TenggatAt.Format("2006-01-02 15:04:05"),
			isOverdueStr,
			it.CreatedAt.Format("2006-01-02 15:04:05"),
			resolvedStr,
			catatan,
		}
		if err := writer.Write(row); err != nil {
			return nil, err
		}
	}

	writer.Flush()
	if err := writer.Error(); err != nil {
		return nil, err
	}

	return buf, nil
}

func (s *Service) GetActivityLogs(limit int) ([]domain.ActivityLogItem, error) {
	return s.repo.GetActivityLogs(limit)
}

// PriorityRank memetakan prioritas ke nilai integer (kritis paling tinggi)
func PriorityRank(p string) int {
	switch strings.ToLower(p) {
	case "kritis":
		return 4
	case "tinggi":
		return 3
	case "sedang":
		return 2
	case "rendah":
		return 1
	default:
		return 0
	}
}

// GenerateShareText memformat daftar kendala ke format pesan WhatsApp
func (s *Service) GenerateShareText(filter domain.IssueFilter, includeCustomer bool) (*domain.ShareTextResponse, error) {
	// Ambil semua kendala yang cocok dengan filter (tanpa paginasi database kaku untuk pengurutan akurat)
	filter.Page = 1
	filter.Limit = 1000 // Ambil sampel cukup besar

	items, total, err := s.repo.ListIssues(filter)
	if err != nil {
		return nil, err
	}

	return FormatIssuesShareText(items, total, filter, includeCustomer, time.Now().UTC()), nil
}

// FormatIssuesShareText mengurutkan dan memformat daftar kendala ke teks gaya WhatsApp
func FormatIssuesShareText(items []domain.OrderIssue, total int, filter domain.IssueFilter, includeCustomer bool, nowUTC time.Time) *domain.ShareTextResponse {

	// Urutkan:
	// 1. Terlambat dulu (is_overdue = true di atas is_overdue = false)
	// 2. Prioritas (kritis > tinggi > sedang > rendah)
	// 3. Tenggat terdekat (tenggat_at ASC)
	sort.Slice(items, func(i, j int) bool {
		// 1. Terlambat
		if items[i].IsOverdue != items[j].IsOverdue {
			return items[i].IsOverdue // true duluan
		}

		// 2. Prioritas
		rankI := PriorityRank(items[i].Prioritas)
		rankJ := PriorityRank(items[j].Prioritas)
		if rankI != rankJ {
			return rankI > rankJ // lebih tinggi rank duluan
		}

		// 3. Tenggat terdekat
		return items[i].TenggatAt.Before(items[j].TenggatAt)
	})

	const maxItems = 20
	truncated := false
	displayItems := items
	if len(items) > maxItems {
		truncated = true
		displayItems = items[:maxItems]
	}

	// Lokasi WIB (UTC+7)
	locWIB := time.FixedZone("WIB", 7*3600)
	nowWIB := nowUTC.In(locWIB)

	var sb strings.Builder
	sb.WriteString("*DAFTAR KENDALA LAYANAN - KENDALAKU*\n")
	sb.WriteString(fmt.Sprintf("Waktu Cetak: %s WIB\n", nowWIB.Format("02/01/2006 15:04")))

	// Ringkasan filter
	var filterSummaries []string
	if filter.Status != "" {
		filterSummaries = append(filterSummaries, fmt.Sprintf("Status: %s", filter.Status))
	}
	if filter.Prioritas != "" {
		filterSummaries = append(filterSummaries, fmt.Sprintf("Prioritas: %s", filter.Prioritas))
	}
	if filter.IsOverdue != nil && *filter.IsOverdue {
		filterSummaries = append(filterSummaries, "Filter: Terlambat Saja")
	}
	if filter.From != "" || filter.To != "" {
		filterSummaries = append(filterSummaries, fmt.Sprintf("Periode: %s s/d %s", filter.From, filter.To))
	}
	if len(filter.IDs) > 0 {
		filterSummaries = append(filterSummaries, fmt.Sprintf("%d item dipilih", len(filter.IDs)))
	}

	if len(filterSummaries) > 0 {
		sb.WriteString(fmt.Sprintf("Filter: %s\n", strings.Join(filterSummaries, " | ")))
	}
	sb.WriteString(fmt.Sprintf("Total Kendala: %d\n\n", total))

	if len(displayItems) == 0 {
		sb.WriteString("Tidak ada kendala yang sesuai dengan filter.\n")
	} else {
		for i, it := range displayItems {
			// Hitung status tenggat dalam jam bulat (round to nearest atau ceiling)
			var slaText string
			diff := it.TenggatAt.Sub(nowUTC)
			diffHours := int(math.Round(math.Abs(diff.Hours())))
			if diffHours < 1 {
				diffHours = 1
			}

			if it.Status == domain.StatusSelesai {
				slaText = "Tuntas"
			} else if it.Status == domain.StatusDitolak {
				slaText = "Ditolak"
			} else if it.IsOverdue || nowUTC.After(it.TenggatAt) {
				slaText = fmt.Sprintf("Terlambat %d jam", diffHours)
			} else {
				slaText = fmt.Sprintf("Sisa %d jam", diffHours)
			}

			tenggatWIB := it.TenggatAt.In(locWIB).Format("02/01 15:04")

			var orderLine string
			if includeCustomer && it.NamaPelanggan != "" {
				orderLine = fmt.Sprintf("%s (%s)", it.KodePesanan, it.NamaPelanggan)
			} else {
				orderLine = it.KodePesanan
			}

			// Format gaya WhatsApp
			sb.WriteString(fmt.Sprintf("%d. *[%s]* *[%s]* %s\n", i+1, it.KodeKendala, strings.ToUpper(it.Prioritas), it.Judul))
			sb.WriteString(fmt.Sprintf("   Pesanan: %s\n", orderLine))
			sb.WriteString(fmt.Sprintf("   Status: %s | Petugas: %s\n", it.Status, it.AssignedNama))
			sb.WriteString(fmt.Sprintf("   Tenggat: %s WIB (%s)\n", tenggatWIB, slaText))
			if i < len(displayItems)-1 {
				sb.WriteString("\n")
			}
		}

		if truncated {
			sisa := total - maxItems
			sb.WriteString(fmt.Sprintf("\n\n_+%d kendala lainnya, lihat di aplikasi_", sisa))
		}
	}

	return &domain.ShareTextResponse{
		Text:      sb.String(),
		Count:     total,
		Truncated: truncated,
	}
}

// ---------------- FASE 6: COMMENTS, REASSIGN & DUE SOON SERVICE ----------------

func (s *Service) GetComments(issueID uint64) ([]domain.IssueComment, error) {
	_, err := s.repo.GetIssueByID(issueID)
	if err != nil {
		return nil, errors.New("kendala tidak ditemukan")
	}
	return s.repo.GetCommentsByIssueID(issueID)
}

func (s *Service) CreateComment(issueID, userID uint64, req domain.CreateCommentRequest) (*domain.IssueComment, error) {
	_, err := s.repo.GetIssueByID(issueID)
	if err != nil {
		return nil, errors.New("kendala tidak ditemukan")
	}

	trimmed := strings.TrimSpace(req.Isi)
	if trimmed == "" {
		return nil, errors.New("isi komentar tidak boleh kosong")
	}
	if len(trimmed) > 1000 {
		return nil, errors.New("isi komentar maksimal 1000 karakter")
	}

	return s.repo.CreateComment(issueID, userID, domain.CommentTypeKomentar, trimmed)
}

func (s *Service) ReassignIssue(issueID, currentAdminID uint64, req domain.ReassignIssueRequest) (*domain.OrderIssue, error) {
	// Mulai Database Transaction dengan SELECT ... FOR UPDATE
	tx, err := s.repo.BeginTx()
	if err != nil {
		return nil, fmt.Errorf("gagal memulai transaksi: %w", err)
	}
	defer tx.Rollback()

	existing, err := s.repo.GetIssueByIDForUpdate(tx, issueID)
	if err != nil {
		return nil, errors.New("kendala tidak ditemukan")
	}

	// Aturan 3: Tidak boleh pada kendala berstatus selesai/ditolak (422)
	if existing.Status == domain.StatusSelesai || existing.Status == domain.StatusDitolak {
		return nil, errors.New("kendala telah berstatus selesai atau ditolak dan tidak dapat dialihkan lagi")
	}

	// Aturan 3: Petugas tujuan harus user role petugas yang ada
	targetUser, err := s.repo.GetUserByID(req.AssignedTo)
	if err != nil || targetUser == nil {
		return nil, errors.New("petugas tujuan tidak ditemukan")
	}
	if targetUser.Role != domain.RolePetugas {
		return nil, errors.New("kendala hanya dapat dialihkan ke pengguna dengan role petugas")
	}

	// Dapatkan nama petugas lama
	namaLama := "Belum Ditugaskan (-)"
	if existing.AssignedTo != nil {
		oldUser, err := s.repo.GetUserByID(*existing.AssignedTo)
		if err == nil && oldUser != nil {
			namaLama = oldUser.Nama
		}
	}

	// Format teks komentar sistem: "Dipindahkan dari X ke Y" plus catatan
	namaBaru := targetUser.Nama
	systemText := fmt.Sprintf("Dipindahkan dari %s ke %s", namaLama, namaBaru)
	catatanTrimmed := strings.TrimSpace(req.Catatan)
	if catatanTrimmed != "" {
		systemText += fmt.Sprintf(". Catatan: %s", catatanTrimmed)
	}

	// Dalam satu transaksi: update assigned_to dan insert komentar tipe 'sistem'
	if err := s.repo.UpdateIssueAssignedToTx(tx, issueID, req.AssignedTo); err != nil {
		return nil, fmt.Errorf("gagal memperbarui petugas penanganan: %w", err)
	}

	if err := s.repo.CreateCommentTx(tx, issueID, currentAdminID, domain.CommentTypeSistem, systemText); err != nil {
		return nil, fmt.Errorf("gagal mencatat riwayat pemindahan: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("gagal commit transaksi reassign: %w", err)
	}

	return s.repo.GetIssueByID(issueID)
}

func (s *Service) GetIssuesDueSoon(hours int) ([]domain.OrderIssue, error) {
	if hours <= 0 {
		hours = 24
	}
	return s.repo.GetIssuesDueSoon(hours)
}



