package tracing

import (
	"context"
	"fmt"
	"math/rand"
	"time"
)

type contextKey string

const traceKey contextKey = "trace_id"

// HeaderTraceID é o header HTTP e metadata gRPC usado em todos os serviços.
const HeaderTraceID = "X-Trace-Id"

// New gera um trace_id único: timestamp-ms em hex + 4 bytes aleatórios.
func New() string {
	b := make([]byte, 4)
	rand.Read(b) //nolint:gosec
	return fmt.Sprintf("%x-%x", time.Now().UnixMilli(), b)
}

// WithTraceID injeta o trace_id no contexto.
func WithTraceID(ctx context.Context, traceID string) context.Context {
	return context.WithValue(ctx, traceKey, traceID)
}

// FromContext extrai o trace_id do contexto; retorna "" se ausente.
func FromContext(ctx context.Context) string {
	v, _ := ctx.Value(traceKey).(string)
	return v
}
