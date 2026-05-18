package domain

import "errors"

var (
	// Erros de usuário
	ErrUserNotFound      = errors.New("Usuario não encontrado")
	ErrUserAlreadyExists = errors.New("Usuario já existe")
	ErrInvalidUsername   = errors.New("Username inválido")
	ErrInvalidEmail      = errors.New("Email inválido")
	ErrInvalidRole       = errors.New("Função invalida")
	ErrInvalidUserID     = errors.New("Id inválido")

	// Essos de conversa
	ErrConversationNotFound  = errors.New("Conversa não encontrada")
	ErrInvalidConversationID = errors.New("Id de conversa inválido")
	ErrInvalidStatus         = errors.New("Status inválido")

	// Erros de mensagem
	ErrMessageNotFound = errors.New("Mensagem não encontrada")
	ErrInvalidContent  = errors.New("Conteúdo inválido")

	// Erros gerais
	ErrInternalServer = errors.New("internal server error")
	ErrBadRequest     = errors.New("bad request")
	ErrUnauthorized   = errors.New("unauthorized")

	// Erros de autenticação
	ErrInvalidCredentials = errors.New("credenciais inválidas")
    ErrInvalidToken       = errors.New("token inválido")
    ErrInvalidPassword    = errors.New("senha inválida")
)
