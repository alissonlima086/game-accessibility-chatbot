package domain

import (
	"time"

	"github.com/google/uuid"
)

type DefaultEntity struct {
	ID        string    `json:"id" db:"id"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`
	IsActive  bool      `json:"is_active" db:"is_active"`
}

func (e *DefaultEntity) GenerateNewID() string {
	e.ID = uuid.New().String()
	return e.ID
}

func (e *DefaultEntity) AssignID(id string) {
	e.ID = id
}

func (e *DefaultEntity) MarkAsInactive() {
	e.IsActive = false
}

func (e *DefaultEntity) InitializeTimestamps() {
	now := time.Now()
	e.CreatedAt = now
	e.UpdatedAt = now
}

func (e *DefaultEntity) UpdateTimestamp() {
	e.UpdatedAt = time.Now()
}
