package domain

import (
	"errors"
	"time"
)

// Definisi Role
const (
	RoleAdmin   = "admin"
	RolePetugas = "petugas"
)

// Definisi Prioritas
const (
	PrioritasRendah = "rendah"
	PrioritasSedang = "sedang"
	PrioritasTinggi = "tinggi"
	PrioritasKritis = "kritis"
)

// Definisi Status Kendala
const (
	StatusBaru              = "baru"
	StatusSedangDiproses    = "sedang_diproses"
	StatusMenungguInformasi = "menunggu_informasi"
	StatusSelesai           = "selesai"
	StatusDitolak           = "ditolak"
)

// Model Pengguna
type User struct {
	ID           uint64    `db:"id" json:"id"`
	Nama         string    `db:"nama" json:"nama"`
	Email        string    `db:"email" json:"email"`
	PasswordHash string    `db:"password_hash" json:"-"`
	Role         string    `db:"role" json:"role"`
	CreatedAt    time.Time `db:"created_at" json:"created_at"`
}

// Model Kategori Kendala
type ProblemCategory struct {
	ID         uint64    `db:"id" json:"id"`
	Nama       string    `db:"nama" json:"nama"`
	WarnaHex   string    `db:"warna_hex" json:"warna_hex"`
	Ikon       string    `db:"ikon" json:"ikon"`
	TenggatJam int       `db:"tenggat_jam" json:"tenggat_jam"`
	Aktif      bool      `db:"aktif" json:"aktif"`
	CreatedAt  time.Time `db:"created_at" json:"created_at"`
	UpdatedAt  time.Time `db:"updated_at" json:"updated_at"`
}

// Model Pesanan Simulasi
type Order struct {
	ID            uint64    `db:"id" json:"id"`
	KodePesanan   string    `db:"kode_pesanan" json:"kode_pesanan"`
	NamaPelanggan string    `db:"nama_pelanggan" json:"nama_pelanggan"`
	Produk        string    `db:"produk" json:"produk"`
	Jumlah        int       `db:"jumlah" json:"jumlah"`
	CreatedAt     time.Time `db:"created_at" json:"created_at"`
}

// Model Kendala Pesanan
type OrderIssue struct {
	ID                  uint64     `db:"id" json:"id"`
	KodeKendala         string     `db:"kode_kendala" json:"kode_kendala"`
	OrderID             uint64     `db:"order_id" json:"order_id"`
	CategoryID          uint64     `db:"category_id" json:"category_id"`
	Judul               string     `db:"judul" json:"judul"`
	Deskripsi           string     `db:"deskripsi" json:"deskripsi"`
	Prioritas           string     `db:"prioritas" json:"prioritas"`
	Status              string     `db:"status" json:"status"`
	TenggatAt           time.Time  `db:"tenggat_at" json:"tenggat_at"`
	AssignedTo          *uint64    `db:"assigned_to" json:"assigned_to"`
	CatatanPenyelesaian *string    `db:"catatan_penyelesaian" json:"catatan_penyelesaian"`
	IsArchived          bool       `db:"is_archived" json:"is_archived"`
	CreatedBy           uint64     `db:"created_by" json:"created_by"`
	CreatedAt           time.Time  `db:"created_at" json:"created_at"`
	UpdatedAt           time.Time  `db:"updated_at" json:"updated_at"`
	ResolvedAt          *time.Time `db:"resolved_at" json:"resolved_at"`

	// Join / Relasi fields lewat JOIN
	KodePesanan      string `db:"kode_pesanan" json:"kode_pesanan"`
	NamaPelanggan    string `db:"nama_pelanggan" json:"nama_pelanggan"`
	ProdukPesanan    string `db:"produk_pesanan" json:"produk_pesanan,omitempty"`
	CategoryNama     string `db:"category_nama" json:"category_nama"`
	CategoryWarnaHex string `db:"category_warna_hex" json:"category_warna_hex"`
	CategoryIkon     string `db:"category_ikon" json:"category_ikon"`
	AssignedNama     string `db:"assigned_nama" json:"assigned_nama"`
	CreatedByNama    string `db:"created_by_nama" json:"created_by_nama"`
	IsOverdue        bool   `db:"is_overdue" json:"is_overdue"`
}

// Model Transaksi Penanganan Kendala
type IssueTransaction struct {
	ID               uint64    `db:"id" json:"id"`
	IssueID          uint64    `db:"issue_id" json:"issue_id"`
	StatusSebelumnya string    `db:"status_sebelumnya" json:"status_sebelumnya"`
	StatusBaru       string    `db:"status_baru" json:"status_baru"`
	CatatanTindakan  string    `db:"catatan_tindakan" json:"catatan_tindakan"`
	OlehUserID       uint64    `db:"oleh_user_id" json:"oleh_user_id"`
	CreatedAt        time.Time `db:"created_at" json:"created_at"`

	// Relasi
	NamaUser string `db:"nama_user" json:"nama_user,omitempty"`
}

// Validasi Transisi Status Bisnis
// baru -> sedang_diproses | ditolak
// sedang_diproses -> menunggu_informasi | selesai | ditolak
// menunggu_informasi -> sedang_diproses
// selesai & ditolak = status akhir (tidak bisa diubah lagi)
func ValidateStatusTransition(statusLama, statusBaru, catatanPenyelesaian string) error {
	if statusLama == statusBaru {
		return errors.New("status baru sama dengan status saat ini")
	}

	if statusLama == StatusSelesai || statusLama == StatusDitolak {
		return errors.New("kendala telah berada pada status akhir (selesai/ditolak) dan tidak dapat diubah lagi")
	}

	valid := false
	switch statusLama {
	case StatusBaru:
		if statusBaru == StatusSedangDiproses || statusBaru == StatusDitolak {
			valid = true
		}
	case StatusSedangDiproses:
		if statusBaru == StatusMenungguInformasi || statusBaru == StatusSelesai || statusBaru == StatusDitolak {
			valid = true
		}
	case StatusMenungguInformasi:
		if statusBaru == StatusSedangDiproses {
			valid = true
		}
	default:
		return errors.New("status awal kendala tidak dikenali")
	}

	if !valid {
		return errors.New("transisi status dari '" + statusLama + "' ke '" + statusBaru + "' tidak diizinkan")
	}

	// Aturan: status selesai WAJIB memiliki catatan penyelesaian
	if statusBaru == StatusSelesai && catatanPenyelesaian == "" {
		return errors.New("catatan penyelesaian wajib diisi jika status diubah menjadi selesai")
	}

	return nil
}
