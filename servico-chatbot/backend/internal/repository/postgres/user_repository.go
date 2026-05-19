package postgres

import (
	"context"
	"errors"

	"backend/internal/domain"

	"github.com/jackc/pgx"
	"github.com/jackc/pgx/v5/pgxpool"
)

type userRepository struct {
	db *pgxpool.Pool
}

func NewUserRepository(db *pgxpool.Pool) *userRepository {
	return &userRepository{db: db}
}

func (r *userRepository) Create(ctx context.Context, user *domain.User) error {
	query := `
		INSERT INTO users (id, username, email, password_hash, role, created_at, updated_at, is_active)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`
	_, err := r.db.Exec(ctx, query,
		user.ID,
		user.Username,
		user.Email,
		user.PasswordHash,
		user.Role,
		user.CreatedAt,
		user.UpdatedAt,
		user.IsActive,
	)
	return err
}

func (r *userRepository) GetByID(ctx context.Context, id string) (*domain.User, error) {
	query := `
		SELECT id, username, email, password_hash, role, created_at, updated_at, is_active
		FROM users
		WHERE id = $1 AND is_active = true
	`
	user := &domain.User{}
	err := r.db.QueryRow(ctx, query, id).Scan(
		&user.ID,
		&user.Username,
		&user.Email,
		&user.PasswordHash,
		&user.Role,
		&user.CreatedAt,
		&user.UpdatedAt,
		&user.IsActive,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrUserNotFound
		}
		return nil, err
	}
	return user, nil
}

func (r *userRepository) GetByEmail(ctx context.Context, email string) (*domain.User, error) {
	query := `
		SELECT id, username, email, password_hash, role, created_at, updated_at, is_active
		FROM users
		WHERE email = $1 AND is_active = true
	`
	user := &domain.User{}
	err := r.db.QueryRow(ctx, query, email).Scan(
		&user.ID,
		&user.Username,
		&user.Email,
		&user.PasswordHash,
		&user.Role,
		&user.CreatedAt,
		&user.UpdatedAt,
		&user.IsActive,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrUserNotFound
		}
		return nil, err
	}
	return user, nil
}

// Update persiste username, email e role — não toca no password_hash.
func (r *userRepository) Update(ctx context.Context, user *domain.User) error {
	query := `
		UPDATE users
		SET username = $2, email = $3, role = $4, updated_at = $5
		WHERE id = $1 AND is_active = true
	`
	result, err := r.db.Exec(ctx, query,
		user.ID,
		user.Username,
		user.Email,
		user.Role,
		user.UpdatedAt,
	)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return domain.ErrUserNotFound
	}
	return nil
}

// UpdatePassword persiste apenas o novo password_hash — método dedicado para troca de senha.
func (r *userRepository) UpdatePassword(ctx context.Context, userID, passwordHash string) error {
	query := `
		UPDATE users
		SET password_hash = $2, updated_at = NOW()
		WHERE id = $1 AND is_active = true
	`
	result, err := r.db.Exec(ctx, query, userID, passwordHash)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return domain.ErrUserNotFound
	}
	return nil
}

func (r *userRepository) Delete(ctx context.Context, id string) error {
	query := `
		UPDATE users
		SET is_active = false, updated_at = NOW()
		WHERE id = $1
	`
	result, err := r.db.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return domain.ErrUserNotFound
	}
	return nil
}

func (r *userRepository) List(ctx context.Context, limit, offset int) ([]*domain.User, error) {
	query := `
		SELECT id, username, email, password_hash, role, created_at, updated_at, is_active
		FROM users
		WHERE is_active = true
		ORDER BY created_at DESC
		LIMIT $1 OFFSET $2
	`
	rows, err := r.db.Query(ctx, query, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	users := make([]*domain.User, 0)
	for rows.Next() {
		user := &domain.User{}
		err := rows.Scan(
			&user.ID,
			&user.Username,
			&user.Email,
			&user.PasswordHash,
			&user.Role,
			&user.CreatedAt,
			&user.UpdatedAt,
			&user.IsActive,
		)
		if err != nil {
			return nil, err
		}
		users = append(users, user)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return users, nil
}

func (r *userRepository) Search(ctx context.Context, q string, limit, offset int) ([]*domain.User, error) {
	pattern := "%" + q + "%"
	query := `
		SELECT id, username, email, password_hash, role, created_at, updated_at, is_active
		FROM users
		WHERE is_active = true
		  AND (username ILIKE $1 OR email ILIKE $1)
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.db.Query(ctx, query, pattern, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	users := make([]*domain.User, 0)
	for rows.Next() {
		user := &domain.User{}
		err := rows.Scan(&user.ID, &user.Username, &user.Email, &user.PasswordHash,
			&user.Role, &user.CreatedAt, &user.UpdatedAt, &user.IsActive)
		if err != nil {
			return nil, err
		}
		users = append(users, user)
	}
	return users, rows.Err()
}
