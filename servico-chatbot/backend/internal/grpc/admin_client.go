package grpcclient

import (
	"context"
	"fmt"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	"backend/internal/config"
	pb "backend/internal/grpc/proto"
)

type AdminClient struct {
	conn    *grpc.ClientConn
	client  pb.AdminServiceClient
	timeout time.Duration
}

func NewAdminClient(cfg *config.GRPCConfig) (*AdminClient, error) {
	address := fmt.Sprintf("%s:%s", cfg.CrawlerHost, cfg.CrawlerAdminPort)
	conn, err := grpc.Dial(address, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return nil, fmt.Errorf("admin grpc dial: %w", err)
	}
	return &AdminClient{
		conn:    conn,
		client:  pb.NewAdminServiceClient(conn),
		timeout: cfg.Timeout,
	}, nil
}

func (c *AdminClient) Close() error {
	if c.conn != nil {
		return c.conn.Close()
	}
	return nil
}

func (c *AdminClient) ctx() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), c.timeout)
}

func (c *AdminClient) AddLinks(urls []string) (*pb.AddLinksResponse, error) {
	ctx, cancel := c.ctx()
	defer cancel()
	return c.client.AddLinks(ctx, &pb.AddLinksRequest{Urls: urls})
}

func (c *AdminClient) ExtractLinks(limit int32) (*pb.ExtractLinksResponse, error) {
	ctx, cancel := c.ctx()
	defer cancel()
	return c.client.ExtractLinks(ctx, &pb.ExtractLinksRequest{Limit: limit})
}

func (c *AdminClient) CrawlSinglePage(url string) (*pb.CrawlSinglePageResponse, error) {
	ctx, cancel := c.ctx()
	defer cancel()
	return c.client.CrawlSinglePage(ctx, &pb.CrawlSinglePageRequest{Url: url})
}

func (c *AdminClient) GetLinksStatus() (*pb.LinksStatusResponse, error) {
	ctx, cancel := c.ctx()
	defer cancel()
	return c.client.GetLinksStatus(ctx, &pb.Empty{})
}

func (c *AdminClient) GetLinksStatusByDomain() (*pb.LinksByDomainResponse, error) {
	ctx, cancel := c.ctx()
	defer cancel()
	return c.client.GetLinksStatusByDomain(ctx, &pb.Empty{})
}

func (c *AdminClient) ListLinks(limit, skip int32, status, urlFilter string) (*pb.ListLinksResponse, error) {
	ctx, cancel := c.ctx()
	defer cancel()
	return c.client.ListLinks(ctx, &pb.ListLinksRequest{
		Limit:     limit,
		Skip:      skip,
		Status:    status,
		UrlFilter: urlFilter,
	})
}

func (c *AdminClient) DeleteLink(url string) (*pb.OperationResponse, error) {
	ctx, cancel := c.ctx()
	defer cancel()
	return c.client.DeleteLink(ctx, &pb.DeleteLinkRequest{Url: url})
}

func (c *AdminClient) ListPages(limit, skip int32) (*pb.ListPagesResponse, error) {
	ctx, cancel := c.ctx()
	defer cancel()
	return c.client.ListPages(ctx, &pb.ListPagesRequest{Limit: limit, Skip: skip})
}

func (c *AdminClient) ListPagesByDomain(domain string, limit, skip int32) (*pb.ListPagesResponse, error) {
	ctx, cancel := c.ctx()
	defer cancel()
	return c.client.ListPagesByDomain(ctx, &pb.ListPagesByDomainRequest{Domain: domain, Limit: limit, Skip: skip})
}

func (c *AdminClient) GetPage(url string) (*pb.PageDetailResponse, error) {
	ctx, cancel := c.ctx()
	defer cancel()
	return c.client.GetPage(ctx, &pb.GetPageRequest{Url: url})
}

func (c *AdminClient) GetDomainStats(domain string) (*pb.DomainStatsResponse, error) {
	ctx, cancel := c.ctx()
	defer cancel()
	return c.client.GetDomainStats(ctx, &pb.DomainRequest{Domain: domain})
}

func (c *AdminClient) DeleteDomain(domain string) (*pb.DeleteDomainResponse, error) {
	ctx, cancel := c.ctx()
	defer cancel()
	return c.client.DeleteDomain(ctx, &pb.DomainRequest{Domain: domain})
}

func (c *AdminClient) TriggerCrawl(limit int32) (*pb.CrawlResponse, error) {
	ctx, cancel := c.ctx()
	defer cancel()
	return c.client.TriggerCrawl(ctx, &pb.TriggerCrawlRequest{Limit: limit})
}

// RescanAll reseta todos os links para pending e inicia reprocessamento completo.
func (c *AdminClient) RescanAll(limit int32) (*pb.CrawlResponse, error) {
	ctx, cancel := c.ctx()
	defer cancel()
	return c.client.RescanAll(ctx, &pb.TriggerCrawlRequest{Limit: limit})
}
