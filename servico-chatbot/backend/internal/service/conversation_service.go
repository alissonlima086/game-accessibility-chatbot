package service

import (
	"context"

	"backend/internal/domain"
	"backend/internal/repository"
)

type ConversationService struct {
	conversationRepo repository.ConversationRepository
	messageRepo      repository.MessageRepository
	userRepo         repository.UserRepository
}

func NewConversationService(
	conversationRepo repository.ConversationRepository,
	messageRepo repository.MessageRepository,
	userRepo repository.UserRepository,
) *ConversationService {
	return &ConversationService{
		conversationRepo: conversationRepo,
		messageRepo:      messageRepo,
		userRepo:         userRepo,
	}
}

func (s *ConversationService) CreateConversation(ctx context.Context, userID, title string) (*domain.Conversation, error) {
	// Verificar se o usuário existe
	_, err := s.userRepo.GetByID(ctx, userID)
	if err != nil {
		return nil, err
	}

	conversation := domain.NewConversation(userID, title)

	if err := conversation.Validate(); err != nil {
		return nil, err
	}

	if err := s.conversationRepo.Create(ctx, conversation); err != nil {
		return nil, err
	}

	return conversation, nil
}

func (s *ConversationService) GetConversationByID(ctx context.Context, id string) (*domain.Conversation, error) {
	return s.conversationRepo.GetByID(ctx, id)
}

func (s *ConversationService) GetConversationWithMessages(ctx context.Context, id string, messageLimit int) (*domain.Conversation, error) {
	conversation, err := s.conversationRepo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}

	if messageLimit <= 0 {
		messageLimit = 50
	}

	messages, err := s.messageRepo.GetByConversationID(ctx, id, messageLimit, 0)
	if err != nil {
		return nil, err
	}

	conversation.Messages = messages
	return conversation, nil
}

func (s *ConversationService) GetUserConversations(ctx context.Context, userID string, limit, offset int) ([]*domain.Conversation, error) {
	if limit <= 0 {
		limit = 20
	}
	if offset < 0 {
		offset = 0
	}
	return s.conversationRepo.GetByUserID(ctx, userID, limit, offset)
}

func (s *ConversationService) UpdateConversation(ctx context.Context, conversation *domain.Conversation) error {
	if err := conversation.Validate(); err != nil {
		return err
	}

	conversation.UpdateTimestamp()
	return s.conversationRepo.Update(ctx, conversation)
}

func (s *ConversationService) CloseConversation(ctx context.Context, id string) error {
	conversation, err := s.conversationRepo.GetByID(ctx, id)
	if err != nil {
		return err
	}

	conversation.Close()
	return s.conversationRepo.Update(ctx, conversation)
}

func (s *ConversationService) ArchiveConversation(ctx context.Context, id string) error {
	conversation, err := s.conversationRepo.GetByID(ctx, id)
	if err != nil {
		return err
	}

	conversation.Archive()
	return s.conversationRepo.Update(ctx, conversation)
}

func (s *ConversationService) ReopenConversation(ctx context.Context, id string) error {
	conversation, err := s.conversationRepo.GetByID(ctx, id)
	if err != nil {
		return err
	}

	conversation.Reopen()
	return s.conversationRepo.Update(ctx, conversation)
}

func (s *ConversationService) DeleteConversation(ctx context.Context, id string) error {
	return s.conversationRepo.Delete(ctx, id)
}
