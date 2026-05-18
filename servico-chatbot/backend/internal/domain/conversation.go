package domain

type ConversationStatus string

const (
	ConversationStatusOpen     ConversationStatus = "OPEN"
	ConversationStatusClosed   ConversationStatus = "CLOSED"
	ConversationStatusArchived ConversationStatus = "ARCHIVED"
)

type Conversation struct {
	DefaultEntity
	UserID   string             `json:"user_id" db:"user_id"`
	Title    string             `json:"title" db:"title"`
	Status   ConversationStatus `json:"status" db:"status"`
	Messages []*Message         `json:"messages,omitempty" db:"-"`
}

func NewConversation(userID, title string) *Conversation {
	conv := &Conversation{
		UserID:   userID,
		Title:    title,
		Status:   ConversationStatusOpen,
		Messages: make([]*Message, 0),
	}
	conv.GenerateNewID()
	conv.InitializeTimestamps()
	conv.IsActive = true
	return conv
}

func (c *Conversation) AddMessage(message *Message) {
	c.Messages = append(c.Messages, message)
	c.UpdateTimestamp()
}

func (c *Conversation) GetMessages(limit int) []*Message {
	if limit <= 0 || limit > len(c.Messages) {
		return c.Messages
	}

	start := len(c.Messages) - limit
	return c.Messages[start:]
}

func (c *Conversation) Close() {
	c.Status = ConversationStatusClosed
	c.UpdateTimestamp()
}

func (c *Conversation) Archive() {
	c.Status = ConversationStatusArchived
	c.UpdateTimestamp()
}

func (c *Conversation) Reopen() {
	if c.Status == ConversationStatusClosed {
		c.Status = ConversationStatusOpen
		c.UpdateTimestamp()
	}
}

func (c *Conversation) Validate() error {
	if c.UserID == "" {
		return ErrInvalidUserID
	}
	if c.Status != ConversationStatusOpen &&
		c.Status != ConversationStatusClosed &&
		c.Status != ConversationStatusArchived {
		return ErrInvalidStatus
	}
	return nil
}
