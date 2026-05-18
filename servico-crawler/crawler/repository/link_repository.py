from datetime import datetime
from typing import List, Dict, Any, Optional
import logging
from urllib.parse import urlparse

logger = logging.getLogger(__name__)


class LinkRepository:
    def __init__(self, db):
        self.collection = db.links
        self.collection.create_index("url")
        self.collection.create_index("status")
        self.collection.create_index("domain")
        self.collection.create_index([("url", 1), ("status", 1)])
        self.collection.create_index("created_at")
        self.collection.create_index([("status", 1), ("attempts", 1)])
        self.collection.create_index([("last_crawled", 1)])

    def add_links(self, urls: List[str], depth: int, max_per_domain: int = None) -> Dict[str, int]:
        added = 0
        duplicated = 0

        for url in urls:
            try:
                if self.collection.find_one({"url": url}):
                    duplicated += 1
                    continue

                result = self.collection.insert_one({
                    "url": url,
                    "domain": self._extract_domain(url),
                    "depth": depth,
                    "status": "pending",
                    "error": None,
                    "attempts": 0,
                    "created_at": datetime.utcnow(),
                    "next_crawl": datetime.utcnow(),
                    "last_crawled": None,
                })

                if result.inserted_id:
                    added += 1

            except Exception as e:
                logger.error(f"Erro ao adicionar link {url}: {str(e)}")

        return {"added": added, "duplicated": duplicated, "total": added + duplicated}

    def get_pending(self, limit: int = 100) -> List[Dict]:
        return list(self.collection.find({"status": "pending"}).sort("created_at", 1).limit(limit))

    def get_pending_by_status(self, status: str, limit: int = 100) -> List[Dict]:
        return list(self.collection.find({"status": status}).sort("created_at", 1).limit(limit))

    def get_pending_for_crawl(self, limit: int = 100) -> List[Dict]:
        return list(
            self.collection.find({"status": "pending"})
            .sort([("attempts", 1), ("created_at", 1)])
            .limit(limit)
        )

    def get_status(self) -> Dict[str, Any]:
        return {
            "total": self.collection.count_documents({}),
            "pending": self.collection.count_documents({"status": "pending"}),
            "success": self.collection.count_documents({"status": "success"}),
            "error": self.collection.count_documents({"status": "error"}),
            "blocked": self.collection.count_documents({"status": "blocked"}),
        }

    def get_status_by_domain(self) -> List[Dict]:
        pipeline = [
            {
                "$group": {
                    "_id": "$domain",
                    "total": {"$sum": 1},
                    "pending": {"$sum": {"$cond": [{"$eq": ["$status", "pending"]}, 1, 0]}},
                    "success": {"$sum": {"$cond": [{"$eq": ["$status", "success"]}, 1, 0]}},
                    "error": {"$sum": {"$cond": [{"$eq": ["$status", "error"]}, 1, 0]}},
                }
            },
            {"$sort": {"total": -1}}
        ]
        return list(self.collection.aggregate(pipeline))

    def update_status(self, url: str, status: str, error: Optional[str] = None) -> bool:
        update_data = {
            "status": status,
            "next_crawl": datetime.utcnow() if status == "pending" else None
        }

        if error:
            update_data["error"] = error

        if status == "success":
            update_data["last_crawled"] = datetime.utcnow()
            update_data["error"] = None
            update_data["attempts"] = 0

        if status == "error":
            doc = self.collection.find_one({"url": url})
            if doc:
                update_data["attempts"] = (doc.get("attempts", 0) or 0) + 1

        result = self.collection.update_one({"url": url}, {"$set": update_data})
        return result.modified_count > 0

    def delete(self, url: str) -> bool:
        return self.collection.delete_one({"url": url}).deleted_count > 0

    def delete_by_domain(self, domain: str) -> int:
        return self.collection.delete_many({"domain": domain}).deleted_count

    def get_links_by_domain(self, domain: str, status: Optional[str] = None) -> List[Dict]:
        query = {"domain": domain}
        if status:
            query["status"] = status
        return list(self.collection.find(query))

    def get_count_by_domain(self, domain: str) -> int:
        return self.collection.count_documents({"domain": domain})

    def _extract_domain(self, url: str) -> str:
        try:
            return urlparse(url).netloc.lower()
        except Exception as e:
            logger.error(f"Erro ao extrair domínio de {url}: {str(e)}")
            return ""
