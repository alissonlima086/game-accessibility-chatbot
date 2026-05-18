package domain

import (
	"encoding/json"
	"time"
)

type MessageRole string

const (
	MessageRoleUser MessageRole = "USER"
	MessageRoleBot  MessageRole = "BOT"
)

type CrawlerResult struct {
	Summary     string `json:"summary"`
	SourceCount int    `json:"source_count"`
}

type Message struct {
	DefaultEntity
	ConversationID string         `json:"conversation_id" db:"conversation_id"`
	ReplyToID      *string        `json:"reply_to_id,omitempty" db:"reply_to_id"`
	Content        string         `json:"content" db:"content"`
	Role           MessageRole    `json:"role" db:"role"`
	Timestamp      time.Time      `json:"timestamp" db:"timestamp"`
	CrawlerResult  *CrawlerResult `json:"crawler_result,omitempty" db:"crawler_result"`
}

func NewMessage(conversationID, content string, role MessageRole) *Message {
	msg := &Message{
		ConversationID: conversationID,
		Content:        content,
		Role:           role,
		Timestamp:      time.Now(),
	}
	msg.GenerateNewID()
	msg.InitializeTimestamps()
	msg.IsActive = true
	return msg
}

func NewUserMessage(conversationID, content string) *Message {
	return NewMessage(conversationID, content, MessageRoleUser)
}

func NewBotMessage(conversationID, content string) *Message {
	return NewMessage(conversationID, content, MessageRoleBot)
}

func (m *Message) SetReplyTo(messageID string) {
	m.ReplyToID = &messageID
}

func (m *Message) AttachCrawlerResult(result *CrawlerResult) {
	m.CrawlerResult = result
	m.UpdateTimestamp()
}

func (m *Message) IsFromUser() bool {
	return m.Role == MessageRoleUser
}

func (m *Message) IsFromBot() bool {
	return m.Role == MessageRoleBot
}

func (m *Message) HasCrawlerResult() bool {
	return m.CrawlerResult != nil
}

func (m *Message) Validate() error {
	if m.ConversationID == "" {
		return ErrInvalidConversationID
	}
	if m.Content == "" {
		return ErrInvalidContent
	}
	if m.Role != MessageRoleUser && m.Role != MessageRoleBot {
		return ErrInvalidRole
	}
	return nil
}

func (m *Message) MarshalCrawlerResult() ([]byte, error) {
	if m.CrawlerResult == nil {
		return nil, nil
	}
	return json.Marshal(m.CrawlerResult)
}

func (m *Message) UnmarshalCrawlerResult(data []byte) error {
	if data == nil || len(data) == 0 {
		return nil
	}
	return json.Unmarshal(data, &m.CrawlerResult)
}
