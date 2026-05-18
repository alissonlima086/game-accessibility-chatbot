package domain

import "golang.org/x/crypto/bcrypt"

type UserRole string

const (
	UserRoleUser  UserRole = "USER"
	UserRoleAdmin UserRole = "ADMIN"
)

type User struct {
	DefaultEntity
	Username     string   `json:"username"      db:"username"`
	Email        string   `json:"email"         db:"email"`
	PasswordHash string   `json:"-"             db:"password_hash"` // nunca serializado no JSON
	Role         UserRole `json:"role"          db:"role"`
}

func NewUser(username, email string, role UserRole) *User {
	user := &User{
		Username: username,
		Email:    email,
		Role:     role,
	}
	user.GenerateNewID()
	user.InitializeTimestamps()
	user.IsActive = true
	return user
}

func (u *User) SetPassword(plain string) error {
	hash, err := bcrypt.GenerateFromPassword([]byte(plain), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	u.PasswordHash = string(hash)
	return nil
}

func (u *User) CheckPassword(plain string) bool {
	err := bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(plain))
	return err == nil
}

func (u *User) IsAdmin() bool {
	return u.Role == UserRoleAdmin
}

func (u *User) Validate() error {
	if u.Username == "" {
		return ErrInvalidUsername
	}
	if u.Email == "" {
		return ErrInvalidEmail
	}
	if u.Role != UserRoleUser && u.Role != UserRoleAdmin {
		return ErrInvalidRole
	}
	return nil
}