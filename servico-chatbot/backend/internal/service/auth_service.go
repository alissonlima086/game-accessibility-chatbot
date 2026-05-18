package service

import (
	"context"
	"time"

	"backend/internal/domain"
	"backend/internal/repository"

	"github.com/golang-jwt/jwt/v5"
)

// Claims representa o payload do JWT
type Claims struct {
	UserID string          `json:"user_id"`
	Email  string          `json:"email"`
	Role   domain.UserRole `json:"role"`
	jwt.RegisteredClaims
}

type AuthService struct {
	repo            repository.UserRepository
	jwtSecret       []byte
	expirationHours int
}

func NewAuthService(repo repository.UserRepository, jwtSecret string, expirationHours int) *AuthService {
	return &AuthService{
		repo:            repo,
		jwtSecret:       []byte(jwtSecret),
		expirationHours: expirationHours,
	}
}

// Register cria um novo usuário com senha
func (s *AuthService) Register(ctx context.Context, username, email, password string, role domain.UserRole) (*domain.User, error) {
	existing, err := s.repo.GetByEmail(ctx, email)
	if err == nil && existing != nil {
		return nil, domain.ErrUserAlreadyExists
	}

	user := domain.NewUser(username, email, role)

	if err := user.Validate(); err != nil {
		return nil, err
	}

	if err := user.SetPassword(password); err != nil {
		return nil, err
	}

	if err := s.repo.Create(ctx, user); err != nil {
		return nil, err
	}

	return user, nil
}

// Login valida as credenciais e retorna um token JWT
func (s *AuthService) Login(ctx context.Context, email, password string) (string, *domain.User, error) {
	user, err := s.repo.GetByEmail(ctx, email)
	if err != nil {
		// Retorna ErrInvalidCredentials mesmo quando o usuário não existe
		// para não vazar informação sobre quais emails estão cadastrados
		return "", nil, domain.ErrInvalidCredentials
	}

	if !user.CheckPassword(password) {
		return "", nil, domain.ErrInvalidCredentials
	}

	token, err := s.generateToken(user)
	if err != nil {
		return "", nil, err
	}

	return token, user, nil
}

// ValidateToken valida um JWT e retorna as claims
func (s *AuthService) ValidateToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, domain.ErrInvalidToken
		}
		return s.jwtSecret, nil
	})

	if err != nil || !token.Valid {
		return nil, domain.ErrInvalidToken
	}

	claims, ok := token.Claims.(*Claims)
	if !ok {
		return nil, domain.ErrInvalidToken
	}

	return claims, nil
}

func (s *AuthService) generateToken(user *domain.User) (string, error) {
	claims := &Claims{
		UserID: user.ID,
		Email:  user.Email,
		Role:   user.Role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Duration(s.expirationHours) * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Subject:   user.ID,
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(s.jwtSecret)
}