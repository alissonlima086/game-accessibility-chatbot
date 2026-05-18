package middleware

import (
	"backend/internal/tracing"

	"github.com/gin-gonic/gin"
)

// TracingMiddleware gera ou herda o trace_id por request e injeta no contexto Go.
// Devolve o trace_id no header de resposta para correlação no Flutter.
func TracingMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		traceID := c.GetHeader(tracing.HeaderTraceID)
		if traceID == "" {
			traceID = tracing.New()
		}
		ctx := tracing.WithTraceID(c.Request.Context(), traceID)
		c.Request = c.Request.WithContext(ctx)
		c.Header(tracing.HeaderTraceID, traceID)
		c.Next()
	}
}
