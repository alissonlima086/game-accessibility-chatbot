import logging
from typing import Dict, List, Any, Optional
from urllib.parse import urlparse
from crawler import WebCrawler
from config import settings

logger = logging.getLogger(__name__)


class LinkCrawler:
    def __init__(self):
        self.crawler = WebCrawler(respect_robots_txt=settings.respect_robots_txt)
        self.base_domain = None

    def extract_links_from_url(self, url: str, current_depth: int, target_domain: Optional[str] = None) -> Dict[str, Any]:
        self.base_domain = target_domain or self._get_root_domain(urlparse(url).netloc)

        if settings.respect_robots_txt:
            try:
                can_fetch, reason = self.crawler.robots_checker.can_fetch(url)
                if not can_fetch:
                    logger.warning(f"Link bloqueado por robots.txt: {url}")
                    return {"success": False, "links": [], "depth": current_depth + 1,
                            "error": reason, "error_type": "robots_blocked", "robots_blocked": True}
            except Exception as e:
                logger.error(f"Erro ao validar robots.txt para {url}: {str(e)}")
                return {"success": False, "links": [], "depth": current_depth + 1,
                        "error": str(e), "error_type": "robots_blocked", "robots_blocked": True}

        if current_depth >= settings.max_depth:
            logger.debug(f"Limite de profundidade atingido para: {url}")
            return {"success": False, "links": [], "depth": current_depth + 1,
                    "error": f"Profundidade máxima ({settings.max_depth}) atingida",
                    "error_type": "depth_exceeded", "robots_blocked": False}

        # Limpa URLs visitadas para permitir re-extração (ex: após reinício do serviço)
        self.crawler.visited_urls.clear()
        crawl_result = self.crawler.crawl(url, depth=current_depth)

        if not crawl_result["success"]:
            logger.error(f"Erro ao fazer crawl de {url}: {crawl_result.get('error')}")
            return {"success": False, "links": [], "depth": current_depth + 1,
                    "error": crawl_result.get("error"), "error_type": crawl_result.get("error_type"),
                    "robots_blocked": False}

        extracted_links = crawl_result["metadata"].get("extracted_links", [])
        filtered_links = self._filter_links(extracted_links)

        logger.info(f"Links extraídos de {url}: {len(extracted_links)} brutos → {len(filtered_links)} após filtro")

        return {
            "success": True, "links": filtered_links, "depth": current_depth + 1,
            "error": None, "error_type": None, "robots_blocked": False,
            "source_url": url, "source_depth": current_depth
        }

    def _filter_links(self, links: List[str]) -> List[str]:
        filtered = []
        for link in links:
            if not self.crawler._is_valid_url(link):
                continue
            if not self.crawler._validate_domain(link)["valid"]:
                continue
            if self.base_domain:
                if self._get_root_domain(urlparse(link).netloc) != self.base_domain:
                    continue
            filtered.append(link)
        return filtered

    def _get_root_domain(self, domain: str) -> str:
        parts = domain.split(".")
        return ".".join(parts[-2:])

    def reset_session(self):
        self.crawler.reset_session()

    def clear_robots_cache(self):
        self.crawler.clear_robots_cache()
