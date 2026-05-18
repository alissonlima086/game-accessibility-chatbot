import hashlib
import logging
from typing import Optional

logger = logging.getLogger(__name__)


class ContentHasher:
    @staticmethod
    def calculate_hash(content: str) -> str:
        if not content:
            return ""
        try:
            normalized = " ".join(content.split())
            return hashlib.sha256(normalized.encode("utf-8")).hexdigest()
        except Exception as e:
            logger.error(f"Erro ao calcular hash: {str(e)}")
            return ""

    @staticmethod
    def content_changed(old_hash: Optional[str], new_content: str) -> bool:
        if not old_hash:
            return True
        new_hash = ContentHasher.calculate_hash(new_content)
        changed = old_hash != new_hash
        logger.debug(f"Hash {'alterado' if changed else 'igual'}: {old_hash[:16]}...")
        return changed
