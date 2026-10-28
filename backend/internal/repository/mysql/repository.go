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

func (r *Repository) UpdateUserPassword(id uint64, passwordHash string) error {
	query := "UPDATE users SET password_hash = ? WHERE id = ?"
	_, err := r.db.Exec(query, passwordHash, id)
	return err
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
				c.nama AS category_nama, 
				COALESCE(NULLIF(c.warna_hex, ''), '#4F46E5') AS category_warna_hex, 
				COALESCE(NULLIF(c.ikon, ''), 'warning_amber_rounded') AS category_ikon,
				COALESCE(u_assigned.nama, '-') AS assigned_nama,
				u_creator.nama AS created_by_nama,
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
		parts := strings.Split(filter.Prioritas, ",")
		if len(parts) > 1 {
			placeholders := make([]string, len(parts))
			for i, p := range parts {
				placeholders[i] = "?"
				args = append(args, strings.TrimSpace(p))
			}
			conditions = append(conditions, fmt.Sprintf("oi.prioritas IN (%s)", strings.Join(placeholders, ",")))
		} else {
			conditions = append(conditions, "oi.prioritas = ?")
			args = append(args, strings.TrimSpace(filter.Prioritas))
		}
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

	if len(filter.IDs) > 0 {
		placeholders := make([]string, len(filter.IDs))
		for i, id := range filter.IDs {
			placeholders[i] = "?"
			args = append(args, id)
		}
		conditions = append(conditions, fmt.Sprintf("oi.id IN (%s)", strings.Join(placeholders, ",")))
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
			c.nama AS category_nama, 
			COALESCE(NULLIF(c.warna_hex, ''), '#4F46E5') AS category_warna_hex, 
			COALESCE(NULLIF(c.ikon, ''), 'warning_amber_rounded') AS category_ikon,
			COALESCE(u_assigned.nama, '-') AS assigned_nama,
			u_creator.nama AS created_by_nama,
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

// ---------------- FASE 3: DASHBOARD & REPORT REPOSITORY ----------------

type RawSummaryStats struct {
	Total             int             `db:"total"`
	Baru              int             `db:"baru"`
	SedangDiproses    int             `db:"sedang_diproses"`
	MenungguInformasi int             `db:"menunggu_informasi"`
	Selesai           int             `db:"selesai"`
	Ditolak           int             `db:"ditolak"`
	Terlambat         int             `db:"terlambat"`
	JatuhTempoSegera  int             `db:"jatuh_tempo_segera"`
	TotalDurationSec  sql.NullFloat64 `db:"total_duration_sec"`
	ResolvedCount     int             `db:"resolved_count"`
}

func (r *Repository) GetDashboardSummaryStats() (*RawSummaryStats, error) {
	query := `
		SELECT 
			COUNT(*) AS total,
			COALESCE(SUM(CASE WHEN status = 'baru' THEN 1 ELSE 0 END), 0) AS baru,
			COALESCE(SUM(CASE WHEN status = 'sedang_diproses' THEN 1 ELSE 0 END), 0) AS sedang_diproses,
			COALESCE(SUM(CASE WHEN status = 'menunggu_informasi' THEN 1 ELSE 0 END), 0) AS menunggu_informasi,
			COALESCE(SUM(CASE WHEN status = 'selesai' THEN 1 ELSE 0 END), 0) AS selesai,
			COALESCE(SUM(CASE WHEN status = 'ditolak' THEN 1 ELSE 0 END), 0) AS ditolak,
			COALESCE(SUM(CASE WHEN status NOT IN ('selesai', 'ditolak') AND tenggat_at < UTC_TIMESTAMP() THEN 1 ELSE 0 END), 0) AS terlambat,
			COALESCE(SUM(CASE WHEN status NOT IN ('selesai', 'ditolak') AND tenggat_at > UTC_TIMESTAMP() AND tenggat_at <= UTC_TIMESTAMP() + INTERVAL 24 HOUR THEN 1 ELSE 0 END), 0) AS jatuh_tempo_segera,
			COALESCE(SUM(CASE WHEN status = 'selesai' AND resolved_at IS NOT NULL THEN TIMESTAMPDIFF(SECOND, created_at, resolved_at) ELSE 0 END), 0) AS total_duration_sec,
			COALESCE(SUM(CASE WHEN status = 'selesai' AND resolved_at IS NOT NULL THEN 1 ELSE 0 END), 0) AS resolved_count
		FROM order_issues
		WHERE is_archived = 0`

	var s RawSummaryStats
	err := r.db.Get(&s, query)
	if err != nil {
		return nil, err
	}
	return &s, nil
}

func (r *Repository) GetCategoryStats() ([]domain.CategoryStatResponse, error) {
	query := `
		SELECT 
			c.id AS category_id,
			c.nama,
			COALESCE(NULLIF(c.warna_hex, ''), '#4F46E5') AS warna_hex,
			COALESCE(NULLIF(c.ikon, ''), 'warning_amber_rounded') AS ikon,
			COUNT(oi.id) AS total
		FROM problem_categories c
		LEFT JOIN order_issues oi ON c.id = oi.category_id AND oi.is_archived = 0
		GROUP BY c.id, c.nama, c.warna_hex, c.ikon
		ORDER BY total DESC, c.id ASC`

	var list []domain.CategoryStatResponse
	err := r.db.Select(&list, query)
	return list, err
}

type TrendRow struct {
	DateGroup    string `db:"date_group"`
	TotalMasuk   int    `db:"total_masuk"`
	TotalSelesai int    `db:"total_selesai"`
}

func (r *Repository) GetTrendData7Days() ([]TrendRow, error) {
	query := `
		SELECT 
			DATE_FORMAT(d.dt, '%Y-%m-%d') AS date_group,
			COALESCE(SUM(CASE WHEN DATE(oi.created_at) = d.dt AND oi.is_archived = 0 THEN 1 ELSE 0 END), 0) AS total_masuk,
			COALESCE(SUM(CASE WHEN oi.status = 'selesai' AND oi.resolved_at IS NOT NULL AND DATE(oi.resolved_at) = d.dt AND oi.is_archived = 0 THEN 1 ELSE 0 END), 0) AS total_selesai
		FROM (
			SELECT CURDATE() - INTERVAL (a.a) DAY AS dt
			FROM (
				SELECT 6 AS a UNION ALL SELECT 5 UNION ALL SELECT 4 UNION ALL SELECT 3 UNION ALL SELECT 2 UNION ALL SELECT 1 UNION ALL SELECT 0
			) a
		) d
		LEFT JOIN order_issues oi ON (DATE(oi.created_at) = d.dt OR (oi.status = 'selesai' AND DATE(oi.resolved_at) = d.dt))
		GROUP BY d.dt
		ORDER BY d.dt ASC`

	var rows []TrendRow
	err := r.db.Select(&rows, query)
	return rows, err
}

func (r *Repository) GetTrendData30Days() ([]TrendRow, error) {
	query := `
		SELECT 
			DATE_FORMAT(d.dt, '%Y-%m-%d') AS date_group,
			COALESCE(SUM(CASE WHEN DATE(oi.created_at) = d.dt AND oi.is_archived = 0 THEN 1 ELSE 0 END), 0) AS total_masuk,
			COALESCE(SUM(CASE WHEN oi.status = 'selesai' AND oi.resolved_at IS NOT NULL AND DATE(oi.resolved_at) = d.dt AND oi.is_archived = 0 THEN 1 ELSE 0 END), 0) AS total_selesai
		FROM (
			SELECT CURDATE() - INTERVAL (t.n) DAY AS dt
			FROM (
				SELECT a.i + b.i*10 AS n
				FROM (SELECT 0 AS i UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
				CROSS JOIN (SELECT 0 AS i UNION ALL SELECT 1 UNION ALL SELECT 2) b
			) t
			WHERE t.n <= 29
		) d
		LEFT JOIN order_issues oi ON (DATE(oi.created_at) = d.dt OR (oi.status = 'selesai' AND DATE(oi.resolved_at) = d.dt))
		GROUP BY d.dt
		ORDER BY d.dt ASC`

	var rows []TrendRow
	err := r.db.Select(&rows, query)
	return rows, err
}

func (r *Repository) GetTrendData12Months() ([]TrendRow, error) {
	query := `
		SELECT 
			DATE_FORMAT(d.m_first, '%Y-%m') AS date_group,
			COALESCE(SUM(CASE WHEN DATE_FORMAT(oi.created_at, '%Y-%m') = DATE_FORMAT(d.m_first, '%Y-%m') AND oi.is_archived = 0 THEN 1 ELSE 0 END), 0) AS total_masuk,
			COALESCE(SUM(CASE WHEN oi.status = 'selesai' AND oi.resolved_at IS NOT NULL AND DATE_FORMAT(oi.resolved_at, '%Y-%m') = DATE_FORMAT(d.m_first, '%Y-%m') AND oi.is_archived = 0 THEN 1 ELSE 0 END), 0) AS total_selesai
		FROM (
			SELECT (CURDATE() - INTERVAL (m.n) MONTH) AS m_first
			FROM (
				SELECT 11 AS n UNION ALL SELECT 10 UNION ALL SELECT 9 UNION ALL SELECT 8 UNION ALL
				SELECT 7 UNION ALL SELECT 6 UNION ALL SELECT 5 UNION ALL SELECT 4 UNION ALL
				SELECT 3 UNION ALL SELECT 2 UNION ALL SELECT 1 UNION ALL SELECT 0
			) m
		) d
		LEFT JOIN order_issues oi ON (DATE_FORMAT(oi.created_at, '%Y-%m') = DATE_FORMAT(d.m_first, '%Y-%m') OR (oi.status = 'selesai' AND DATE_FORMAT(oi.resolved_at, '%Y-%m') = DATE_FORMAT(d.m_first, '%Y-%m')))
		GROUP BY DATE_FORMAT(d.m_first, '%Y-%m')
		ORDER BY DATE_FORMAT(d.m_first, '%Y-%m') ASC`

	var rows []TrendRow
	err := r.db.Select(&rows, query)
	return rows, err
}

func (r *Repository) GetIssuesForReport(from, to string) ([]domain.OrderIssue, error) {
	var conditions []string
	var args []interface{}

	conditions = append(conditions, "oi.is_archived = 0")
	if from != "" {
		conditions = append(conditions, "oi.created_at >= ?")
		args = append(args, from+" 00:00:00")
	}
	if to != "" {
		conditions = append(conditions, "oi.created_at <= ?")
		args = append(args, to+" 23:59:59")
	}

	whereClause := " WHERE " + strings.Join(conditions, " AND ")
	query := fmt.Sprintf(`
		SELECT 
			oi.id, oi.kode_kendala, oi.order_id, oi.category_id, oi.judul, oi.deskripsi, 
			oi.prioritas, oi.status, oi.tenggat_at, oi.assigned_to, oi.catatan_penyelesaian, 
			oi.is_archived, oi.created_by, oi.created_at, oi.updated_at, oi.resolved_at,
			o.kode_pesanan, o.nama_pelanggan, o.produk AS produk_pesanan,
			c.nama AS category_nama, 
			COALESCE(NULLIF(c.warna_hex, ''), '#4F46E5') AS category_warna_hex, 
			COALESCE(NULLIF(c.ikon, ''), 'warning_amber_rounded') AS category_ikon,
			COALESCE(u_assigned.nama, '-') AS assigned_nama,
			u_creator.nama AS created_by_nama,
			(oi.status NOT IN ('selesai', 'ditolak') AND oi.tenggat_at < UTC_TIMESTAMP()) AS is_overdue
		FROM order_issues oi
		JOIN orders o ON oi.order_id = o.id
		JOIN problem_categories c ON oi.category_id = c.id
		LEFT JOIN users u_assigned ON oi.assigned_to = u_assigned.id
		JOIN users u_creator ON oi.created_by = u_creator.id
		%s
		ORDER BY oi.created_at DESC`, whereClause)

	var items []domain.OrderIssue
	err := r.db.Select(&items, query, args...)
	return items, err
}

func (r *Repository) GetActivityLogs(limit int) ([]domain.ActivityLogItem, error) {
	if limit <= 0 || limit > 100 {
		limit = 30
	}

	query := `
		SELECT 
			it.id,
			it.issue_id,
			oi.kode_kendala,
			oi.judul AS judul_kendala,
			it.status_sebelumnya,
			it.status_baru,
			it.catatan_tindakan,
			it.oleh_user_id,
			u.nama AS oleh_user_nama,
			it.created_at
		FROM issue_transactions it
		JOIN order_issues oi ON it.issue_id = oi.id
		JOIN users u ON it.oleh_user_id = u.id
		ORDER BY it.created_at DESC, it.id DESC
		LIMIT ?`

	var list []domain.ActivityLogItem
	err := r.db.Select(&list, query, limit)
	return list, err
}

// ---------------- FASE 6: COMMENTS, REASSIGN & DUE SOON REPOSITORY ----------------

func (r *Repository) GetCommentsByIssueID(issueID uint64) ([]domain.IssueComment, error) {
	query := `
		SELECT 
			c.id,
			c.issue_id,
			c.user_id,
			c.tipe,
			c.isi,
			c.created_at,
			u.nama AS user_nama,
			u.role AS user_role
		FROM issue_comments c
		JOIN users u ON c.user_id = u.id
		WHERE c.issue_id = ?
		ORDER BY c.created_at ASC, c.id ASC`

	var comments []domain.IssueComment
	err := r.db.Select(&comments, query, issueID)
	return comments, err
}

func (r *Repository) CreateComment(issueID, userID uint64, tipe, isi string) (*domain.IssueComment, error) {
	query := `INSERT INTO issue_comments (issue_id, user_id, tipe, isi, created_at) VALUES (?, ?, ?, ?, UTC_TIMESTAMP())`
	res, err := r.db.Exec(query, issueID, userID, tipe, isi)
	if err != nil {
		return nil, err
	}

	id, err := res.LastInsertId()
	if err != nil {
		return nil, err
	}

	return r.GetCommentByID(uint64(id))
}

func (r *Repository) CreateCommentTx(tx *sqlx.Tx, issueID, userID uint64, tipe, isi string) error {
	query := `INSERT INTO issue_comments (issue_id, user_id, tipe, isi, created_at) VALUES (?, ?, ?, ?, UTC_TIMESTAMP())`
	_, err := tx.Exec(query, issueID, userID, tipe, isi)
	return err
}

func (r *Repository) UpdateIssueAssignedToTx(tx *sqlx.Tx, issueID, assignedTo uint64) error {
	query := `UPDATE order_issues SET assigned_to = ?, updated_at = UTC_TIMESTAMP() WHERE id = ?`
	_, err := tx.Exec(query, assignedTo, issueID)
	return err
}

func (r *Repository) GetCommentByID(id uint64) (*domain.IssueComment, error) {
	query := `
		SELECT 
			c.id,
			c.issue_id,
			c.user_id,
			c.tipe,
			c.isi,
			c.created_at,
			u.nama AS user_nama,
			u.role AS user_role
		FROM issue_comments c
		JOIN users u ON c.user_id = u.id
		WHERE c.id = ?`

	var comment domain.IssueComment
	err := r.db.Get(&comment, query, id)
	return &comment, err
}

func (r *Repository) GetIssuesDueSoon(hours int) ([]domain.OrderIssue, error) {
	if hours <= 0 {
		hours = 24
	}

	query := `
		SELECT 
			oi.id,
			oi.kode_kendala,
			oi.order_id,
			oi.category_id,
			oi.judul,
			oi.deskripsi,
			oi.prioritas,
			oi.status,
			oi.tenggat_at,
			oi.assigned_to,
			oi.catatan_penyelesaian,
			oi.is_archived,
			oi.created_by,
			oi.created_at,
			oi.updated_at,
			oi.resolved_at,
			o.kode_pesanan,
			o.nama_pelanggan,
			c.nama AS category_nama,
			c.warna_hex AS category_warna_hex,
			c.ikon AS category_ikon,
			COALESCE(u_assign.nama, '-') AS assigned_nama,
			u_creator.nama AS created_by_nama,
			(oi.status NOT IN ('selesai', 'ditolak') AND oi.tenggat_at < UTC_TIMESTAMP()) AS is_overdue
		FROM order_issues oi
		JOIN orders o ON oi.order_id = o.id
		JOIN problem_categories c ON oi.category_id = c.id
		JOIN users u_creator ON oi.created_by = u_creator.id
		LEFT JOIN users u_assign ON oi.assigned_to = u_assign.id
		WHERE oi.is_archived = 0
		  AND oi.status NOT IN ('selesai', 'ditolak')
		  AND oi.tenggat_at > UTC_TIMESTAMP()
		  AND oi.tenggat_at <= UTC_TIMESTAMP() + INTERVAL ? HOUR
		ORDER BY oi.tenggat_at ASC`

	var list []domain.OrderIssue
	err := r.db.Select(&list, query, hours)
	return list, err
}


