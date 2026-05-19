package service

import (
	"context"

	"backend/internal/domain"
	"backend/internal/repository"
)

type MessageService struct {
	messageRepo      repository.MessageRepository
	conversationRepo repository.ConversationRepository
}

func NewMessageService(
	messageRepo repository.MessageRepository,
	conversationRepo repository.ConversationRepository,
) *MessageService {
	return &MessageService{
		messageRepo:      messageRepo,
		conversationRepo: conversationRepo,
	}
}

func (s *MessageService) CreateMessage(ctx context.Context, conversationID, content string, role domain.MessageRole) (*domain.Message, error) {
	message := domain.NewMessage(conversationID, content, role)
	if err := message.Validate(); err != nil {
		return nil, err
	}
	if err := s.messageRepo.Create(ctx, message); err != nil {
		return nil, err
	}
	return message, nil
}

func (s *MessageService) CreateUserMessage(ctx context.Context, conversationID, content string) (*domain.Message, error) {
	return s.CreateMessage(ctx, conversationID, content, domain.MessageRoleUser)
}

func (s *MessageService) CreateBotMessage(ctx context.Context, conversationID, content string) (*domain.Message, error) {
	return s.CreateMessage(ctx, conversationID, content, domain.MessageRoleBot)
}

// CreateBotMessageWithSources persiste a mensagem do bot já com as sources do RAG.
// Isso resolve o problema #1: ao reabrir a conversa, as fontes são carregadas do banco.
func (s *MessageService) CreateBotMessageWithSources(ctx context.Context, conversationID, content string, sources []domain.Source) (*domain.Message, error) {
	message := domain.NewBotMessage(conversationID, content)
	if err := message.Validate(); err != nil {
		return nil, err
	}
	if len(sources) > 0 {
		message.CrawlerResult = &domain.CrawlerResult{
			SourceCount: len(sources),
			Sources:     sources,
		}
	}
	if err := s.messageRepo.Create(ctx, message); err != nil {
		return nil, err
	}
	return message, nil
}

func (s *MessageService) CreateBotMessageWithCrawlerResult(ctx context.Context, conversationID, content string, crawlerResult *domain.CrawlerResult) (*domain.Message, error) {
	message, err := s.CreateBotMessage(ctx, conversationID, content)
	if err != nil {
		return nil, err
	}
	message.AttachCrawlerResult(crawlerResult)
	if err := s.messageRepo.Update(ctx, message); err != nil {
		return nil, err
	}
	return message, nil
}

func (s *MessageService) GetMessageByID(ctx context.Context, id string) (*domain.Message, error) {
	return s.messageRepo.GetByID(ctx, id)
}

func (s *MessageService) GetConversationMessages(ctx context.Context, conversationID string, limit, offset int) ([]*domain.Message, error) {
	if limit <= 0 {
		limit = 50
	}
	if offset < 0 {
		offset = 0
	}
	return s.messageRepo.GetByConversationID(ctx, conversationID, limit, offset)
}

func (s *MessageService) UpdateMessage(ctx context.Context, message *domain.Message) error {
	if err := message.Validate(); err != nil {
		return err
	}
	message.UpdateTimestamp()
	return s.messageRepo.Update(ctx, message)
}

func (s *MessageService) DeleteMessage(ctx context.Context, id string) error {
	return s.messageRepo.Delete(ctx, id)
}

func (s *MessageService) CountConversationMessages(ctx context.Context, conversationID string) (int, error) {
	return s.messageRepo.CountByConversationID(ctx, conversationID)
}
