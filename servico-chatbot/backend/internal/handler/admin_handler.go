package handler

import (
	"net/http"
	"strconv"
	"strings"

	grpcclient "backend/internal/grpc"

	"github.com/gin-gonic/gin"
)

type AdminHandler struct {
	adminClient *grpcclient.AdminClient
}

func NewAdminHandler(adminClient *grpcclient.AdminClient) *AdminHandler {
	return &AdminHandler{adminClient: adminClient}
}

// ── Links ─────────────────────────────────────────────────────────────────────

func (h *AdminHandler) AddLinks(c *gin.Context) {
	var body struct {
		URLs []string `json:"urls" binding:"required,min=1"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}
	resp, err := h.adminClient.AddLinks(body.URLs)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"added": resp.Added, "duplicated": resp.Duplicated, "errors": resp.Errors})
}

func (h *AdminHandler) ExtractLinks(c *gin.Context) {
	limit := int32(parseIntQuery(c, "limit", 100))
	resp, err := h.adminClient.ExtractLinks(limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"processed":   resp.Processed,
		"links_added": resp.LinksAdded,
		"errors":      resp.Errors,
	})
}

func (h *AdminHandler) CrawlSinglePage(c *gin.Context) {
	var body struct {
		URL string `json:"url" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: err.Error()})
		return
	}
	resp, err := h.adminClient.CrawlSinglePage(body.URL)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": resp.Success, "message": resp.Message, "title": resp.Title})
}

func (h *AdminHandler) GetLinksStatus(c *gin.Context) {
	resp, err := h.adminClient.GetLinksStatus()
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"total": resp.Total, "pending": resp.Pending,
		"success": resp.Success, "error": resp.Error, "blocked": resp.Blocked,
	})
}

func (h *AdminHandler) GetLinksStatusByDomain(c *gin.Context) {
	resp, err := h.adminClient.GetLinksStatusByDomain()
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	domains := make([]gin.H, 0, len(resp.Domains))
	for _, d := range resp.Domains {
		domains = append(domains, gin.H{
			"domain": d.Domain, "total": d.Total,
			"pending": d.Pending, "success": d.Success, "error": d.Error,
		})
	}
	c.JSON(http.StatusOK, domains)
}

func (h *AdminHandler) ListLinks(c *gin.Context) {
	limit := int32(parseIntQuery(c, "limit", 20))
	skip := int32(parseIntQuery(c, "skip", 0))
	status := c.DefaultQuery("status", "")
	urlFilter := c.DefaultQuery("url", "")
	resp, err := h.adminClient.ListLinks(limit, skip, status, urlFilter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	links := make([]gin.H, 0, len(resp.Links))
	for _, l := range resp.Links {
		links = append(links, gin.H{
			"url":           l.Url,
			"status":        l.Status,
			"depth":         l.Depth,
			"domain":        l.Domain,
			"created_at":    l.CreatedAt,
			"updated_at":    l.UpdatedAt,
			"error_message": l.ErrorMessage,
		})
	}
	c.JSON(http.StatusOK, gin.H{"links": links, "total": resp.Total})
}

func (h *AdminHandler) DeleteLink(c *gin.Context) {
	url := strings.TrimPrefix(c.Param("url"), "/")
	if url == "" {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "url obrigatória"})
		return
	}
	resp, err := h.adminClient.DeleteLink(url)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": resp.Success, "message": resp.Message})
}

// ── Pages ─────────────────────────────────────────────────────────────────────

func (h *AdminHandler) ListPages(c *gin.Context) {
	limit := int32(parseIntQuery(c, "limit", 10))
	skip := int32(parseIntQuery(c, "skip", 0))
	resp, err := h.adminClient.ListPages(limit, skip)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	c.JSON(http.StatusOK, resp.Pages)
}

func (h *AdminHandler) ListPagesByDomain(c *gin.Context) {
	domain := c.Param("domain")
	limit := int32(parseIntQuery(c, "limit", 10))
	skip := int32(parseIntQuery(c, "skip", 0))
	resp, err := h.adminClient.ListPagesByDomain(domain, limit, skip)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	c.JSON(http.StatusOK, resp.Pages)
}

func (h *AdminHandler) GetPage(c *gin.Context) {
	url := c.Query("url")
	if url == "" {
		c.JSON(http.StatusBadRequest, ErrorResponse{Error: "url obrigatória"})
		return
	}
	resp, err := h.adminClient.GetPage(url)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	c.JSON(http.StatusOK, resp)
}

// ── Domains ───────────────────────────────────────────────────────────────────

func (h *AdminHandler) GetDomainStats(c *gin.Context) {
	resp, err := h.adminClient.GetDomainStats(c.Param("domain"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"domain":              resp.Domain,
		"total_links":         resp.TotalLinks,
		"total_pages_crawled": resp.TotalPagesCrawled,
		"links_by_status": gin.H{
			"pending": resp.Pending, "extracted": resp.Extracted,
			"success": resp.Success, "error": resp.Error, "blocked": resp.Blocked,
		},
	})
}

func (h *AdminHandler) DeleteDomain(c *gin.Context) {
	resp, err := h.adminClient.DeleteDomain(c.Param("domain"))
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"links_deleted": resp.LinksDeleted, "pages_deleted": resp.PagesDeleted})
}

// ── Crawl ─────────────────────────────────────────────────────────────────────

func (h *AdminHandler) TriggerCrawl(c *gin.Context) {
	limit := int32(parseIntQuery(c, "limit", 50))
	resp, err := h.adminClient.TriggerCrawl(limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, ErrorResponse{Error: err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": resp.Message, "timestamp": resp.Timestamp})
}

func parseIntQuery(c *gin.Context, key string, def int) int {
	v, err := strconv.Atoi(c.DefaultQuery(key, strconv.Itoa(def)))
	if err != nil {
		return def
	}
	return v
}
