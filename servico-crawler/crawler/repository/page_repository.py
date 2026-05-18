from datetime import datetime
from typing import Dict, Any, List, Optional
import logging
from urllib.parse import urlparse

logger = logging.getLogger(__name__)


class PageRepository:
    def __init__(self, db):
        self.collection = db.pages
        self.collection.create_index([("url", 1)], unique=True)
        self.collection.create_index([("domain", 1), ("crawled_at", -1)])
        self.collection.create_index([("content_hash", 1)])
        self.collection.create_index([("embedding_status", 1)])

    def get_pages(self, limit=10, skip=0):
        pages = list(self.collection.find().sort("crawled_at", -1).skip(skip).limit(limit))
        for p in pages:
            p.pop("text_content", None)
            p.pop("_id", None)
        return pages

    def get_pages_by_domain(self, domain: str, limit=10, skip=0):
        pages = list(self.collection.find({"domain": domain}).sort("crawled_at", -1).skip(skip).limit(limit))
        for p in pages:
            p.pop("text_content", None)
            p.pop("_id", None)
        return pages

    def get_by_url(self, url: str) -> Optional[Dict]:
        return self.collection.find_one({"url": url})

    def delete_by_url(self, url: str) -> bool:
        return self.collection.delete_one({"url": url}).deleted_count > 0

    def save_or_update(self, url: str, page_doc: Dict) -> bool:
        result = self.collection.update_one({"url": url}, {"$set": page_doc}, upsert=True)
        return result.modified_count > 0 or result.upserted_id is not None

    def update_last_crawled(self, url: str, crawled_at: str) -> bool:
        result = self.collection.update_one(
            {"url": url},
            {"$set": {"updated_at": datetime.utcnow().isoformat(), "last_check": crawled_at}}
        )
        return result.modified_count > 0

    def delete_by_domain(self, domain: str) -> int:
        return self.collection.delete_many({"domain": domain}).deleted_count

    def count_by_domain(self, domain: str) -> int:
        return self.collection.count_documents({"domain": domain})

    def get_pending_embeddings(self, limit: int = 50, skip: int = 0) -> List[Dict]:
        return list(self.collection.find({"embedding_status": "pending"}).sort("crawled_at", -1).skip(skip).limit(limit))

    def set_embedding_processing(self, url: str) -> bool:
        result = self.collection.update_one(
            {"url": url},
            {"$set": {"embedding_status": "processing", "embedding_started_at": datetime.utcnow().isoformat()}}
        )
        return result.modified_count > 0

    def set_embedding_completed(self, url: str, chunks_count: int) -> bool:
        result = self.collection.update_one(
            {"url": url},
            {"$set": {"embedding_status": "completed", "chunks_count": chunks_count, "embedding_completed_at": datetime.utcnow().isoformat()}}
        )
        return result.modified_count > 0

    def set_embedding_failed(self, url: str, error: str) -> bool:
        result = self.collection.update_one(
            {"url": url},
            {"$set": {"embedding_status": "failed", "embedding_error": error, "embedding_failed_at": datetime.utcnow().isoformat()}}
        )
        return result.modified_count > 0

    def reset_failed_embeddings(self) -> int:
        result = self.collection.update_many(
            {"embedding_status": "failed"},
            {"$set": {"embedding_status": "pending", "embedding_error": None}}
        )
        return result.modified_count

    def get_embedding_stats(self) -> Dict[str, int]:
        return {
            status: self.collection.count_documents({"embedding_status": status})
            for status in ("pending", "processing", "completed", "failed")
        }

    def _extract_domain(self, url: str) -> str:
        try:
            return urlparse(url).netloc.lower()
        except Exception as e:
            logger.error(f"Erro ao extrair domínio de {url}: {str(e)}")
            return ""
