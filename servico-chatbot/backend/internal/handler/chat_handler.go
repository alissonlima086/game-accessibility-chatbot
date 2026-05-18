package handler

import (
	"log"
	"net/http"
	"regexp"
	"strings"
	"time"
	"unicode"

	grpcclient "backend/internal/grpc"
	"backend/internal/handler/dto"
	"backend/internal/service"
	"backend/internal/tracing"

	"github.com/gin-gonic/gin"
)

var stopwordsPT = map[string]bool{
	"o": true, "a": true, "os": true, "as": true, "um": true, "uma": true,
	"de": true, "do": true, "da": true, "dos": true, "das": true, "em": true,
	"no": true, "na": true, "nos": true, "nas": true, "por": true, "para": true,
	"com": true, "que": true, "se": true, "é": true, "são": true,
}

var nonAlpha = regexp.MustCompile(`[^\p{L}\p{N}\s]`)

func generateTitle(query string) string {
	cleaned := nonAlpha.ReplaceAllString(strings.ToLower(query), " ")
	words := strings.Fields(cleaned)
	var keywords []string
	for _, w := range words {
		if !stopwordsPT[w] && len([]rune(w)) > 2 {
			r := []rune(w)
			r[0] = unicode.ToUpper(r[0])
			keywords = append(keywords, string(r))
		}
		if len(keywords) == 5 {
			break
		}
	}
	if len(keywords) == 0 {
		if len([]rune(query)) > 40 {
			return string([]rune(query)[:40]) + "..."
		}
		return query
	}
	return strings.Join(keywords, " ")
}

type ChatHandler struct {
	conversationService *service.ConversationService
	messageService      *service.MessageService
	searchClient        *grpcclient.SearchClient
}

func NewChatHandler(
	conversationService *service.ConversationService,
	messageService *service.MessageService,
	searchClient *grpcclient.SearchClient,
) *ChatHandler {
	return &ChatHandler{
		conversationService: conversationService,
		messageService:      messageService,
		searchClient:        searchClient,
	}
}

func (h *ChatHandler) StartChat(c *gin.Context) {
	var req dto.StartChatRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}
	title := generateTitle(req.Content)
	conversation, err := h.conversationService.CreateConversation(c.Request.Context(), req.UserID, title)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	h.sendAndRespond(c, conversation.ID, req.Content, dto.ToConversationResponse(conversation))
}

func (h *ChatHandler) SendMessage(c *gin.Context) {
	conversationID := c.Param("id")
	var req dto.SendUserMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}
	conv, err := h.conversationService.GetConversationByID(c.Request.Context(), conversationID)
	if err != nil {
		c.JSON(http.StatusNotFound, ErrorResponse{Error: "conversa não encontrada"})
		return
	}
	h.sendAndRespond(c, conversationID, req.Content, dto.ToConversationResponse(conv))
}

func (h *ChatHandler) sendAndRespond(c *gin.Context, conversationID, content string, convResp dto.ConversationResponse) {
	ctx := c.Request.Context()
	traceID := tracing.FromContext(ctx) // injetado pelo TracingMiddleware
	trace := tracing.NewTrace(traceID)
	requestStart := time.Now()

	log.Printf("[trace:%s] nova query: %q", traceID, content)

	// ── 1. Persistir mensagem do usuário ────────────────────────────────
	spanUser := trace.Span("postgres: save user_message")
	userMessage, err := h.messageService.CreateUserMessage(ctx, conversationID, content)
	spanUser.End()
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	// ── 2. gRPC → Python RAG ────────────────────────────────────────────
	spanGRPC := trace.Span("grpc: go → python rag (round-trip)")
	searchResult, searchErr := h.searchClient.Search(ctx, content, "", 5)
	spanGRPC.End()

	var botContent string
	var sources []dto.SourceResponse
	var ragMetrics *tracing.RAGMetrics

	if searchErr != nil || searchResult == nil {
		log.Printf("[trace:%s] grpc error: %v", traceID, searchErr)
		botContent = "Não foi possível obter uma resposta no momento."
	} else {
		botContent = searchResult.Proto.Answer
		ragMetrics = searchResult.Metrics // nil se Python ainda não retornar metrics_json
		for _, r := range searchResult.Proto.Results {
			sources = append(sources, dto.SourceResponse{
				URL:   r.Url,
				Score: float64(r.Score),
			})
		}
	}

	// ── 3. Persistir mensagem do bot ────────────────────────────────────
	spanBot := trace.Span("postgres: save bot_message")
	botMessage, err := h.messageService.CreateBotMessage(ctx, conversationID, botContent)
	spanBot.End()
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}

	// ── 4. Montar métricas e responder ao Flutter ────────────────────────
	goMetrics := &tracing.GoMetrics{
		TraceID:            traceID,
		UserMessageSave_ms: spanUser.Ms(),
		GrpcRoundTrip_ms:   spanGRPC.Ms(),
		BotMessageSave_ms:  spanBot.Ms(),
		RAG:                ragMetrics,
	}

	spanHTTP := trace.Span("http: serialize + write to flutter")
	c.JSON(http.StatusOK, dto.ChatResponse{
		Conversation: convResp,
		UserMessage:  dto.ToMessageResponse(userMessage),
		BotMessage:   dto.ToMessageResponse(botMessage),
		Sources:      sources,
		Metrics:      goMetrics,
	})
	spanHTTP.End()

	goMetrics.HTTPWrite_ms = spanHTTP.Ms()
	goMetrics.GoTotal_ms = float64(time.Since(requestStart).Microseconds()) / 1000.0

	trace.Summary(content)
	log.Printf("[trace:%s] %s", traceID, goMetrics.Format())
}
