package middleware

import (
	"net/http"
	"strings"

	"github.com/flowrestia/kendalaku/backend/pkg/jwt"
	"github.com/flowrestia/kendalaku/backend/pkg/response"
	"github.com/gin-gonic/gin"
)

const (
	AuthorizationHeaderKey  = "authorization"
	AuthorizationTypeBearer = "bearer"
	AuthorizationPayloadKey = "authorization_payload"
)

func AuthMiddleware(tokenMaker *jwt.TokenMaker) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader(AuthorizationHeaderKey)
		if len(authHeader) == 0 {
			response.Error(c, http.StatusUnauthorized, "UNAUTHORIZED", "Header otorisasi tidak ditemukan")
			c.Abort()
			return
		}

		fields := strings.Fields(authHeader)
		if len(fields) < 2 {
			response.Error(c, http.StatusUnauthorized, "UNAUTHORIZED", "Format header token tidak valid")
			c.Abort()
			return
		}

		authType := strings.ToLower(fields[0])
		if authType != AuthorizationTypeBearer {
			response.Error(c, http.StatusUnauthorized, "UNAUTHORIZED", "Tipe otorisasi tidak didukung")
			c.Abort()
			return
		}

		accessToken := fields[1]
		claims, err := tokenMaker.ValidateToken(accessToken)
		if err != nil {
			response.Error(c, http.StatusUnauthorized, "UNAUTHORIZED", "Token akses tidak sah atau telah kedaluwarsa")
			c.Abort()
			return
		}

		c.Set(AuthorizationPayloadKey, claims)
		c.Next()
	}
}

func RequireRole(roles ...string) gin.HandlerFunc {
	return func(c *gin.Context) {
		payloadVal, exists := c.Get(AuthorizationPayloadKey)
		if !exists {
			response.Error(c, http.StatusUnauthorized, "UNAUTHORIZED", "Payload sesi pengguna tidak ditemukan")
			c.Abort()
			return
		}

		claims, ok := payloadVal.(*jwt.Claims)
		if !ok {
			response.Error(c, http.StatusUnauthorized, "UNAUTHORIZED", "Format payload sesi tidak valid")
			c.Abort()
			return
		}

		for _, r := range roles {
			if claims.Role == r {
				c.Next()
				return
			}
		}

		response.Error(c, http.StatusForbidden, "FORBIDDEN", "Anda tidak memiliki hak akses untuk aksi ini")
		c.Abort()
	}
}

func CORSMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, PATCH, DELETE")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}
