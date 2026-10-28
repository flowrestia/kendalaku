package handler

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/flowrestia/kendalaku/backend/internal/domain"
	"github.com/flowrestia/kendalaku/backend/internal/middleware"
	"github.com/flowrestia/kendalaku/backend/internal/service"
	"github.com/flowrestia/kendalaku/backend/pkg/jwt"
	"github.com/flowrestia/kendalaku/backend/pkg/response"
	"github.com/gin-gonic/gin"
)

type Handler struct {
	svc *service.Service
}

func NewHandler(svc *service.Service) *Handler {
	return &Handler{svc: svc}
}

func (h *Handler) getClaims(c *gin.Context) *jwt.Claims {
	val, ok := c.Get(middleware.AuthorizationPayloadKey)
	if !ok {
		return nil
	}
	claims, _ := val.(*jwt.Claims)
	return claims
}

// ---------------- AUTH HANDLER ----------------

func (h *Handler) Login(c *gin.Context) {
	var req domain.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Email dan password wajib diisi dengan benar: "+err.Error())
		return
	}

	res, err := h.svc.Login(req)
	if err != nil {
		response.Unauthorized(c, err.Error())
		return
	}

	response.Success(c, http.StatusOK, res)
}

func (h *Handler) GetMe(c *gin.Context) {
	claims := h.getClaims(c)
	if claims == nil {
		response.Unauthorized(c, "Sesi tidak valid")
		return
	}

	user, err := h.svc.GetUserProfile(claims.UserID)
	if err != nil {
		response.NotFound(c, "Pengguna tidak ditemukan")
		return
	}

	response.Success(c, http.StatusOK, user)
}

func (h *Handler) GetUsers(c *gin.Context) {
	users, err := h.svc.GetAllUsers()
	if err != nil {
		response.InternalServerError(c, "Gagal mengambil daftar pengguna: "+err.Error())
		return
	}
	response.Success(c, http.StatusOK, users)
}

// ---------------- PROBLEM CATEGORY HANDLER ----------------

func (h *Handler) GetCategories(c *gin.Context) {
	onlyActive := c.Query("aktif") == "true"
	categories, err := h.svc.GetAllCategories(onlyActive)
	if err != nil {
		response.InternalServerError(c, "Gagal mengambil kategori: "+err.Error())
		return
	}
	response.Success(c, http.StatusOK, categories)
}

func (h *Handler) CreateCategory(c *gin.Context) {
	var req domain.CategoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Data kategori tidak valid: "+err.Error())
		return
	}

	cat, err := h.svc.CreateCategory(req)
	if err != nil {
		response.InternalServerError(c, "Gagal menambah kategori: "+err.Error())
		return
	}

	response.Success(c, http.StatusCreated, cat)
}

func (h *Handler) UpdateCategory(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "ID kategori tidak valid")
		return
	}

	var req domain.CategoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Data kategori tidak valid: "+err.Error())
		return
	}

	cat, err := h.svc.UpdateCategory(id, req)
	if err != nil {
		response.UnprocessableEntity(c, "UPDATE_FAILED", err.Error())
		return
	}

	response.Success(c, http.StatusOK, cat)
}

func (h *Handler) DeleteCategory(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "ID kategori tidak valid")
		return
	}

	if err := h.svc.DeleteCategory(id); err != nil {
		response.UnprocessableEntity(c, "DELETE_CATEGORY_RESTRICTED", err.Error())
		return
	}

	response.Success(c, http.StatusOK, gin.H{"message": "Kategori berhasil dihapus"})
}

// ---------------- ORDERS SIMULASI HANDLER ----------------

func (h *Handler) GetOrders(c *gin.Context) {
	orders, err := h.svc.GetAllOrders()
	if err != nil {
		response.InternalServerError(c, "Gagal mengambil daftar pesanan: "+err.Error())
		return
	}
	response.Success(c, http.StatusOK, orders)
}

// ---------------- ISSUES HANDLER ----------------

