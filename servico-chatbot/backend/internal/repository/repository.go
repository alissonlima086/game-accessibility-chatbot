package repository

import (
	"context"

	"backend/internal/domain"
)

// UserRepository define as operações de persistência para User
type UserRepository interface {
	Create(ctx context.Context, user *domain.User) error
	GetByID(ctx context.Context, id string) (*domain.User, error)
	GetByEmail(ctx context.Context, email string) (*domain.User, error)
	Update(ctx context.Context, user *domain.User) error
	Delete(ctx context.Context, id string) error
	List(ctx context.Context, limit, offset int) ([]*domain.User, error)
	Search(ctx context.Context, q string, limit, offset int) ([]*domain.User, error)
}

// ConversationRepository define as operações de persistência para Conversation
type ConversationRepository interface {
	Create(ctx context.Context, conversation *domain.Conversation) error
	GetByID(ctx context.Context, id string) (*domain.Conversation, error)
	GetByUserID(ctx context.Context, userID string, limit, offset int) ([]*domain.Conversation, error)
	Update(ctx context.Context, conversation *domain.Conversation) error
	Delete(ctx context.Context, id string) error
	UpdateStatus(ctx context.Context, id string, status domain.ConversationStatus) error
}

// MessageRepository define as operações de persistência para Message
type MessageRepository interface {
	Create(ctx context.Context, message *domain.Message) error
	GetByID(ctx context.Context, id string) (*domain.Message, error)
	GetByConversationID(ctx context.Context, conversationID string, limit, offset int) ([]*domain.Message, error)
	Update(ctx context.Context, message *domain.Message) error
	Delete(ctx context.Context, id string) error
	CountByConversationID(ctx context.Context, conversationID string) (int, error)
}
