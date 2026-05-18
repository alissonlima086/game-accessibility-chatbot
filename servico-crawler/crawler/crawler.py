import requests
from bs4 import BeautifulSoup
from config import settings
from robots_checker import RobotsChecker
from status_code_classifier import status_classifier
from typing import Dict, List, Any, Optional
from urllib.parse import urljoin, urlparse
import logging
from datetime import datetime

logger = logging.getLogger(__name__)


class WebCrawler:
    def __init__(self, respect_robots_txt: bool = True):
        self.user_agent = settings.user_agent
        self.timeout = settings.request_timeout
        self.headers = {"User-Agent": self.user_agent}
        self.visited_urls = set()
        self.respect_robots_txt = respect_robots_txt

        self.robots_checker = RobotsChecker(
            user_agent=self.user_agent,
            cache_duration_hours=settings.robots_cache_hours
        ) if respect_robots_txt else None

    def crawl(self, url: str, depth: int = 0) -> Dict[str, Any]:
        if depth > settings.max_depth:
            return {
                "url": url, "success": False,
                "error": f"Profundidade máxima alcançada ({settings.max_depth})",
                "error_type": "depth_exceeded", "should_delete": False,
                "html_content": None, "metadata": {}
            }

        if url in self.visited_urls:
            return {
                "url": url, "success": False,
                "error": "URL já visitada nessa instância",
                "error_type": "duplicate", "should_delete": False,
                "html_content": None, "metadata": {}, "is_duplicate": True
            }

        if self.respect_robots_txt:
            can_fetch, reason = self.robots_checker.can_fetch(url)
            if not can_fetch:
                return {
                    "url": url, "success": False,
                    "error": f"Bloqueado por robots.txt: {reason}",
                    "error_type": "robots_blocked", "should_delete": False,
                    "html_content": None, "metadata": {}, "is_blocked": True
                }

        self.visited_urls.add(url)

        try:
            response = requests.get(url, headers=self.headers, timeout=self.timeout, allow_redirects=True)
            status_code = response.status_code

            if not status_classifier.is_success(status_code):
                error_message = status_classifier.get_error_message(status_code)
                classification = status_classifier.classify(status_code)
                action = status_classifier.get_action_for_error(status_code)
                logger.warning(f"{error_message} para {url}")
                return {
                    "url": url, "success": False,
                    "error": error_message, "error_type": classification,
                    "status_code": status_code,
                    "should_delete": action["should_delete"],
                    "should_retry": action["should_retry"],
                    "html_content": None,
                    "metadata": {"status_code": status_code, "depth": depth}
                }

            response.raise_for_status()
            soup = BeautifulSoup(response.text, "lxml")
            metadata = self.extract_metadata(soup, url)
            metadata["status_code"] = response.status_code
            metadata["depth"] = depth

            return {"url": url, "success": True, "html_content": response.text, "metadata": metadata, "error": None}

        except requests.exceptions.Timeout:
            logger.error(f"Timeout ao acessar {url}")
            return {"url": url, "success": False, "error": f"Timeout ao acessar {url}",
                    "error_type": "timeout", "should_delete": False, "should_retry": True,
                    "html_content": None, "metadata": {"depth": depth}}

        except requests.exceptions.ConnectionError as e:
            logger.error(f"Erro de conexão ao acessar {url}: {e}")
            return {"url": url, "success": False, "error": f"Erro de conexão: {str(e)}",
                    "error_type": "connection_error", "should_delete": False, "should_retry": True,
                    "html_content": None, "metadata": {"depth": depth}}

        except requests.exceptions.HTTPError as e:
            logger.error(f"Erro HTTP ao acessar {url}: {e}")
            return {"url": url, "success": False, "error": f"Erro HTTP: {str(e)}",
                    "error_type": "http_error", "should_delete": False, "should_retry": True,
                    "html_content": None, "metadata": {"depth": depth}}

        except Exception as e:
            logger.error(f"Erro inesperado ao acessar {url}: {e}")
            return {"url": url, "success": False, "error": f"Erro inesperado: {str(e)}",
                    "error_type": "unknown_error", "should_delete": False, "should_retry": True,
                    "html_content": None, "metadata": {"depth": depth}}

    def _validate_domain(self, url: str) -> Dict[str, Any]:
        try:
            domain = urlparse(url).netloc.lower()
            for blocked in settings.blocked_domains:
                if blocked.lower() in domain:
                    return {"valid": False, "reason": f"Dominio bloqueado: {domain}"}
            return {"valid": True, "reason": ""}
        except Exception as e:
            logger.error(f"Erro ao validar domínio de {url}: {str(e)}")
            return {"valid": False, "reason": f"Erro ao validar domínio: {str(e)}"}

    def extract_metadata(self, soup: BeautifulSoup, url: str, depth: int = 0) -> Dict[str, Any]:
        return {
            "title": self._get_title(soup),
            "meta_keywords": self._get_meta_content(soup, "name", "keywords"),
            "description": self._get_meta_content(soup, "name", "description"),
            "word_count": self._count_words(soup),
            "language": self._get_language(soup),
            "crawled_at": datetime.utcnow().isoformat(),
            "extracted_links": self._extract_links(soup, url),
            "depth": depth
        }

    def _get_title(self, soup: BeautifulSoup) -> Optional[str]:
        if soup.title and soup.title.string:
            text = soup.title.get_text(strip=True)
            return text if text else None
        return None

    def _get_meta_content(self, soup: BeautifulSoup, attr_name: str, attr_value: str) -> Optional[str]:
        tag = soup.find("meta", attrs={attr_name: attr_value})
        if tag and tag.get("content"):
            content = tag["content"].strip()
            return content if content else None
        return None

    def _count_words(self, soup: BeautifulSoup) -> int:
        try:
            for tag in soup(["script", "style"]):
                tag.decompose()
            return len(soup.get_text(separator=" ", strip=True).split())
        except Exception as e:
            logger.error(f"Erro ao contar palavras: {str(e)}")
            return 0

    def _get_language(self, soup: BeautifulSoup) -> Optional[str]:
        html_tag = soup.find("html")
        if html_tag and html_tag.get("lang"):
            lang = html_tag["lang"].strip()
            return lang if lang else None
        return None

    def _extract_links(self, soup: BeautifulSoup, base_url: str) -> List[str]:
        links = set()
        for a_tag in soup.find_all("a", href=True):
            href = a_tag["href"].strip()
            if not href or href.startswith(("#", "mailto:", "javascript:")):
                continue
            full_url = self._normalize_url(urljoin(base_url, href))
            if not self._is_valid_url(full_url):
                continue
            if not self._validate_domain(full_url)["valid"]:
                logger.debug(f"Link em domínio bloqueado: {full_url}")
                continue
            links.add(full_url)
        links_list = list(links)
        logger.info(f"Extraidos {len(links_list)} links únicos de {base_url}")
        return links_list

    BLOCKED_EXTENSIONS = {
        ".xls", ".xlsx", ".xlsm", ".xlsb", ".xml", ".csv", ".ods",
        ".doc", ".docx", ".odt", ".rtf", ".ppt", ".pptx", ".odp",
        ".pdf", ".epub", ".mobi",
        ".jpg", ".jpeg", ".png", ".gif", ".webp", ".svg", ".ico",
        ".bmp", ".tiff", ".tif",
        ".mp4", ".mp3", ".avi", ".mov", ".mkv", ".webm", ".wav",
        ".flac", ".ogg",
        ".zip", ".rar", ".tar", ".gz", ".7z",
        ".exe", ".dmg", ".deb", ".rpm", ".apk",
        ".js", ".css", ".json",
        ".log", ".sql", ".db",
    }

    def _is_valid_url(self, url: str) -> bool:
        try:
            parsed = urlparse(url)
            if parsed.scheme not in ("http", "https") or not parsed.netloc:
                return False
            path = parsed.path.lower().split("?")[0].split("#")[0]
            ext = "." + path.rsplit(".", 1)[-1] if "." in path else ""
            if ext in self.BLOCKED_EXTENSIONS:
                logger.debug(f"URL bloqueada por extensão ({ext}): {url}")
                return False
            return True
        except Exception as e:
            logger.error(f"Erro ao validar URL {url}: {str(e)}")
            return False

    def _normalize_url(self, url: str) -> str:
        parsed = urlparse(url)
        return f"{parsed.scheme}://{parsed.netloc}{parsed.path.rstrip('/')}"

    def reset_session(self):
        self.visited_urls.clear()

    def get_robots_cache_info(self) -> Dict:
        return self.robots_checker.get_cache_info() if self.robots_checker else {}

    def clear_robots_cache(self):
        if self.robots_checker:
            self.robots_checker.clear_cache()
