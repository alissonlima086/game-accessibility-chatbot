import logging
from typing import Dict, Any, Optional
from datetime import datetime

from crawler import WebCrawler
from content_hasher import ContentHasher
from processor.html_processor import HTMLProcessor
from processor.keyword_processor import KeywordProcessor
from config import settings
from tracing import Span, CrawlerMetrics

logger = logging.getLogger(__name__)


class PageCrawler:
    def __init__(self):
        self.crawler = WebCrawler(respect_robots_txt=settings.respect_robots_txt)
        self.html_processor = HTMLProcessor(remove_nav_footer=True, min_word_count=10)
        self.keyword_processor = KeywordProcessor()
        self.content_hasher = ContentHasher()

    def crawl_page(self, url: str, previous_hash: Optional[str] = None, trace_id: str = "") -> Dict[str, Any]:
        metrics = CrawlerMetrics(trace_id=trace_id)

        # ── 1. HTTP fetch ────────────────────────────────────────────────
        span = Span("http fetch")
        crawl_result = self.crawler.crawl(url)
        metrics.http_fetch_ms = span.end()

        if not crawl_result["success"]:
            logger.error("[trace:%s] erro ao crawlear %s: %s", trace_id, url, crawl_result.get("error"))
            return {
                "success": False, "url": url, "changed": False,
                "hash": None, "content": None, "crawled_at": None,
                "error": crawl_result.get("error"),
                "error_type": crawl_result.get("error_type"),
            }

        html_content = crawl_result["html_content"]
        metadata = crawl_result["metadata"]
        content_hash = self.content_hasher.calculate_hash(html_content)

        if not self.content_hasher.content_changed(previous_hash, html_content) and previous_hash:
            logger.info("[trace:%s] conteúdo não mudou para %s. Pulando processamento.", trace_id, url)
            return {
                "success": True, "url": url, "changed": False,
                "hash": content_hash, "content": None,
                "crawled_at": datetime.utcnow().isoformat(),
                "error": None, "error_type": None,
            }

        # ── 2. HTML parse + extração de texto ────────────────────────────
        span = Span("html parse")
        text_content = self.html_processor.process_html(html_content)
        keywords = self.keyword_processor.extract_keywords(text_content)
        summary = HTMLProcessor.extract_summary(html_content, max_length=500)
        metrics.html_parse_ms = span.end()

        processed_content = {
            "title": metadata.get("title"),
            "description": metadata.get("description"),
            "text_content": text_content,
            "summary": summary,
            "word_count": len(text_content.split()),
            "keywords": keywords,
            "language": metadata.get("language"),
            "status_code": metadata.get("status_code", 200),
        }

        logger.info("[trace:%s] página crawled: %s | palavras: %d",
                    trace_id, url, processed_content["word_count"])

        metrics.compute_total()
        if trace_id:
            metrics.log_summary(url)

        return {
            "success": True, "url": url, "changed": True,
            "hash": content_hash, "content": processed_content,
            "crawled_at": datetime.utcnow().isoformat(),
            "error": None, "error_type": None,
        }

    def reset_session(self):
        self.crawler.reset_session()

    def clear_robots_cache(self):
        self.crawler.clear_robots_cache()
