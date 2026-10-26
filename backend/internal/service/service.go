package service

import (
	"errors"
	"fmt"
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

func (s *Service) UpdateIssue(id uint64, req domain.UpdateIssueRequest) (*domain.OrderIssue, error) {
	existing, err := s.repo.GetIssueByID(id)
	if err != nil {
		return nil, errors.New("kendala tidak ditemukan")
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

func (s *Service) TransitionStatus(issueID uint64, req domain.TransitionStatusRequest, userID uint64) (*domain.OrderIssue, error) {
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
