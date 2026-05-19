package handler

import (
	"net/http"
	"strconv"

	"backend/internal/domain"
	"backend/internal/handler/dto"
	"backend/internal/service"

	"github.com/gin-gonic/gin"
)

type UserHandler struct {
	userService *service.UserService
	authService *service.AuthService
}

func NewUserHandler(userService *service.UserService, authService *service.AuthService) *UserHandler {
	return &UserHandler{userService: userService, authService: authService}
}

func (h *UserHandler) CreateUser(c *gin.Context) {
	var req dto.CreateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}
	user, err := h.userService.CreateUser(c.Request.Context(), req.Username, req.Email, domain.UserRole(req.Role))
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

func (h *UserHandler) GetUser(c *gin.Context) {
	id := c.Param("id")
	user, err := h.userService.GetUserByID(c.Request.Context(), id)
	if err != nil {
		if err == domain.ErrUserNotFound {
			c.JSON(http.StatusNotFound, ErrorResponse{Error: err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	c.JSON(http.StatusOK, dto.ToUserResponse(user))
}

func (h *UserHandler) UpdateUser(c *gin.Context) {
	id := c.Param("id")
	var req dto.UpdateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}
	user, err := h.userService.GetUserByID(c.Request.Context(), id)
	if err != nil {
		if err == domain.ErrUserNotFound {
			c.JSON(http.StatusNotFound, ErrorResponse{Error: err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	user.Username = req.Username
	user.Email = req.Email
	user.Role = domain.UserRole(req.Role)
	if err := h.userService.UpdateUser(c.Request.Context(), user); err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	c.JSON(http.StatusOK, dto.ToUserResponse(user))
}

func (h *UserHandler) DeleteUser(c *gin.Context) {
	id := c.Param("id")
	if err := h.userService.DeleteUser(c.Request.Context(), id); err != nil {
		if err == domain.ErrUserNotFound {
			c.JSON(http.StatusNotFound, ErrorResponse{Error: err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *UserHandler) ListUsers(c *gin.Context) {
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "10"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))
	search := c.Query("search")

	var users []*domain.User
	var err error
	if search != "" {
		users, err = h.userService.SearchUsers(c.Request.Context(), search, limit, offset)
	} else {
		users, err = h.userService.ListUsers(c.Request.Context(), limit, offset)
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	response := make([]dto.UserResponse, 0, len(users))
	for _, user := range users {
		response = append(response, dto.ToUserResponse(user))
	}
	c.JSON(http.StatusOK, response)
}

// ── Perfil do usuário autenticado ─────────────────────────────────────────────

// GetProfile retorna os dados do usuário logado.
func (h *UserHandler) GetProfile(c *gin.Context) {
	userID := c.GetString("userID")
	user, err := h.userService.GetUserByID(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusNotFound, ErrorResponse{Error: "usuário não encontrado"})
		return
	}
	c.JSON(http.StatusOK, dto.ToUserResponse(user))
}

// UpdateProfile atualiza nome e e-mail do usuário logado.
func (h *UserHandler) UpdateProfile(c *gin.Context) {
	userID := c.GetString("userID")
	var req dto.UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}
	user, err := h.userService.GetUserByID(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusNotFound, ErrorResponse{Error: "usuário não encontrado"})
		return
	}
	user.Username = req.Username
	user.Email = req.Email
	if err := h.userService.UpdateUser(c.Request.Context(), user); err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	c.JSON(http.StatusOK, dto.ToUserResponse(user))
}

// ChangePassword troca a senha do usuário logado após validar a senha atual.
func (h *UserHandler) ChangePassword(c *gin.Context) {
	userID := c.GetString("userID")
	var req dto.ChangePasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}
	if err := h.userService.ChangePassword(c.Request.Context(), userID, req.CurrentPassword, req.NewPassword); err != nil {
		if err == domain.ErrInvalidCredentials {
			c.JSON(http.StatusUnauthorized, ErrorResponse{Error: "senha atual incorreta"})
			return
		}
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "senha alterada com sucesso"})
}

// DeleteProfile deleta a conta do usuário logado.
func (h *UserHandler) DeleteProfile(c *gin.Context) {
	userID := c.GetString("userID")
	if err := h.userService.DeleteUser(c.Request.Context(), userID); err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
}
