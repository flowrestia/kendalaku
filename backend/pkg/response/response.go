package response

import (
	"net/http"

	"github.com/gin-gonic/gin"
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
