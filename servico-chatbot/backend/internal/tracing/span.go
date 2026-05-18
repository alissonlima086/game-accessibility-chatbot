package tracing

import (
	"fmt"
	"log"
	"sync"
	"time"
)

// Span cronometra uma etapa individual.
type Span struct {
	Name    string
	start   time.Time
	elapsed time.Duration
	done    bool
}

func startSpan(name string) *Span {
	return &Span{Name: name, start: time.Now()}
}

// End finaliza o span e retorna a duração em ms.
func (s *Span) End() float64 {
	if !s.done {
		s.elapsed = time.Since(s.start)
		s.done = true
	}
	return float64(s.elapsed.Microseconds()) / 1000.0
}

// Ms retorna a duração em ms (chamar após End).
func (s *Span) Ms() float64 {
	return float64(s.elapsed.Microseconds()) / 1000.0
}

// Trace agrega múltiplos spans de uma request.
type Trace struct {
	mu      sync.Mutex
	TraceID string
	spans   []*Span
}

// NewTrace cria um Trace com o trace_id dado.
func NewTrace(traceID string) *Trace {
	return &Trace{TraceID: traceID}
}

// Span inicia e registra um novo span no trace.
func (t *Trace) Span(name string) *Span {
	s := startSpan(name)
	t.mu.Lock()
	t.spans = append(t.spans, s)
	t.mu.Unlock()
	return s
}

// Summary imprime o resumo de todos os spans.
func (t *Trace) Summary(query string) {
	t.mu.Lock()
	defer t.mu.Unlock()

	log.Printf("\n================================================================")
	log.Printf("  📊  TRACE %s — query: %q", t.TraceID, query)
	log.Printf("  ┌─────────────────────────────────────────────────────────")
	var total float64
	for _, s := range t.spans {
		ms := s.Ms()
		total += ms
		log.Printf("  │  %-45s %10.3f ms", s.Name, ms)
	}
	log.Printf("  │  ─────────────────────────────────────────────────────")
	log.Printf("  │  TOTAL Go end-to-end:                         %10.3f ms", total)
	log.Printf("  └─────────────────────────────────────────────────────────")
	log.Printf("================================================================\n")
}

// RAGMetrics são as métricas retornadas pelo serviço Python RAG.
type RAGMetrics struct {
	Retrieval_ms     float64 `json:"retrieval_ms"`
	MongoFetch_ms    float64 `json:"mongo_fetch_ms"`
	PromptBuild_ms   float64 `json:"prompt_build_ms"`
	LLM_ms           float64 `json:"llm_ms"`
	InternalTotal_ms float64 `json:"internal_total_ms"`
}

// GoMetrics são as métricas do lado Go enviadas ao Flutter.
type GoMetrics struct {
	TraceID            string      `json:"trace_id"`
	UserMessageSave_ms float64     `json:"user_message_save_ms"`
	GrpcRoundTrip_ms   float64     `json:"grpc_round_trip_ms"`
	BotMessageSave_ms  float64     `json:"bot_message_save_ms"`
	HTTPWrite_ms       float64     `json:"http_write_ms"`
	GoTotal_ms         float64     `json:"go_total_ms"`
	RAG                *RAGMetrics `json:"rag,omitempty"`
}

// Format retorna uma linha de log legível.
func (m *GoMetrics) Format() string {
	s := fmt.Sprintf(
		"[trace:%s] go_total=%.0fms grpc=%.0fms db_user=%.0fms db_bot=%.0fms",
		m.TraceID, m.GoTotal_ms, m.GrpcRoundTrip_ms, m.UserMessageSave_ms, m.BotMessageSave_ms,
	)
	if m.RAG != nil {
		s += fmt.Sprintf(
			" | rag_total=%.0fms retrieval=%.0fms mongo=%.0fms prompt=%.0fms llm=%.0fms",
			m.RAG.InternalTotal_ms, m.RAG.Retrieval_ms, m.RAG.MongoFetch_ms,
			m.RAG.PromptBuild_ms, m.RAG.LLM_ms,
		)
	}
	return s
}
