package service

import (
	"context"

	"backend/internal/domain"
	"backend/internal/repository"
)

type UserService struct {
	repo repository.UserRepository
}

func NewUserService(repo repository.UserRepository) *UserService {
	return &UserService{repo: repo}
}

func (s *UserService) CreateUser(ctx context.Context, username, email string, role domain.UserRole) (*domain.User, error) {
	existingUser, err := s.repo.GetByEmail(ctx, email)
	if err == nil && existingUser != nil {
		return nil, domain.ErrUserAlreadyExists
	}
	user := domain.NewUser(username, email, role)
	if err := user.Validate(); err != nil {
		return nil, err
	}
	if err := s.repo.Create(ctx, user); err != nil {
		return nil, err
	}
	return user, nil
}

func (s *UserService) GetUserByID(ctx context.Context, id string) (*domain.User, error) {
	return s.repo.GetByID(ctx, id)
}

func (s *UserService) GetUserByEmail(ctx context.Context, email string) (*domain.User, error) {
	return s.repo.GetByEmail(ctx, email)
}

func (s *UserService) UpdateUser(ctx context.Context, user *domain.User) error {
	if err := user.Validate(); err != nil {
		return err
	}
	user.UpdateTimestamp()
	return s.repo.Update(ctx, user)
}

func (s *UserService) DeleteUser(ctx context.Context, id string) error {
	return s.repo.Delete(ctx, id)
}

func (s *UserService) ListUsers(ctx context.Context, limit, offset int) ([]*domain.User, error) {
	if limit <= 0 {
		limit = 10
	}
	if offset < 0 {
		offset = 0
	}
	return s.repo.List(ctx, limit, offset)
}

func (s *UserService) SearchUsers(ctx context.Context, q string, limit, offset int) ([]*domain.User, error) {
	if limit <= 0 {
		limit = 10
	}
	if offset < 0 {
		offset = 0
	}
	return s.repo.Search(ctx, q, limit, offset)
}

// ChangePassword valida a senha atual e persiste o novo hash diretamente,
// usando UpdatePassword para não sobrescrever outros campos.
func (s *UserService) ChangePassword(ctx context.Context, userID, currentPassword, newPassword string) error {
	user, err := s.repo.GetByID(ctx, userID)
	if err != nil {
		return domain.ErrUserNotFound
	}
	if !user.CheckPassword(currentPassword) {
		return domain.ErrInvalidCredentials
	}
	if err := user.SetPassword(newPassword); err != nil {
		return err
	}
	return s.repo.UpdatePassword(ctx, userID, user.PasswordHash)
}
