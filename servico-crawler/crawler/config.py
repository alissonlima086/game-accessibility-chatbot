from pydantic_settings import BaseSettings
from typing import Optional, List

class CrawlerConfig(BaseSettings):
    mongodb_url: str = "mongodb://mongodb:27017/"
    mongodb_db: str = "webcrawler"

    crawl_interval: int = 3600
    request_timeout: int = 10

    user_agent: str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"

    max_depth: int = 3
    max_pages_per_domain: int = 100
    max_total_pages: int = 1000

    allowed_domains: List[str] = []
    blocked_domains: List[str] = []

    delete_permanent_errors_from_queue: bool = True
    keep_temporary_errors_for_retry: bool = True

    respect_robots_txt: bool = True
    robots_cache_hours: int = 24 
    robots_txt_timeout: int = 5  

    run_scheduler_on_first_day: bool = True
    scheduler_hour: int = 0
    scheduler_minute: int = 0

    api_host: str = "0.0.0.0"
    api_port: int = 8000

    log_level: str = "INFO"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False

settings = CrawlerConfig()