func (h *Handler) ListIssues(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "10"))
	categoryID, _ := strconv.ParseUint(c.Query("category_id"), 10, 64)
	assignedToRaw := c.Query("assigned_to")
	var assignedTo uint64
	if assignedToRaw == "me" {
		claims := h.getClaims(c)
		if claims != nil {
			assignedTo = claims.UserID
		}
	} else if assignedToRaw != "" {
		assignedTo, _ = strconv.ParseUint(assignedToRaw, 10, 64)
	}

	var isArchived *bool
	if c.Query("is_archived") != "" {
		val := c.Query("is_archived") == "true"
		isArchived = &val
	}

	var isOverdue *bool
	if c.Query("is_overdue") != "" {
		val := c.Query("is_overdue") == "true"
		isOverdue = &val
	}

	var ids []uint64
	if idsParam := c.Query("ids"); idsParam != "" {
		for _, part := range strings.Split(idsParam, ",") {
			if id, err := strconv.ParseUint(strings.TrimSpace(part), 10, 64); err == nil && id > 0 {
				ids = append(ids, id)
			}
		}
	}

	filter := domain.IssueFilter{
		Search:     c.Query("search"),
		Status:     c.Query("status"),
		Prioritas:  c.Query("prioritas"),
		CategoryID: categoryID,
		AssignedTo: assignedTo,
		From:       c.Query("from"),
		To:         c.Query("to"),
		IsArchived: isArchived,
		IsOverdue:  isOverdue,
		IDs:        ids,
		Page:       page,
		Limit:      limit,
	}

	result, err := h.svc.ListIssues(filter)
	if err != nil {
		response.InternalServerError(c, "Gagal mengambil daftar kendala: "+err.Error())
		return
	}

	response.Success(c, http.StatusOK, result)
}

func (h *Handler) ShareText(c *gin.Context) {
	categoryID, _ := strconv.ParseUint(c.Query("category_id"), 10, 64)

	assignedToRaw := c.Query("assigned_to")
	var assignedTo uint64
	if assignedToRaw == "me" {
		claims := h.getClaims(c)
		if claims != nil {
			assignedTo = claims.UserID
		}
	} else if assignedToRaw != "" {
		assignedTo, _ = strconv.ParseUint(assignedToRaw, 10, 64)
	}

	var isArchived *bool
	if c.Query("is_archived") != "" {
		val := c.Query("is_archived") == "true"
		isArchived = &val
	}

	var isOverdue *bool
	if c.Query("is_overdue") != "" {
		val := c.Query("is_overdue") == "true"
		isOverdue = &val
	}

	var ids []uint64
	if idsParam := c.Query("ids"); idsParam != "" {
		for _, part := range strings.Split(idsParam, ",") {
			if id, err := strconv.ParseUint(strings.TrimSpace(part), 10, 64); err == nil && id > 0 {
				ids = append(ids, id)
			}
		}
	}

	includeCustomer := true
	if c.Query("include_customer") == "false" {
		includeCustomer = false
	}

	filter := domain.IssueFilter{
		Search:     c.Query("search"),
		Status:     c.Query("status"),
		Prioritas:  c.Query("prioritas"),
		CategoryID: categoryID,
		AssignedTo: assignedTo,
		From:       c.Query("from"),
		To:         c.Query("to"),
		IsArchived: isArchived,
		IsOverdue:  isOverdue,
		IDs:        ids,
	}

	result, err := h.svc.GenerateShareText(filter, includeCustomer)
	if err != nil {
		response.InternalServerError(c, "Gagal menghasilkan teks WhatsApp: "+err.Error())
		return
	}

	response.Success(c, http.StatusOK, result)
}

func (h *Handler) CreateIssue(c *gin.Context) {
	claims := h.getClaims(c)
	if claims == nil {
		response.Unauthorized(c, "Sesi tidak valid")
		return
	}

	var req domain.CreateIssueRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Form input kendala tidak valid: "+err.Error())
		return
	}

	issue, err := h.svc.CreateIssue(req, claims.UserID)
	if err != nil {
		response.UnprocessableEntity(c, "CREATE_ISSUE_FAILED", err.Error())
		return
	}

	response.Success(c, http.StatusCreated, issue)
}

