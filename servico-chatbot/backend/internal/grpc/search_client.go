package grpcclient

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/metadata"

	"backend/internal/config"
	pb "backend/internal/grpc/proto"
	"backend/internal/tracing"
)

type SearchClient struct {
	conn    *grpc.ClientConn
	client  pb.SearchServiceClient
	timeout time.Duration
}

func NewSearchClient(cfg *config.GRPCConfig) (*SearchClient, error) {
	address := fmt.Sprintf("%s:%s", cfg.CrawlerHost, cfg.CrawlerSearchPort)
	conn, err := grpc.Dial(address, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return nil, fmt.Errorf("search grpc dial: %w", err)
	}
	return &SearchClient{
		conn:    conn,
		client:  pb.NewSearchServiceClient(conn),
		timeout: cfg.Timeout,
	}, nil
}

func (c *SearchClient) Close() error {
	if c.conn != nil {
		return c.conn.Close()
	}
	return nil
}

// SearchResult encapsula a resposta proto + as métricas RAG deserializadas.
type SearchResult struct {
	Proto   *pb.SearchResponse
	Metrics *tracing.RAGMetrics
}

// Search envia a query com o trace_id no metadata gRPC e retorna
// a resposta proto + as métricas RAG contidas em metrics_json.
func (c *SearchClient) Search(ctx context.Context, query, domain string, limit int32) (*SearchResult, error) {
	tctx, cancel := context.WithTimeout(ctx, c.timeout)
	defer cancel()

	// Propaga o trace_id como metadata gRPC (lowercase — padrão gRPC).
	if traceID := tracing.FromContext(ctx); traceID != "" {
		tctx = metadata.AppendToOutgoingContext(tctx, "x-trace-id", traceID)
	}

	resp, err := c.client.Search(tctx, &pb.SearchRequest{
		Query:  query,
		Limit:  limit,
		Domain: domain,
	})
	if err != nil {
		return nil, err
	}

	result := &SearchResult{Proto: resp}

	// Desserializa métricas RAG do campo metrics_json (adicionado ao proto).
	// Se o campo não existir / estiver vazio, Metrics fica nil — compatibilidade retroativa.
	if resp.GetMetricsJson() != "" {
		var m tracing.RAGMetrics
		if jsonErr := json.Unmarshal([]byte(resp.GetMetricsJson()), &m); jsonErr == nil {
			result.Metrics = &m
		}
	}

	return result, nil
}
