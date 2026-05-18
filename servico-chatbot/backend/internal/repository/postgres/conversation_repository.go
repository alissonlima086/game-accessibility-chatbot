package postgres

import (
	"context"
	"errors"

	"backend/internal/domain"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type conversationRepository struct {
	db *pgxpool.Pool
}

func NewConversationRepository(db *pgxpool.Pool) *conversationRepository {
	return &conversationRepository{db: db}
}

func (r *conversationRepository) Create(ctx context.Context, conversation *domain.Conversation) error {
	query := `
		INSERT INTO conversations (id, user_id, title, status, created_at, updated_at, is_active)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	_, err := r.db.Exec(ctx, query,
		conversation.ID,
		conversation.UserID,
		conversation.Title,
		conversation.Status,
		conversation.CreatedAt,
		conversation.UpdatedAt,
		conversation.IsActive,
	)
	return err
}

func (r *conversationRepository) GetByID(ctx context.Context, id string) (*domain.Conversation, error) {
	query := `
		SELECT id, user_id, title, status, created_at, updated_at, is_active
		FROM conversations
		WHERE id = $1 AND is_active = true
	`

	conversation := &domain.Conversation{}
	err := r.db.QueryRow(ctx, query, id).Scan(
		&conversation.ID,
		&conversation.UserID,
		&conversation.Title,
		&conversation.Status,
		&conversation.CreatedAt,
		&conversation.UpdatedAt,
		&conversation.IsActive,
	)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrConversationNotFound
		}
		return nil, err
	}

	return conversation, nil
}

func (r *conversationRepository) GetByUserID(ctx context.Context, userID string, limit, offset int) ([]*domain.Conversation, error) {
	query := `
		SELECT id, user_id, title, status, created_at, updated_at, is_active
		FROM conversations
		WHERE user_id = $1 AND is_active = true
		ORDER BY updated_at DESC
		LIMIT $2 OFFSET $3
	`

	rows, err := r.db.Query(ctx, query, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	conversations := make([]*domain.Conversation, 0)
	for rows.Next() {
		conversation := &domain.Conversation{}
		err := rows.Scan(
			&conversation.ID,
			&conversation.UserID,
			&conversation.Title,
			&conversation.Status,
			&conversation.CreatedAt,
			&conversation.UpdatedAt,
			&conversation.IsActive,
		)
		if err != nil {
			return nil, err
		}
		conversations = append(conversations, conversation)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	return conversations, nil
}

func (r *conversationRepository) Update(ctx context.Context, conversation *domain.Conversation) error {
	query := `
		UPDATE conversations
		SET title = $2, status = $3, updated_at = $4
		WHERE id = $1 AND is_active = true
	`

	result, err := r.db.Exec(ctx, query,
		conversation.ID,
		conversation.Title,
		conversation.Status,
		conversation.UpdatedAt,
	)

	if err != nil {
		return err
	}

	if result.RowsAffected() == 0 {
		return domain.ErrConversationNotFound
	}

	return nil
}

func (r *conversationRepository) Delete(ctx context.Context, id string) error {
	query := `
		UPDATE conversations
		SET is_active = false, updated_at = NOW()
		WHERE id = $1
	`

	result, err := r.db.Exec(ctx, query, id)
	if err != nil {
		return err
	}

	if result.RowsAffected() == 0 {
		return domain.ErrConversationNotFound
	}

	return nil
}

func (r *conversationRepository) UpdateStatus(ctx context.Context, id string, status domain.ConversationStatus) error {
	query := `
		UPDATE conversations
		SET status = $2, updated_at = NOW()
		WHERE id = $1 AND is_active = true
	`

	result, err := r.db.Exec(ctx, query, id, status)
	if err != nil {
		return err
	}

	if result.RowsAffected() == 0 {
		return domain.ErrConversationNotFound
	}

	return nil
}
