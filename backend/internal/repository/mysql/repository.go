package mysql

import (
	"database/sql"
	"fmt"
	"strings"
	"time"

	"github.com/flowrestia/kendalaku/backend/internal/domain"
	"github.com/jmoiron/sqlx"
)

type Repository struct {
	db *sqlx.DB
}

func NewRepository(db *sqlx.DB) *Repository {
	return &Repository{db: db}
}

// ---------------- USER REPOSITORY ----------------

func (r *Repository) GetUserByEmail(email string) (*domain.User, error) {
	var user domain.User
	query := "SELECT id, nama, email, password_hash, role, created_at FROM users WHERE email = ?"
	err := r.db.Get(&user, query, email)
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *Repository) GetUserByID(id uint64) (*domain.User, error) {
	var user domain.User
	query := "SELECT id, nama, email, password_hash, role, created_at FROM users WHERE id = ?"
	err := r.db.Get(&user, query, id)
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (r *Repository) GetAllUsers() ([]domain.User, error) {
	var users []domain.User
	query := "SELECT id, nama, email, role, created_at FROM users ORDER BY nama ASC"
	err := r.db.Select(&users, query)
	return users, err
}

// ---------------- PROBLEM CATEGORY REPOSITORY ----------------

func (r *Repository) GetAllCategories(onlyActive bool) ([]domain.ProblemCategory, error) {
	var categories []domain.ProblemCategory
	query := "SELECT id, nama, warna_hex, ikon, tenggat_jam, aktif, created_at, updated_at FROM problem_categories"
	if onlyActive {
		query += " WHERE aktif = 1"
	}
	query += " ORDER BY nama ASC"
	err := r.db.Select(&categories, query)
	return categories, err
}

func (r *Repository) GetCategoryByID(id uint64) (*domain.ProblemCategory, error) {
	var category domain.ProblemCategory
	query := "SELECT id, nama, warna_hex, ikon, tenggat_jam, aktif, created_at, updated_at FROM problem_categories WHERE id = ?"
	err := r.db.Get(&category, query, id)
	if err != nil {
		return nil, err
	}
	return &category, nil
}

func (r *Repository) CreateCategory(cat *domain.ProblemCategory) (uint64, error) {
	query := `INSERT INTO problem_categories (nama, warna_hex, ikon, tenggat_jam, aktif, created_at, updated_at)
			  VALUES (?, ?, ?, ?, ?, NOW(), NOW())`
	res, err := r.db.Exec(query, cat.Nama, cat.WarnaHex, cat.Ikon, cat.TenggatJam, cat.Aktif)
	if err != nil {
		return 0, err
	}
	id, err := res.LastInsertId()
	return uint64(id), err
}

func (r *Repository) UpdateCategory(id uint64, cat *domain.ProblemCategory) error {
	query := `UPDATE problem_categories 
			  SET nama = ?, warna_hex = ?, ikon = ?, tenggat_jam = ?, aktif = ?, updated_at = NOW()
			  WHERE id = ?`
	_, err := r.db.Exec(query, cat.Nama, cat.WarnaHex, cat.Ikon, cat.TenggatJam, cat.Aktif, id)
	return err
}

func (r *Repository) DeleteCategory(id uint64) error {
	// Cek apakah sudah digunakan oleh order_issues
	var count int
	err := r.db.Get(&count, "SELECT COUNT(*) FROM order_issues WHERE category_id = ?", id)
	if err != nil {
		return err
	}
	if count > 0 {
		return fmt.Errorf("kategori tidak boleh dihapus karena telah digunakan pada %d kendala pesanan, silakan nonaktifkan saja", count)
	}

	_, err = r.db.Exec("DELETE FROM problem_categories WHERE id = ?", id)
	return err
}

// ---------------- ORDER SIMULASI REPOSITORY ----------------

func (r *Repository) GetAllOrders() ([]domain.Order, error) {
	var orders []domain.Order
	query := "SELECT id, kode_pesanan, nama_pelanggan, produk, jumlah, created_at FROM orders ORDER BY id DESC"
	err := r.db.Select(&orders, query)
	return orders, err
}

func (r *Repository) GetOrderByID(id uint64) (*domain.Order, error) {
	var order domain.Order
	query := "SELECT id, kode_pesanan, nama_pelanggan, produk, jumlah, created_at FROM orders WHERE id = ?"
	err := r.db.Get(&order, query, id)
	if err != nil {
		return nil, err
	}
	return &order, nil
}

// ---------------- ORDER ISSUES REPOSITORY ----------------

// GenerateNextIssueCode menghasilkan kode KDL-YYYYMM-XXXX unik dan aman dari race condition menggunakan DB Transaction & SELECT ... FOR UPDATE
func (r *Repository) GenerateNextIssueCode(tx *sqlx.Tx) (string, error) {
	now := time.Now().UTC()
	prefix := fmt.Sprintf("KDL-%s-", now.Format("200601"))

	var lastCode sql.NullString
	// Mengunci baris terakhir pada bulan ini untuk mencegah duplikasi bersamaan
	query := `SELECT kode_kendala FROM order_issues 
			  WHERE kode_kendala LIKE ? 
			  ORDER BY kode_kendala DESC LIMIT 1 FOR UPDATE`
	err := tx.Get(&lastCode, query, prefix+"%")
	if err != nil && err != sql.ErrNoRows {
		return "", err
	}

	nextSeq := 1
	if lastCode.Valid && len(lastCode.String) >= len(prefix)+4 {
		var seq int
		_, err := fmt.Sscanf(lastCode.String, prefix+"%d", &seq)
		if err == nil {
			nextSeq = seq + 1
		}
	}

	return fmt.Sprintf("%s%04d", prefix, nextSeq), nil
}

func (r *Repository) CreateIssue(tx *sqlx.Tx, issue *domain.OrderIssue) (uint64, error) {
	query := `INSERT INTO order_issues 
		(kode_kendala, order_id, category_id, judul, deskripsi, prioritas, status, tenggat_at, assigned_to, catatan_penyelesaian, is_archived, created_by, created_at, updated_at, resolved_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, NOW(), NOW(), NULL)`

	res, err := tx.Exec(query,
		issue.KodeKendala, issue.OrderID, issue.CategoryID, issue.Judul, issue.Deskripsi,
		issue.Prioritas, issue.Status, issue.TenggatAt, issue.AssignedTo, issue.CatatanPenyelesaian, issue.CreatedBy,
	)
	if err != nil {
		return 0, err
	}
	id, err := res.LastInsertId()
	return uint64(id), err
}

func (r *Repository) GetIssueByID(id uint64) (*domain.OrderIssue, error) {
	var issue domain.OrderIssue
	query := `SELECT 
				oi.id, oi.kode_kendala, oi.order_id, oi.category_id, oi.judul, oi.deskripsi, 
				oi.prioritas, oi.status, oi.tenggat_at, oi.assigned_to, oi.catatan_penyelesaian, 
				oi.is_archived, oi.created_by, oi.created_at, oi.updated_at, oi.resolved_at,
				o.kode_pesanan, o.nama_pelanggan, o.produk AS produk_pesanan,
				c.nama AS nama_kategori, c.warna_hex AS warna_kategori, c.ikon AS ikon_kategori,
				COALESCE(u_assigned.nama, '-') AS nama_petugas,
				u_creator.nama AS nama_pembuat,
				(oi.status NOT IN ('selesai', 'ditolak') AND oi.tenggat_at < UTC_TIMESTAMP()) AS is_overdue
			  FROM order_issues oi
			  JOIN orders o ON oi.order_id = o.id
			  JOIN problem_categories c ON oi.category_id = c.id
			  LEFT JOIN users u_assigned ON oi.assigned_to = u_assigned.id
			  JOIN users u_creator ON oi.created_by = u_creator.id
			  WHERE oi.id = ?`

	err := r.db.Get(&issue, query, id)
	if err != nil {
		return nil, err
	}
	return &issue, nil
}

func (r *Repository) GetIssueByIDForUpdate(tx *sqlx.Tx, id uint64) (*domain.OrderIssue, error) {
	var issue domain.OrderIssue
	query := `SELECT id, kode_kendala, order_id, category_id, judul, deskripsi, prioritas, status, tenggat_at, assigned_to, catatan_penyelesaian, is_archived, created_by, created_at, updated_at, resolved_at 
			  FROM order_issues WHERE id = ? FOR UPDATE`
	err := tx.Get(&issue, query, id)
	if err != nil {
		return nil, err
	}
	return &issue, nil
}

func (r *Repository) UpdateIssue(id uint64, req *domain.UpdateIssueRequest) error {
	query := `UPDATE order_issues 
			  SET judul = ?, deskripsi = ?, prioritas = ?, assigned_to = ?, tenggat_at = COALESCE(?, tenggat_at), updated_at = NOW()
			  WHERE id = ?`
	_, err := r.db.Exec(query, req.Judul, req.Deskripsi, req.Prioritas, req.AssignedTo, req.TenggatAt, id)
	return err
}

func (r *Repository) SetArchiveStatus(id uint64, isArchived bool) error {
	_, err := r.db.Exec("UPDATE order_issues SET is_archived = ?, updated_at = NOW() WHERE id = ?", isArchived, id)
	return err
}

func (r *Repository) DeleteIssue(id uint64) error {
	_, err := r.db.Exec("DELETE FROM order_issues WHERE id = ?", id)
	return err
}

// ---------------- TRANSAKSI STATUS TRANSITION REPOSITORY ----------------


func (r *Repository) RecordTransaction(tx *sqlx.Tx, issueID uint64, statusSebelumnya, statusBaru, catatanTindakan string, userID uint64) error {
	query := `INSERT INTO issue_transactions 
			  (issue_id, status_sebelumnya, status_baru, catatan_tindakan, oleh_user_id, created_at)
			  VALUES (?, ?, ?, ?, ?, NOW())`
	_, err := tx.Exec(query, issueID, statusSebelumnya, statusBaru, catatanTindakan, userID)
	return err
}

func (r *Repository) GetTransactionsByIssueID(issueID uint64) ([]domain.IssueTransaction, error) {
	var list []domain.IssueTransaction
	query := `SELECT it.id, it.issue_id, it.status_sebelumnya, it.status_baru, it.catatan_tindakan, it.oleh_user_id, it.created_at, u.nama AS nama_user
			  FROM issue_transactions it
			  JOIN users u ON it.oleh_user_id = u.id
			  WHERE it.issue_id = ?
			  ORDER BY it.id ASC`
	err := r.db.Select(&list, query, issueID)
	return list, err
}

// ---------------- LIST KENDALA DENGAN FILTER, SEARCH, SORT, PAGINATION ----------------

func (r *Repository) ListIssues(filter domain.IssueFilter) ([]domain.OrderIssue, int, error) {
	var conditions []string
	var args []interface{}

	if filter.IsArchived != nil {
		conditions = append(conditions, "oi.is_archived = ?")
		args = append(args, *filter.IsArchived)
	} else {
		conditions = append(conditions, "oi.is_archived = 0")
	}

	if filter.Search != "" {
		s := "%" + filter.Search + "%"
		conditions = append(conditions, "(oi.kode_kendala LIKE ? OR oi.judul LIKE ? OR o.kode_pesanan LIKE ? OR o.nama_pelanggan LIKE ?)")
		args = append(args, s, s, s, s)
	}

	if filter.Status != "" {
		conditions = append(conditions, "oi.status = ?")
		args = append(args, filter.Status)
	}

	if filter.Prioritas != "" {
		conditions = append(conditions, "oi.prioritas = ?")
		args = append(args, filter.Prioritas)
	}

	if filter.CategoryID > 0 {
		conditions = append(conditions, "oi.category_id = ?")
		args = append(args, filter.CategoryID)
	}

	if filter.AssignedTo > 0 {
		conditions = append(conditions, "oi.assigned_to = ?")
		args = append(args, filter.AssignedTo)
	}

	if filter.From != "" {
		conditions = append(conditions, "oi.created_at >= ?")
		args = append(args, filter.From+" 00:00:00")
	}

	if filter.To != "" {
		conditions = append(conditions, "oi.created_at <= ?")
		args = append(args, filter.To+" 23:59:59")
	}

	if filter.IsOverdue != nil && *filter.IsOverdue {
		conditions = append(conditions, "oi.status NOT IN ('selesai', 'ditolak') AND oi.tenggat_at < UTC_TIMESTAMP()")
	}

	whereClause := ""
	if len(conditions) > 0 {
		whereClause = " WHERE " + strings.Join(conditions, " AND ")
	}

	// Hitung total data
	countQuery := fmt.Sprintf(`SELECT COUNT(*) 
								FROM order_issues oi 
								JOIN orders o ON oi.order_id = o.id 
								%s`, whereClause)
	var total int
	err := r.db.Get(&total, countQuery, args...)
	if err != nil {
		return nil, 0, err
	}

	// Paginasi
	if filter.Limit <= 0 {
		filter.Limit = 10
	}
	if filter.Page <= 0 {
		filter.Page = 1
	}
	offset := (filter.Page - 1) * filter.Limit

	dataQuery := fmt.Sprintf(`
		SELECT 
			oi.id, oi.kode_kendala, oi.order_id, oi.category_id, oi.judul, oi.deskripsi, 
			oi.prioritas, oi.status, oi.tenggat_at, oi.assigned_to, oi.catatan_penyelesaian, 
			oi.is_archived, oi.created_by, oi.created_at, oi.updated_at, oi.resolved_at,
			o.kode_pesanan, o.nama_pelanggan, o.produk AS produk_pesanan,
			c.nama AS nama_kategori, c.warna_hex AS warna_kategori, c.ikon AS ikon_kategori,
			COALESCE(u_assigned.nama, '-') AS nama_petugas,
			u_creator.nama AS nama_pembuat,
			(oi.status NOT IN ('selesai', 'ditolak') AND oi.tenggat_at < UTC_TIMESTAMP()) AS is_overdue
		FROM order_issues oi
		JOIN orders o ON oi.order_id = o.id
		JOIN problem_categories c ON oi.category_id = c.id
		LEFT JOIN users u_assigned ON oi.assigned_to = u_assigned.id
		JOIN users u_creator ON oi.created_by = u_creator.id
		%s
		ORDER BY oi.created_at DESC
		LIMIT ? OFFSET ?`, whereClause)

	args = append(args, filter.Limit, offset)

	var items []domain.OrderIssue
	err = r.db.Select(&items, dataQuery, args...)
	if err != nil {
		return nil, 0, err
	}

	return items, total, nil
}

func (r *Repository) BeginTx() (*sqlx.Tx, error) {
	return r.db.Beginx()
}
