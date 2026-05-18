package middleware

import (
	"net/http"
	"strings"

	"backend/internal/handler"
	"backend/internal/service"

	"github.com/gin-gonic/gin"
)

func AuthMiddleware(authService *service.AuthService) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, handler.ErrorResponse{Error: "authorization header obrigatório"})
			c.Abort()
			return
		}

		// Remove espaços extras e trata tanto "Bearer <token>" quanto só "<token>"
		authHeader = strings.TrimSpace(authHeader)

		var tokenString string
		if strings.HasPrefix(authHeader, "Bearer ") {
			tokenString = strings.TrimPrefix(authHeader, "Bearer ")
		} else if strings.HasPrefix(authHeader, "bearer ") {
			tokenString = strings.TrimPrefix(authHeader, "bearer ")
		} else {
			// Assume que é o token direto, sem prefixo
			tokenString = authHeader
		}

		tokenString = strings.TrimSpace(tokenString)
		if tokenString == "" {
			c.JSON(http.StatusUnauthorized, handler.ErrorResponse{Error: "token não informado"})
			c.Abort()
			return
		}

		claims, err := authService.ValidateToken(tokenString)
		if err != nil {
			c.JSON(http.StatusUnauthorized, handler.ErrorResponse{Error: "token inválido ou expirado"})
			c.Abort()
			return
		}

		c.Set("userID", claims.UserID)
		c.Set("userEmail", claims.Email)
		c.Set("userRole", string(claims.Role))

		c.Next()
	}
}

func AdminOnly() gin.HandlerFunc {
	return func(c *gin.Context) {
		role := c.GetString("userRole")
		if role != "ADMIN" {
			c.JSON(http.StatusForbidden, handler.ErrorResponse{Error: "acesso restrito a administradores"})
			c.Abort()
			return
		}
		c.Next()
	}
}