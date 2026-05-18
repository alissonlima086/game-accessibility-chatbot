from urllib.robotparser import RobotFileParser
from urllib.parse import urlparse
import logging
from typing import Optional, Dict, Tuple
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)


class RobotsChecker:
    def __init__(self, user_agent: str = "Mozilla/5.0", cache_duration_hours: int = 24):
        self.user_agent = user_agent
        self.cache_duration = timedelta(hours=cache_duration_hours)
        self.robots_cache: Dict[str, Dict] = {}

    def can_fetch(self, url: str) -> Tuple[bool, Optional[str]]:
        try:
            domain = urlparse(url).netloc
            parser, stats = self._get_parser(domain)

            if parser is None:
                logger.warning(f"Sem robots.txt para {domain}, permitindo crawl")
                return True, None

            if stats.get("has_problematic_rules"):
                logger.warning(f"robots.txt de {domain} com regras problemáticas, permitindo crawl")
                return True, None

            if not parser.can_fetch(self.user_agent, url):
                return False, "Bloqueado por robots.txt"

            crawl_delay = parser.crawl_delay(self.user_agent)
            if crawl_delay:
                logger.debug(f"Crawl-Delay de {crawl_delay}s para {domain}")

            return True, None

        except Exception as e:
            logger.error(f"Erro ao validar robots.txt para {url}: {str(e)}")
            return True, None

    def _get_parser(self, domain: str) -> Tuple[Optional[RobotFileParser], Dict]:
        if domain in self.robots_cache:
            cached = self.robots_cache[domain]
            if datetime.now() - cached["timestamp"] < self.cache_duration:
                return cached["parser"], cached["stats"]
            del self.robots_cache[domain]
        return self._download_and_cache_robots(domain)

    def _download_and_cache_robots(self, domain: str) -> Tuple[Optional[RobotFileParser], Dict]:
        try:
            robots_url = f"https://{domain}/robots.txt"
            logger.info(f"Baixando robots.txt de {robots_url}")

            parser = RobotFileParser()
            parser.set_url(robots_url)
            parser.read()

            stats = self._analyze_robots_rules(parser, domain)
            self.robots_cache[domain] = {
                "parser": parser,
                "timestamp": datetime.now(),
                "stats": stats
            }

            if stats.get("has_problematic_rules"):
                logger.warning(f"Regras problemáticas em {domain}: {stats.get('problematic_rules')}")

            return parser, stats

        except Exception as e:
            logger.warning(f"Erro ao baixar robots.txt de {domain}: {str(e)}")
            return None, {"error": str(e), "has_problematic_rules": False}

    def _analyze_robots_rules(self, parser: RobotFileParser, domain: str) -> Dict:
        stats = {"has_problematic_rules": False, "problematic_rules": [], "total_entries": 0}
        problematic_patterns = ["//", "*:", "/*/"]

        try:
            if hasattr(parser, "entries"):
                for entry in parser.entries:
                    stats["total_entries"] += 1
                    if hasattr(entry, "disallow"):
                        for disallow_rule in entry.disallow:
                            pattern = disallow_rule[0]
                            if pattern in problematic_patterns:
                                stats["has_problematic_rules"] = True
                                stats["problematic_rules"].append(pattern)
                                logger.warning(f"Regra problemática em {domain}: Disallow: {pattern}")
        except Exception as e:
            logger.debug(f"Não foi possível analisar entries do robots.txt: {e}")

        return stats

    def clear_cache(self):
        self.robots_cache.clear()
        logger.info("Cache de robots.txt limpo")

    def get_cache_info(self) -> Dict[str, dict]:
        return {
            domain: {
                "cached_at": cached["timestamp"].isoformat(),
                "age_seconds": (datetime.now() - cached["timestamp"]).total_seconds(),
                "problematic_rules": cached["stats"].get("problematic_rules", [])
            }
            for domain, cached in self.robots_cache.items()
        }
