package handler

import (
	"net/http"
	"strconv"

	"backend/internal/domain"
	"backend/internal/handler/dto"
	"backend/internal/service"

	"github.com/gin-gonic/gin"
)

type ConversationHandler struct {
	conversationService *service.ConversationService
}

func NewConversationHandler(conversationService *service.ConversationService) *ConversationHandler {
	return &ConversationHandler{conversationService: conversationService}
}

// CreateConversation godoc
// @Summary Create a new conversation
// @Tags conversations
// @Accept json
// @Produce json
// @Param conversation body dto.CreateConversationRequest true "Conversation data"
// @Success 201 {object} dto.ConversationResponse
// @Failure 400 {object} ErrorResponse
// @Router /conversations [post]
func (h *ConversationHandler) CreateConversation(c *gin.Context) {
	var req dto.CreateConversationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	conversation, err := h.conversationService.CreateConversation(c.Request.Context(), req.UserID, req.Title)
	if err != nil {
		if err == domain.ErrUserNotFound {
			c.JSON(http.StatusNotFound, ErrorResponse{Error: "user not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusCreated, dto.ToConversationResponse(conversation))
}

// GetConversation godoc
// @Summary Get conversation by ID
// @Tags conversations
// @Produce json
// @Param id path string true "Conversation ID"
// @Param with_messages query bool false "Include messages"
// @Param message_limit query int false "Message limit"
// @Success 200 {object} dto.ConversationResponse
// @Failure 404 {object} ErrorResponse
// @Router /conversations/{id} [get]
func (h *ConversationHandler) GetConversation(c *gin.Context) {
	id := c.Param("id")
	withMessages := c.Query("with_messages") == "true"
	messageLimit, _ := strconv.Atoi(c.DefaultQuery("message_limit", "50"))

	var conversation *domain.Conversation
	var err error

	if withMessages {
		conversation, err = h.conversationService.GetConversationWithMessages(c.Request.Context(), id, messageLimit)
	} else {
		conversation, err = h.conversationService.GetConversationByID(c.Request.Context(), id)
	}

	if err != nil {
		if err == domain.ErrConversationNotFound {
			c.JSON(http.StatusNotFound, ErrorResponse{Error: err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, dto.ToConversationResponse(conversation))
}

// GetUserConversations godoc
// @Summary Get user conversations
// @Tags conversations
// @Produce json
// @Param user_id path string true "User ID"
// @Param limit query int false "Limit"
// @Param offset query int false "Offset"
// @Success 200 {array} dto.ConversationResponse
// @Router /users/{user_id}/conversations [get]
func (h *ConversationHandler) GetUserConversations(c *gin.Context) {
	userID := c.Param("id")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	conversations, err := h.conversationService.GetUserConversations(c.Request.Context(), userID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	response := make([]dto.ConversationResponse, 0, len(conversations))
	for _, conv := range conversations {
		response = append(response, dto.ToConversationResponse(conv))
	}

	c.JSON(http.StatusOK, response)
}

// UpdateConversation godoc
// @Summary Update conversation
// @Tags conversations
// @Accept json
// @Produce json
// @Param id path string true "Conversation ID"
// @Param conversation body dto.UpdateConversationRequest true "Conversation data"
// @Success 200 {object} dto.ConversationResponse
// @Failure 400 {object} ErrorResponse
// @Router /conversations/{id} [put]
func (h *ConversationHandler) UpdateConversation(c *gin.Context) {
	id := c.Param("id")

	var req dto.UpdateConversationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	conversation, err := h.conversationService.GetConversationByID(c.Request.Context(), id)
	if err != nil {
		if err == domain.ErrConversationNotFound {
			c.JSON(http.StatusNotFound, ErrorResponse{Error: err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	conversation.Title = req.Title
	conversation.Status = domain.ConversationStatus(req.Status)

	if err := h.conversationService.UpdateConversation(c.Request.Context(), conversation); err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.JSON(http.StatusOK, dto.ToConversationResponse(conversation))
}

// CloseConversation godoc
// @Summary Close conversation
// @Tags conversations
// @Param id path string true "Conversation ID"
// @Success 204
// @Router /conversations/{id}/close [post]
func (h *ConversationHandler) CloseConversation(c *gin.Context) {
	id := c.Param("id")

	if err := h.conversationService.CloseConversation(c.Request.Context(), id); err != nil {
		if err == domain.ErrConversationNotFound {
			c.JSON(http.StatusNotFound, ErrorResponse{Error: err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.Status(http.StatusNoContent)
}

// ArchiveConversation godoc
// @Summary Archive conversation
// @Tags conversations
// @Param id path string true "Conversation ID"
// @Success 204
// @Router /conversations/{id}/archive [post]
func (h *ConversationHandler) ArchiveConversation(c *gin.Context) {
	id := c.Param("id")

	if err := h.conversationService.ArchiveConversation(c.Request.Context(), id); err != nil {
		if err == domain.ErrConversationNotFound {
			c.JSON(http.StatusNotFound, ErrorResponse{Error: err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.Status(http.StatusNoContent)
}

// DeleteConversation godoc
// @Summary Delete conversation
// @Tags conversations
// @Param id path string true "Conversation ID"
// @Success 204
// @Router /conversations/{id} [delete]
func (h *ConversationHandler) DeleteConversation(c *gin.Context) {
	id := c.Param("id")

	if err := h.conversationService.DeleteConversation(c.Request.Context(), id); err != nil {
		if err == domain.ErrConversationNotFound {
			c.JSON(http.StatusNotFound, ErrorResponse{Error: err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	c.Status(http.StatusNoContent)
}
