package response

import (
	"errors"
	"fmt"
	"log"
	"net/http"
	"runtime/debug"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/go-playground/validator/v10"
)

type ErrorDetail struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

type APIResponse struct {
	Success bool         `json:"success"`
	Data    interface{}  `json:"data"`
	Error   *ErrorDetail `json:"error"`
}

func JSON(c *gin.Context, statusCode int, success bool, data interface{}, errDetail *ErrorDetail) {
	c.JSON(statusCode, APIResponse{
		Success: success,
		Data:    data,
		Error:   errDetail,
	})
}

func Success(c *gin.Context, statusCode int, data interface{}) {
	JSON(c, statusCode, true, data, nil)
}

func Error(c *gin.Context, statusCode int, code, message string) {
	JSON(c, statusCode, false, nil, &ErrorDetail{
		Code:    code,
		Message: message,
	})
}

func BadRequest(c *gin.Context, message string) {
	Error(c, http.StatusBadRequest, "BAD_REQUEST", message)
}

func Unauthorized(c *gin.Context, message string) {
	Error(c, http.StatusUnauthorized, "UNAUTHORIZED", message)
}

func Forbidden(c *gin.Context, message string) {
	Error(c, http.StatusForbidden, "FORBIDDEN", message)
}

func NotFound(c *gin.Context, message string) {
	Error(c, http.StatusNotFound, "NOT_FOUND", message)
}

func UnprocessableEntity(c *gin.Context, code, message string) {
	Error(c, http.StatusUnprocessableEntity, code, message)
}

func InternalServerError(c *gin.Context, message string) {
	Error(c, http.StatusInternalServerError, "INTERNAL_SERVER_ERROR", message)
}

// CustomRecovery menangkap panic tak terduga dan mengembalikan respons JSON 500 standar tanpa stack trace
func CustomRecovery() gin.HandlerFunc {
	return gin.CustomRecovery(func(c *gin.Context, recovered interface{}) {
		log.Printf("[PANIC RECOVERED] %v\n%s", recovered, debug.Stack())
		c.AbortWithStatusJSON(http.StatusInternalServerError, APIResponse{
			Success: false,
			Data:    nil,
			Error: &ErrorDetail{
				Code:    "INTERNAL_ERROR",
				Message: "Terjadi kesalahan pada server",
			},
		})
	})
}

// FormatValidationError mengubah error validasi binding menjadi pesan ramah berbahasa Indonesia
func FormatValidationError(err error) string {
	if err == nil {
		return "Data yang dikirim tidak valid"
	}

	var valErrs validator.ValidationErrors
	if errors.As(err, &valErrs) && len(valErrs) > 0 {
		fe := valErrs[0]
		field := fe.Field()
		tag := fe.Tag()
		param := fe.Param()

		switch field {
		case "PasswordBaru":
			if tag == "min" {
				return fmt.Sprintf("Kata sandi baru minimal %s karakter", param)
			}
			return "Kata sandi baru wajib diisi"
		case "PasswordLama":
			return "Kata sandi lama wajib diisi"
		case "Email":
			if tag == "email" {
				return "Format email tidak valid"
			}
			return "Email wajib diisi"
		case "Password":
			if tag == "min" {
				return fmt.Sprintf("Kata sandi minimal %s karakter", param)
			}
			return "Kata sandi wajib diisi"
		case "Nama":
			if tag == "max" {
				return fmt.Sprintf("Nama kategori maksimal %s karakter", param)
			}
			return "Nama kategori wajib diisi"
		case "WarnaHex":
			if tag == "max" {
				return "Kode warna maksimal 7 karakter"
			}
			return "Kode warna wajib diisi"
		case "Ikon":
			if tag == "max" {
				return "Nama ikon maksimal 50 karakter"
			}
			return "Ikon kategori wajib diisi"
		case "TenggatJam":
			return "Tenggat waktu jam minimal 1 jam"
		case "OrderID":
			return "Pesanan wajib dipilih"
		case "CategoryID":
			return "Kategori kendala wajib dipilih"
		case "Judul":
			if tag == "max" {
				return fmt.Sprintf("Judul kendala maksimal %s karakter", param)
			}
			return "Judul kendala wajib diisi"
		case "Deskripsi":
			return "Deskripsi kendala wajib diisi"
		case "Prioritas":
			return "Prioritas harus salah satu dari: rendah, sedang, tinggi, kritis"
		case "StatusBaru":
			return "Status baru harus salah satu dari: sedang_diproses, menunggu_informasi, selesai, ditolak"
		case "CatatanTindakan":
			return "Catatan tindakan wajib diisi"
		case "Isi":
			if tag == "max" {
				return fmt.Sprintf("Isi komentar maksimal %s karakter", param)
			}
			return "Isi komentar wajib diisi"
		case "AssignedTo":
			return "Petugas penanganan wajib dipilih"
		default:
			switch tag {
			case "required":
				return fmt.Sprintf("%s wajib diisi", field)
			case "min":
				return fmt.Sprintf("%s minimal %s karakter", field, param)
			case "max":
				return fmt.Sprintf("%s maksimal %s karakter", field, param)
			case "email":
				return fmt.Sprintf("Format %s tidak valid", strings.ToLower(field))
			case "oneof":
				return fmt.Sprintf("%s tidak valid (pilihan: %s)", field, strings.ReplaceAll(param, " ", ", "))
			default:
				return fmt.Sprintf("Data %s tidak valid", field)
			}
		}
	}

	return "Format data permintaan tidak valid"
}
