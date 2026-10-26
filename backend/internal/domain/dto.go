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
