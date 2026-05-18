package handler

import (
	"log"
	"net/http"
	"strconv"

	"backend/internal/domain"
	grpcclient "backend/internal/grpc"
	"backend/internal/handler/dto"
	"backend/internal/service"

	"github.com/gin-gonic/gin"
)

type MessageHandler struct {
	messageService *service.MessageService
	searchClient   *grpcclient.SearchClient
}

func NewMessageHandler(
	messageService *service.MessageService,
	searchClient *grpcclient.SearchClient,
) *MessageHandler {
	return &MessageHandler{
		messageService: messageService,
		searchClient:   searchClient,
	}
}

func (h *MessageHandler) SendUserMessage(c *gin.Context) {
	conversationID := c.Param("id")

	var req dto.SendUserMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}

	userMessage, err := h.messageService.CreateUserMessage(c.Request.Context(), conversationID, req.Content)
	if err != nil {
		if err == domain.ErrConversationNotFound {
			c.JSON(http.StatusNotFound, ErrorResponse{Error: "conversation not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	searchResult, err := h.searchClient.Search(c.Request.Context(), req.Content, "", 8)

	var botContent string
	if err != nil {
		log.Printf("gRPC search error: %v", err)
	}
	if err != nil || searchResult == nil {
		botContent = "Não foi possível obter uma resposta no momento."
	} else {
		botContent = searchResult.Proto.Answer
	}

	botMessage, err := h.messageService.CreateBotMessage(c.Request.Context(), conversationID, botContent)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	resp := gin.H{
		"user_message": dto.ToMessageResponse(userMessage),
		"bot_message":  dto.ToMessageResponse(botMessage),
	}

	if searchResult != nil && len(searchResult.Proto.Results) > 0 {
		sources := make([]gin.H, 0, len(searchResult.Proto.Results))
		for _, r := range searchResult.Proto.Results {
			sources = append(sources, gin.H{
				"url":   r.Url,
				"score": r.Score,
			})
		}
		resp["sources"] = sources
	}

	c.JSON(http.StatusOK, resp)
}

func (h *MessageHandler) CreateMessage(c *gin.Context) {
	var req dto.CreateMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}
	message, err := h.messageService.CreateMessage(
		c.Request.Context(),
		req.ConversationID,
		req.Content,
		domain.MessageRole(req.Role),
	)
	if err != nil {
		if err == domain.ErrConversationNotFound {
			c.JSON(http.StatusNotFound, ErrorResponse{Error: "conversation not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	c.JSON(http.StatusCreated, dto.ToMessageResponse(message))
}

func (h *MessageHandler) GetMessage(c *gin.Context) {
	id := c.Param("id")
	message, err := h.messageService.GetMessageByID(c.Request.Context(), id)
	if err != nil {
		if err == domain.ErrMessageNotFound {
			c.JSON(http.StatusNotFound, ErrorResponse{Error: err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	c.JSON(http.StatusOK, dto.ToMessageResponse(message))
}

func (h *MessageHandler) GetConversationMessages(c *gin.Context) {
	conversationID := c.Param("id")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	messages, err := h.messageService.GetConversationMessages(c.Request.Context(), conversationID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	response := make([]dto.MessageResponse, 0, len(messages))
	for _, msg := range messages {
		response = append(response, dto.ToMessageResponse(msg))
	}
	c.JSON(http.StatusOK, response)
}

func (h *MessageHandler) DeleteMessage(c *gin.Context) {
	id := c.Param("id")
	if err := h.messageService.DeleteMessage(c.Request.Context(), id); err != nil {
		if err == domain.ErrMessageNotFound {
			c.JSON(http.StatusNotFound, ErrorResponse{Error: err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
}