func (h *Handler) GetIssueDetail(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "ID kendala tidak valid")
		return
	}

	issue, err := h.svc.GetIssueDetail(id)
	if err != nil {
		response.NotFound(c, err.Error())
		return
	}

	response.Success(c, http.StatusOK, issue)
}

func (h *Handler) UpdateIssue(c *gin.Context) {
	claims := h.getClaims(c)
	if claims == nil {
		response.Unauthorized(c, "Sesi tidak valid")
		return
	}

	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "ID kendala tidak valid")
		return
	}

	var req domain.UpdateIssueRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Data update kendala tidak valid: "+err.Error())
		return
	}

	issue, err := h.svc.UpdateIssue(id, req, claims.Role, claims.UserID)
	if err != nil {
		if errors.Is(err, domain.ErrForbidden) {
			response.Forbidden(c, err.Error())
			return
		}
		response.UnprocessableEntity(c, "UPDATE_ISSUE_FAILED", err.Error())
		return
	}

	response.Success(c, http.StatusOK, issue)
}

func (h *Handler) ArchiveIssue(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "ID kendala tidak valid")
		return
	}

	var req struct {
		IsArchived bool `json:"is_archived"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		req.IsArchived = true // default jika tidak dikirim
	}

	if err := h.svc.ArchiveIssue(id, req.IsArchived); err != nil {
		response.UnprocessableEntity(c, "ARCHIVE_FAILED", err.Error())
		return
	}

	msg := "Kendala berhasil diarsipkan"
	if !req.IsArchived {
		msg = "Kendala berhasil dikembalikan dari arsip"
	}
	response.Success(c, http.StatusOK, gin.H{"message": msg})
}

func (h *Handler) DeleteIssue(c *gin.Context) {
	claims := h.getClaims(c)
	if claims == nil {
		response.Unauthorized(c, "Sesi tidak valid")
		return
	}

	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "ID kendala tidak valid")
		return
	}

	if err := h.svc.DeleteIssue(id, claims.Role); err != nil {
		response.UnprocessableEntity(c, "DELETE_FAILED", err.Error())
		return
	}

	response.Success(c, http.StatusOK, gin.H{"message": "Kendala berhasil dihapus secara permanen"})
}

// ---------------- TRANSITIONS HANDLER ----------------

func (h *Handler) TransitionStatus(c *gin.Context) {
	claims := h.getClaims(c)
	if claims == nil {
		response.Unauthorized(c, "Sesi tidak valid")
		return
	}

	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "ID kendala tidak valid")
		return
	}

	var req domain.TransitionStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Input transisi status tidak valid: "+err.Error())
		return
	}

	issue, err := h.svc.TransitionStatus(id, req, claims.UserID, claims.Role)
	if err != nil {
		if errors.Is(err, domain.ErrForbidden) {
			response.Forbidden(c, err.Error())
			return
		}
		// Tolak dengan HTTP 422 jika aturan bisnis dilanggar
		response.UnprocessableEntity(c, "INVALID_STATUS_TRANSITION", err.Error())
		return
	}

	response.Success(c, http.StatusOK, issue)
}

func (h *Handler) GetIssueTransitions(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "ID kendala tidak valid")
		return
	}

	transitions, err := h.svc.GetIssueTransitions(id)
	if err != nil {
		response.NotFound(c, err.Error())
		return
	}

	response.Success(c, http.StatusOK, transitions)
}

// ---------------- FASE 6: COMMENTS & REASSIGN HANDLERS ----------------

func (h *Handler) GetComments(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "ID kendala tidak valid")
		return
	}

	comments, err := h.svc.GetComments(id)
	if err != nil {
		response.NotFound(c, err.Error())
		return
	}

	response.Success(c, http.StatusOK, comments)
}

func (h *Handler) CreateComment(c *gin.Context) {
	claims := h.getClaims(c)
	if claims == nil {
		response.Unauthorized(c, "Sesi tidak valid")
		return
	}

	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "ID kendala tidak valid")
		return
	}

	var req domain.CreateCommentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Isi komentar wajib diisi (maksimal 1000 karakter): "+err.Error())
		return
	}

	comment, err := h.svc.CreateComment(id, claims.UserID, req)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}

	response.Success(c, http.StatusCreated, comment)
}

func (h *Handler) ReassignIssue(c *gin.Context) {
	claims := h.getClaims(c)
	if claims == nil {
		response.Unauthorized(c, "Sesi tidak valid")
		return
	}

	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		response.BadRequest(c, "ID kendala tidak valid")
		return
	}

	var req domain.ReassignIssueRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, "Data penugasan tidak valid: "+err.Error())
		return
	}

	issue, err := h.svc.ReassignIssue(id, claims.UserID, req)
	if err != nil {
		response.UnprocessableEntity(c, "REASSIGN_FAILED", err.Error())
		return
	}

	response.Success(c, http.StatusOK, issue)
}

func (h *Handler) GetIssuesDueSoon(c *gin.Context) {
	hours, _ := strconv.Atoi(c.DefaultQuery("hours", "24"))
	issues, err := h.svc.GetIssuesDueSoon(hours)
	if err != nil {
		response.InternalServerError(c, "Gagal mengambil daftar kendala jatuh tempo: "+err.Error())
		return
	}

	response.Success(c, http.StatusOK, issues)
}

// ---------------- FASE 3: DASHBOARD, REPORT & ACTIVITY HANDLERS ----------------

func (h *Handler) GetDashboardSummary(c *gin.Context) {
	summary, err := h.svc.GetDashboardSummary()
	if err != nil {
		response.InternalServerError(c, err.Error())
		return
	}
	response.Success(c, http.StatusOK, summary)
}

func (h *Handler) GetDashboardByCategory(c *gin.Context) {
	stats, err := h.svc.GetCategoryStats()
	if err != nil {
		response.InternalServerError(c, err.Error())
		return
	}
	response.Success(c, http.StatusOK, stats)
}

func (h *Handler) GetDashboardTrend(c *gin.Context) {
	period := c.DefaultQuery("period", "7d")
	trend, err := h.svc.GetTrendData(period)
	if err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	response.Success(c, http.StatusOK, trend)
}

func (h *Handler) GetReportRecap(c *gin.Context) {
	from := c.Query("from")
	to := c.Query("to")

	recap, err := h.svc.GetReportRecap(from, to)
	if err != nil {
		response.InternalServerError(c, err.Error())
		return
	}
	response.Success(c, http.StatusOK, recap)
}

func (h *Handler) ExportReportCSV(c *gin.Context) {
	from := c.Query("from")
	to := c.Query("to")

	buf, err := h.svc.ExportReportCSV(from, to)
	if err != nil {
		response.InternalServerError(c, "Gagal membuat laporan CSV: "+err.Error())
		return
	}

	fileName := "laporan_kendala.csv"
	if from != "" && to != "" {
		fileName = "laporan_kendala_" + from + "_sd_" + to + ".csv"
	}

	c.Header("Content-Description", "File Transfer")
	c.Header("Content-Disposition", "attachment; filename="+fileName)
	c.Header("Content-Type", "text/csv; charset=utf-8")
	c.Data(http.StatusOK, "text/csv; charset=utf-8", buf.Bytes())
}

func (h *Handler) GetActivityLogs(c *gin.Context) {
	limitStr := c.DefaultQuery("limit", "20")
	limit, _ := strconv.Atoi(limitStr)

	logs, err := h.svc.GetActivityLogs(limit)
	if err != nil {
		response.InternalServerError(c, err.Error())
		return
	}
	response.Success(c, http.StatusOK, logs)
}

