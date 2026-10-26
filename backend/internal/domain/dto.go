package domain

import "time"

// Request DTO Login
type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=6"`
}

// Response DTO Login
type LoginResponse struct {
	Token string `json:"token"`
	User  User   `json:"user"`
}

// Request DTO Kategori
type CategoryRequest struct {
	Nama       string `json:"nama" binding:"required,max=100"`
	WarnaHex   string `json:"warna_hex" binding:"required,max=7"`
	Ikon       string `json:"ikon" binding:"required,max=50"`
	TenggatJam int    `json:"tenggat_jam" binding:"required,min=1"`
	Aktif      *bool  `json:"aktif"`
}

// Request DTO Buat Kendala
type CreateIssueRequest struct {
	OrderID    uint64     `json:"order_id" binding:"required"`
	CategoryID uint64     `json:"category_id" binding:"required"`
	Judul      string     `json:"judul" binding:"required,max=200"`
	Deskripsi  string     `json:"deskripsi" binding:"required"`
	Prioritas  string     `json:"prioritas" binding:"required,oneof=rendah sedang tinggi kritis"`
	AssignedTo *uint64    `json:"assigned_to"`
	TenggatAt  *time.Time `json:"tenggat_at"` // Opsional, default dihitung di service
}

// Request DTO Update Kendala
type UpdateIssueRequest struct {
	Judul      string     `json:"judul" binding:"required,max=200"`
	Deskripsi  string     `json:"deskripsi" binding:"required"`
	Prioritas  string     `json:"prioritas" binding:"required,oneof=rendah sedang tinggi kritis"`
	AssignedTo *uint64    `json:"assigned_to"`
	TenggatAt  *time.Time `json:"tenggat_at"`
}

// Request DTO Transisi Status
type TransitionStatusRequest struct {
	StatusBaru          string `json:"status_baru" binding:"required,oneof=sedang_diproses menunggu_informasi selesai ditolak"`
	CatatanTindakan     string `json:"catatan_tindakan" binding:"required"`
	CatatanPenyelesaian string `json:"catatan_penyelesaian"`
}

// Filter Query DTO untuk List Kendala
type IssueFilter struct {
	Search     string
	Status     string
	Prioritas  string
	CategoryID uint64
	AssignedTo uint64
	From       string
	To         string
	IsArchived *bool
	IsOverdue  *bool
	Page       int
	Limit      int
}

type PaginatedResult struct {
	Items      interface{} `json:"items"`
	Total      int         `json:"total"`
	Page       int         `json:"page"`
	Limit      int         `json:"limit"`
	TotalPages int         `json:"total_pages"`
}

// ---------------- DTO FASE 3: DASHBOARD & REPORT ----------------

// DashboardSummaryResponse untuk GET /api/v1/dashboard/summary
type DashboardSummaryResponse struct {
	TotalKendala             int     `json:"total"`
	Baru                     int     `json:"baru"`
	SedangDiproses           int     `json:"sedang_diproses"`
	MenungguInformasi        int     `json:"menunggu_informasi"`
	Selesai                  int     `json:"selesai"`
	Ditolak                  int     `json:"ditolak"`
	Terlambat                int     `json:"terlambat"`
	RataRataWaktuPenyelesaian float64 `json:"rata_rata_waktu_jam"`
	PersentaseSelesai        float64 `json:"persentase_selesai"`
}

// CategoryStatResponse untuk GET /api/v1/dashboard/by-category
type CategoryStatResponse struct {
	CategoryID uint64  `db:"category_id" json:"category_id"`
	Nama       string  `db:"nama" json:"nama"`
	WarnaHex   string  `db:"warna_hex" json:"warna_hex"`
	Ikon       string  `db:"ikon" json:"ikon"`
	Total      int     `db:"total" json:"total"`
	Persentase float64 `db:"persentase" json:"persentase"`
}

// TrendPointResponse untuk GET /api/v1/dashboard/trend
type TrendPointResponse struct {
	Label          string `json:"label"` // Misal "2026-10-20" atau "Okt 2026"
	Tanggal        string `json:"tanggal"`
	TotalMasuk     int    `json:"total_masuk"`
	TotalSelesai   int    `json:"total_selesai"`
}

// StatusBreakdown untuk rekap laporan
type StatusBreakdown struct {
	Baru              int `json:"baru"`
	SedangDiproses    int `json:"sedang_diproses"`
	MenungguInformasi int `json:"menunggu_informasi"`
	Selesai           int `json:"selesai"`
	Ditolak           int `json:"ditolak"`
}

// CategoryRecapItem untuk GET /api/v1/reports/recap
type CategoryRecapItem struct {
	CategoryID uint64          `json:"category_id"`
	Nama       string          `json:"nama"`
	WarnaHex   string          `json:"warna_hex"`
	Total      int             `json:"total"`
	Status     StatusBreakdown `json:"status"`
}

// ReportRecapResponse untuk GET /api/v1/reports/recap
type ReportRecapResponse struct {
	TotalKendala         int                 `json:"total_kendala"`
	KategoriPalingSering *string             `json:"kategori_paling_sering"`
	RekapStatus          StatusBreakdown     `json:"rekap_status"`
	PerKategori          []CategoryRecapItem `json:"per_kategori"`
}

// ActivityLogItem untuk GET /api/v1/activities
type ActivityLogItem struct {
	ID               uint64    `db:"id" json:"id"`
	IssueID          uint64    `db:"issue_id" json:"issue_id"`
	KodeKendala      string    `db:"kode_kendala" json:"kode_kendala"`
	JudulKendala     string    `db:"judul_kendala" json:"judul_kendala"`
	StatusSebelumnya string    `db:"status_sebelumnya" json:"status_sebelumnya"`
	StatusBaru       string    `db:"status_baru" json:"status_baru"`
	CatatanTindakan  string    `db:"catatan_tindakan" json:"catatan_tindakan"`
	OlehUserID       uint64    `db:"oleh_user_id" json:"oleh_user_id"`
	OlehUserNama     string    `db:"oleh_user_nama" json:"oleh_user_nama"`
	CreatedAt        time.Time `db:"created_at" json:"created_at"`
}

