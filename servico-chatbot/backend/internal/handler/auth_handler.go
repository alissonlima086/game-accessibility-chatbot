package handler

import (
	"net/http"

	"backend/internal/domain"
	"backend/internal/handler/dto"
	"backend/internal/service"

	"github.com/gin-gonic/gin"
)

type AuthHandler struct {
	authService *service.AuthService
}

func NewAuthHandler(authService *service.AuthService) *AuthHandler {
	return &AuthHandler{authService: authService}
}

// Register godoc
// @Summary Registrar novo usuário
// @Tags auth
// @Accept json
// @Produce json
// @Param user body dto.RegisterRequest true "Dados do usuário"
// @Success 201 {object} dto.UserResponse
// @Failure 400 {object} ErrorResponse
// @Failure 409 {object} ErrorResponse
// @Router /auth/register [post]
func (h *AuthHandler) Register(c *gin.Context) {
	var req dto.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	user, err := h.authService.Register(
		c.Request.Context(),
		req.Username,
		req.Email,
		req.Password,
		domain.UserRoleUser,
	)
	if err != nil {
		if err == domain.ErrUserAlreadyExists {
			c.JSON(http.StatusConflict, ErrorResponse{Error: err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusCreated, dto.ToUserResponse(user))
}

// Login godoc
// @Summary Login do usuário
// @Tags auth
// @Accept json
// @Produce json
// @Param credentials body dto.LoginRequest true "Credenciais"
// @Success 200 {object} dto.LoginResponse
// @Failure 401 {object} ErrorResponse
// @Router /auth/login [post]
func (h *AuthHandler) Login(c *gin.Context) {
	var req dto.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	token, user, err := h.authService.Login(c.Request.Context(), req.Email, req.Password)
	if err != nil {
		if err == domain.ErrInvalidCredentials {
			c.JSON(http.StatusUnauthorized, ErrorResponse{Error: err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, dto.LoginResponse{
		Token: token,
		User:  dto.ToUserResponse(user),
	})
}

// Me godoc
// @Summary Retorna o usuário autenticado
// @Tags auth
// @Security BearerAuth
// @Produce json
// @Success 200
// @Failure 401 {object} ErrorResponse
// @Router /auth/me [get]
func (h *AuthHandler) Me(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"user_id": c.GetString("userID"),
		"email":   c.GetString("userEmail"),
		"role":    c.GetString("userRole"),
	})
}