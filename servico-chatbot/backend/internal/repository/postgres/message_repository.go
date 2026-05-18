package postgres

import (
	"context"
	"encoding/json"
	"errors"

	"backend/internal/domain"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type messageRepository struct {
	db *pgxpool.Pool
}

func NewMessageRepository(db *pgxpool.Pool) *messageRepository {
	return &messageRepository{db: db}
}

func (r *messageRepository) Create(ctx context.Context, message *domain.Message) error {
	var crawlerResultJSON []byte
	var err error

	if message.CrawlerResult != nil {
		crawlerResultJSON, err = json.Marshal(message.CrawlerResult)
		if err != nil {
			return err
		}
	}

	query := `
		INSERT INTO messages (id, conversation_id, reply_to_id, content, role, timestamp, crawler_result, created_at, is_active)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`
	_, err = r.db.Exec(ctx, query,
		message.ID,
		message.ConversationID,
		message.ReplyToID,
		message.Content,
		message.Role,
		message.Timestamp,
		crawlerResultJSON,
		message.CreatedAt,
		message.IsActive,
	)
	return err
}

func (r *messageRepository) GetByID(ctx context.Context, id string) (*domain.Message, error) {
	query := `
		SELECT id, conversation_id, reply_to_id, content, role, timestamp, crawler_result, created_at, is_active
		FROM messages
		WHERE id = $1 AND is_active = true
	`

	message := &domain.Message{}
	var crawlerResultJSON []byte

	err := r.db.QueryRow(ctx, query, id).Scan(
		&message.ID,
		&message.ConversationID,
		&message.ReplyToID,
		&message.Content,
		&message.Role,
		&message.Timestamp,
		&crawlerResultJSON,
		&message.CreatedAt,
		&message.IsActive,
	)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrMessageNotFound
		}
		return nil, err
	}

	if len(crawlerResultJSON) > 0 {
		if err := json.Unmarshal(crawlerResultJSON, &message.CrawlerResult); err != nil {
			return nil, err
		}
	}

	return message, nil
}

func (r *messageRepository) GetByConversationID(ctx context.Context, conversationID string, limit, offset int) ([]*domain.Message, error) {
	query := `
		SELECT id, conversation_id, reply_to_id, content, role, timestamp, crawler_result, created_at, is_active
		FROM messages
		WHERE conversation_id = $1 AND is_active = true
		ORDER BY timestamp ASC
		LIMIT $2 OFFSET $3
	`

	rows, err := r.db.Query(ctx, query, conversationID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	messages := make([]*domain.Message, 0)
	for rows.Next() {
		message := &domain.Message{}
		var crawlerResultJSON []byte

		err := rows.Scan(
			&message.ID,
			&message.ConversationID,
			&message.ReplyToID,
			&message.Content,
			&message.Role,
			&message.Timestamp,
			&crawlerResultJSON,
			&message.CreatedAt,
			&message.IsActive,
		)
		if err != nil {
			return nil, err
		}

		if len(crawlerResultJSON) > 0 {
			if err := json.Unmarshal(crawlerResultJSON, &message.CrawlerResult); err != nil {
				return nil, err
			}
		}

		messages = append(messages, message)
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	return messages, nil
}

func (r *messageRepository) Update(ctx context.Context, message *domain.Message) error {
	var crawlerResultJSON []byte
	var err error

	if message.CrawlerResult != nil {
		crawlerResultJSON, err = json.Marshal(message.CrawlerResult)
		if err != nil {
			return err
		}
	}

	query := `
		UPDATE messages
		SET content = $2, crawler_result = $3
		WHERE id = $1 AND is_active = true
	`

	result, err := r.db.Exec(ctx, query,
		message.ID,
		message.Content,
		crawlerResultJSON,
	)

	if err != nil {
		return err
	}

	if result.RowsAffected() == 0 {
		return domain.ErrMessageNotFound
	}

	return nil
}

func (r *messageRepository) Delete(ctx context.Context, id string) error {
	query := `
		UPDATE messages
		SET is_active = false
		WHERE id = $1
	`

	result, err := r.db.Exec(ctx, query, id)
	if err != nil {
		return err
	}

	if result.RowsAffected() == 0 {
		return domain.ErrMessageNotFound
	}

	return nil
}

func (r *messageRepository) CountByConversationID(ctx context.Context, conversationID string) (int, error) {
	query := `
		SELECT COUNT(*)
		FROM messages
		WHERE conversation_id = $1 AND is_active = true
	`

	var count int
	err := r.db.QueryRow(ctx, query, conversationID).Scan(&count)
	if err != nil {
		return 0, err
	}

	return count, nil
}
