package dto

import (
	"backend/internal/domain"
	"backend/internal/tracing"
)

// User DTOs
type CreateUserRequest struct {
	Username string `json:"username" binding:"required"`
	Email    string `json:"email" binding:"required,email"`
	Role     string `json:"role" binding:"required,oneof=USER ADMIN"`
}

type UpdateUserRequest struct {
	Username string `json:"username" binding:"required"`
	Email    string `json:"email" binding:"required,email"`
	Role     string `json:"role" binding:"required,oneof=USER ADMIN"`
}

type UserResponse struct {
	ID        string `json:"id"`
	Username  string `json:"username"`
	Email     string `json:"email"`
	Role      string `json:"role"`
	CreatedAt string `json:"created_at"`
	UpdatedAt string `json:"updated_at"`
	IsActive  bool   `json:"is_active"`
}

// Conversation DTOs
type CreateConversationRequest struct {
	UserID string `json:"user_id" binding:"required"`
	Title  string `json:"title" binding:"required"`
}

type UpdateConversationRequest struct {
	Title  string `json:"title" binding:"required"`
	Status string `json:"status" binding:"required,oneof=OPEN CLOSED ARCHIVED"`
}

type ConversationResponse struct {
	ID        string            `json:"id"`
	UserID    string            `json:"user_id"`
	Title     string            `json:"title"`
	Status    string            `json:"status"`
	Messages  []MessageResponse `json:"messages,omitempty"`
	CreatedAt string            `json:"created_at"`
	UpdatedAt string            `json:"updated_at"`
}

// Message DTOs
type CreateMessageRequest struct {
	ConversationID string `json:"conversation_id" binding:"required"`
	Content        string `json:"content" binding:"required"`
	Role           string `json:"role" binding:"required,oneof=USER BOT"`
}

type SendUserMessageRequest struct {
	Content string `json:"content" binding:"required"`
}

type MessageResponse struct {
	ID             string                 `json:"id"`
	ConversationID string                 `json:"conversation_id"`
	ReplyToID      *string                `json:"reply_to_id,omitempty"`
	Content        string                 `json:"content"`
	Role           string                 `json:"role"`
	Timestamp      string                 `json:"timestamp"`
	CrawlerResult  *CrawlerResultResponse `json:"crawler_result,omitempty"`
	CreatedAt      string                 `json:"created_at"`
}

type CrawlerResultResponse struct {
	Summary     string `json:"summary"`
	SourceCount int    `json:"source_count"`
}

// Auth DTOs
type RegisterRequest struct {
	Username string `json:"username" binding:"required"`
	Email    string `json:"email"    binding:"required,email"`
	Password string `json:"password" binding:"required,min=8"`
}

type LoginRequest struct {
	Email    string `json:"email"    binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

type LoginResponse struct {
	Token string       `json:"token"`
	User  UserResponse `json:"user"`
}

// StartChatRequest - cria conversa + envia primeira mensagem
type StartChatRequest struct {
	UserID  string `json:"user_id" binding:"required"`
	Content string `json:"content" binding:"required"`
}

// SourceResponse - fonte retornada pelo crawler
type SourceResponse struct {
	URL   string  `json:"url"`
	Score float64 `json:"score"`
}

// ChatResponse - resposta unificada do chat (inclui métricas distribuídas)
type ChatResponse struct {
	Conversation ConversationResponse `json:"conversation"`
	UserMessage  MessageResponse      `json:"user_message"`
	BotMessage   MessageResponse      `json:"bot_message"`
	Sources      []SourceResponse     `json:"sources,omitempty"`
	Metrics      *tracing.GoMetrics   `json:"metrics,omitempty"`
}

// Helper functions to convert domain to DTO
func ToUserResponse(user *domain.User) UserResponse {
	return UserResponse{
		ID:        user.ID,
		Username:  user.Username,
		Email:     user.Email,
		Role:      string(user.Role),
		CreatedAt: user.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
		UpdatedAt: user.UpdatedAt.Format("2006-01-02T15:04:05Z07:00"),
		IsActive:  user.IsActive,
	}
}

func ToConversationResponse(conv *domain.Conversation) ConversationResponse {
	messages := make([]MessageResponse, 0, len(conv.Messages))
	for _, msg := range conv.Messages {
		messages = append(messages, ToMessageResponse(msg))
	}
	return ConversationResponse{
		ID:        conv.ID,
		UserID:    conv.UserID,
		Title:     conv.Title,
		Status:    string(conv.Status),
		Messages:  messages,
		CreatedAt: conv.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
		UpdatedAt: conv.UpdatedAt.Format("2006-01-02T15:04:05Z07:00"),
	}
}

func ToMessageResponse(msg *domain.Message) MessageResponse {
	resp := MessageResponse{
		ID:             msg.ID,
		ConversationID: msg.ConversationID,
		ReplyToID:      msg.ReplyToID,
		Content:        msg.Content,
		Role:           string(msg.Role),
		Timestamp:      msg.Timestamp.Format("2006-01-02T15:04:05Z07:00"),
		CreatedAt:      msg.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
	}
	if msg.CrawlerResult != nil {
		resp.CrawlerResult = &CrawlerResultResponse{
			Summary:     msg.CrawlerResult.Summary,
			SourceCount: msg.CrawlerResult.SourceCount,
		}
	}
	return resp
}
