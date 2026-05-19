import re
import logging
import os
from typing import List, Optional, Dict, Any
from urllib.parse import urlparse
from datetime import datetime

from crawlers.link_crawler import LinkCrawler
from crawlers.page_crawler import PageCrawler
from repository.link_repository import LinkRepository
from repository.page_repository import PageRepository
from service.embedding_service import EmbeddingService
from service.llm_service import build_llm_client
from config import settings

logger = logging.getLogger(__name__)


def _extract_base_url(url: str) -> str:
    try:
        parsed = urlparse(url)
        return f"{parsed.scheme}://{parsed.netloc}"
    except Exception:
        return url


STOPWORDS_PT = {
    # Saudações
    "bom", "boa", "dia", "tarde", "noite", "olá", "oi", "hey", "hello",
    # Artigos
    "o", "a", "os", "as", "um", "uma", "uns", "umas",
    # Preposições
    "de", "do", "da", "dos", "das", "em", "no", "na", "nos", "nas",
    "por", "para", "com", "sem", "sob", "sobre", "entre", "até", "ao", "à",
    "aos", "às", "pelo", "pela", "pelos", "pelas", "num", "numa",
    # Pronomes
    "me", "meu", "minha", "meus", "minhas", "você", "voce", "eu", "ele",
    "ela", "nos", "nós", "eles", "elas", "isso", "isto", "aqui", "ali",
    "lá", "se", "que", "quem", "qual", "quais", "seu", "sua", "seus", "suas",
    # Verbos auxiliares / comuns
    "é", "são", "foi", "eram", "ser", "estar", "ter", "há",
    "pode", "podem", "poderia", "poderiam", "deve", "devem", "deveria",
    "seria", "seriam", "tem", "têm", "tinha", "tinham", "fazer", "faz",
    "feito", "sendo", "tendo", "existe", "existem",
    # Conjunções / conectivos
    "e", "ou", "mas", "porém", "pois", "porque", "quando", "como",
    "onde", "enquanto", "portanto", "então", "assim", "também", "já",
    "ainda", "além", "disso", "nisso", "nisto",
    # Interrogativos / indefinidos
    "algum", "alguma", "alguns", "algumas", "nenhum", "nenhuma", "todo",
    "toda", "todos", "todas", "cada", "qualquer",
    # Domínio — jogos
    "jogo", "jogos", "game", "games", "gaming",
    # Verbos de pergunta genéricos
    "influencia", "influenciam", "afeta", "afetam", "impacta", "impactam",
    "funciona", "funcionam", "ajuda", "ajudam", "serve", "servem",
    "significa", "significam", "devo", "devemos", "preciso", "precisamos",
    "quero", "queremos", "gostaria",
    # Outros
    "favor", "obrigado", "obrigada", "tipo", "tal", "etc",
}


def _clean_query(query: str) -> str:
    cleaned = re.sub(r"[^\w\s]", " ", query.lower())
    words = [w for w in cleaned.split() if w not in STOPWORDS_PT and len(w) > 2]
    result = " ".join(words)
    return result if result else query


class CrawlerService:
    def __init__(self, db):
        self.db = db
        self.link_repo = LinkRepository(db)
        self.page_repo = PageRepository(db)
        self.link_extractor = LinkCrawler()
        self.page_crawler = PageCrawler()
        self.embedding_service = EmbeddingService(
            qdrant_url=os.getenv("QDRANT_URL", "http://localhost:6333"),
            model_name=os.getenv("EMBEDDING_MODEL", "all-MiniLM-L6-v2")
        )
        self.llm_client = build_llm_client()
        self.stats = {
            "links": {"added": 0, "duplicated": 0, "extraction_errors": 0, "robots_blocked": 0},
            "pages": {"crawled": 0, "unchanged": 0, "changed": 0, "crawl_errors": 0, "limit_reached": 0}
        }

    def add_links(self, urls: List[str]) -> Dict[str, Any]:
        result = self.link_repo.add_links([str(url) for url in urls], depth=0)
        logger.info(f"URLs adicionadas: {result}")
        return result

    def extract_links_from_pending(self, limit: int = 100) -> Dict[str, Any]:
        pending_links = self.link_repo.get_pending_by_status("pending", limit=limit)

        if not pending_links:
            logger.info("Nenhum link pendente para extração")
            return {"processed": 0, "links_added": 0, "robots_blocked": 0, "errors": 0, "stats": self.stats["links"]}

        logger.info(f"Iniciando extração de links de {len(pending_links)} URLs")
        base_domain = self._get_root_domain(urlparse(pending_links[0]["url"]).netloc)

        for link_doc in pending_links:
            url = link_doc["url"]
            current_depth = link_doc.get("depth", 0)

            result = self.link_extractor.extract_links_from_url(
                url=url, current_depth=current_depth, target_domain=base_domain
            )

            if result["success"]:
                new_links = result["links"]
                if new_links:
                    add_result = self.link_repo.add_links(new_links, depth=result["depth"])
                    self.stats["links"]["added"] += add_result.get("added", 0)
                    self.stats["links"]["duplicated"] += add_result.get("duplicated", 0)
                    logger.info(f"Adicionados {add_result.get('added', 0)} novos links de {url}")
            elif result["robots_blocked"]:
                self.stats["links"]["robots_blocked"] += 1
                logger.warning(f"Link bloqueado por robots.txt: {url}")
            else:
                self.stats["links"]["extraction_errors"] += 1
                self.link_repo.update_status(url, "error", result["error"])
                logger.error(f"Erro ao extrair links de {url}: {result['error']}")

        logger.info(
            f"Extração finalizada | Adicionados: {self.stats['links']['added']} | "
            f"Bloqueados: {self.stats['links']['robots_blocked']} | "
            f"Erros: {self.stats['links']['extraction_errors']}"
        )

        return {
            "processed": len(pending_links),
            "links_added": self.stats["links"]["added"],
            "robots_blocked": self.stats["links"]["robots_blocked"],
            "errors": self.stats["links"]["extraction_errors"],
            "stats": self.stats["links"]
        }

    def crawl_pending_pages(self, limit: int = 50, max_pages: Optional[int] = None) -> Dict[str, Any]:
        pending_pages = self.link_repo.get_pending_for_crawl(limit=limit)

        if not pending_pages:
            logger.info("Nenhuma página pendente de crawl")
            return {"crawled": 0, "unchanged": 0, "changed": 0, "errors": 0, "limit_reached": False, "stats": self.stats["pages"]}

        logger.info(f"Iniciando crawl de {len(pending_pages)} páginas")
        # Limpa URLs visitadas para permitir re-crawl correto entre chamadas
        self.page_crawler.reset_session()

        pages_crawled = 0
        pages_limit = max_pages or settings.max_total_pages
        limit_reached = False

        for link_doc in pending_pages:
            if pages_crawled >= pages_limit:
                logger.warning(f"Limite de páginas ({pages_limit}) atingido.")
                limit_reached = True
                break

            url = link_doc["url"]
            existing_page = self.page_repo.get_by_url(url)
            previous_hash = existing_page.get("content_hash") if existing_page else None

            result = self.page_crawler.crawl_page(url, previous_hash=previous_hash)

            if not result["success"]:
                self.stats["pages"]["crawl_errors"] += 1
                error_type = result.get("error_type", "")
                if error_type == "robots_blocked":
                    self.link_repo.update_status(url, "blocked", result["error"])
                    logger.warning(f"Bloqueado por robots.txt: {url}")
                else:
                    self.link_repo.update_status(url, "error", result["error"])
                    logger.error(f"Erro ao crawlear {url}: {result['error']}")
                continue

            pages_crawled += 1

            if not result["changed"]:
                self.stats["pages"]["unchanged"] += 1
                self.link_repo.update_status(url, "success")
                self.page_repo.update_last_crawled(url, result["crawled_at"])
                logger.info(f"Página sem mudanças: {url}")
                continue

            self.stats["pages"]["changed"] += 1
            self._process_crawled_page(url, result)
            self.link_repo.update_status(url, "success")
            logger.info(f"Página processada: {url}")

        self.stats["pages"]["crawled"] = pages_crawled
        self.stats["pages"]["limit_reached"] = limit_reached

        logger.info(
            f"Crawl finalizado | Crawled: {pages_crawled} | Mudou: {self.stats['pages']['changed']} | "
            f"Sem mudança: {self.stats['pages']['unchanged']} | Erros: {self.stats['pages']['crawl_errors']}"
        )

        crawl_response = {
            "crawled": pages_crawled,
            "unchanged": self.stats["pages"]["unchanged"],
            "changed": self.stats["pages"]["changed"],
            "errors": self.stats["pages"]["crawl_errors"],
            "limit_reached": limit_reached,
            "stats": self.stats["pages"]
        }

        if self.stats["pages"]["changed"] > 0:
            logger.info("Iniciando processamento de embeddings...")
            embed_result = self.embedding_service.process_pending_pages(self.page_repo)
            crawl_response["embeddings"] = embed_result
            logger.info(f"Embeddings: {embed_result['processed']} processadas, {embed_result['failed']} falhadas")

        return crawl_response

    def _process_crawled_page(self, url: str, crawl_result: Dict[str, Any]):
        content = crawl_result["content"]
        page_doc = {
            "url": url,
            "domain": self._get_root_domain(urlparse(url).netloc),
            "content_hash": crawl_result["hash"],
            "title": content.get("title"),
            "description": content.get("description"),
            "text_content": content.get("text_content"),
            "summary": content.get("summary"),
            "word_count": content.get("word_count", 0),
            "keywords": content.get("keywords", []),
            "language": content.get("language"),
            "status_code": content.get("status_code", 200),
            "crawled_at": crawl_result["crawled_at"],
            "updated_at": datetime.utcnow().isoformat(),
            "embedding_status": "pending",
            "chunks_count": 0,
        }
        self.page_repo.save_or_update(url, page_doc)

    def process_embeddings(self) -> Dict[str, Any]:
        logger.info("Trigger manual de processamento de embeddings")
        return self.embedding_service.process_pending_pages(self.page_repo)

    def retry_embedding_failures(self) -> Dict[str, Any]:
        logger.info("Reprocessando páginas com falha em embedding")
        return self.embedding_service.retry_failed_pages(self.page_repo)

    def get_embedding_stats(self) -> Dict[str, int]:
        return self.page_repo.get_embedding_stats()

    def search_embeddings(self, query: str, limit: int = 5, domain: str = None) -> Dict[str, Any]:
        search_query = _clean_query(query)
        logger.info(f"Query original: '{query}' | Query limpa: '{search_query}'")
        raw_results = self.embedding_service.search(search_query, limit, domain)

        context_parts = []
        for r in raw_results:
            url = r.get("url", "")
            full_text = self._fetch_full_text(url)
            source = full_text if full_text else r.get("chunk_text", "")
            context_parts.append(f"[Fonte: {url}]\n{source}")

        context = "\n\n---\n\n".join(context_parts)
        answer = self._generate_answer(query, context)

        return {
            "answer": answer,
            "results": raw_results,
        }


    def _fetch_full_text(self, url: str) -> str:
        try:
            page = self.page_repo.get_by_url(url)
            if page and page.get("text_content"):
                return page["text_content"].strip()

            base_url = _extract_base_url(url)
            if base_url != url:
                page = self.page_repo.get_by_url(base_url)
                if page and page.get("text_content"):
                    return page["text_content"].strip()

            return ""
        except Exception as e:
            logger.error(f"Erro ao buscar texto completo para {url}: {e}")
            return ""

    def _generate_answer(self, query: str, context: str) -> str:
        if not self.llm_client:
            return context.split("\n\n---\n\n")[0] if context else "Nenhuma informação encontrada."
        try:
            prompt = (
                f"Contexto:\n{context}\n\n"
                f"Pergunta: {query}\n\nResposta:"
            )
            return self.llm_client.complete(prompt)
        except Exception as e:
            logger.error(f"Erro no LLM: {e}")
            return "Erro ao gerar resposta."

    def _get_root_domain(self, domain: str) -> str:
        parts = domain.split(".")
        return ".".join(parts[-2:])

    def reset_session(self):
        self.link_extractor.reset_session()
        self.page_crawler.reset_session()

    def clear_robots_cache(self):
        self.link_extractor.clear_robots_cache()
        self.page_crawler.clear_robots_cache()

    def get_links_status(self) -> Dict[str, Any]:
        return self.link_repo.get_status()

    def get_links_status_by_domain(self) -> List[Dict[str, Any]]:
        return self.link_repo.get_status_by_domain()

    def get_pages(self, limit: int = 10, skip: int = 0) -> List[Dict[str, Any]]:
        return self.page_repo.get_pages(limit, skip)

    def get_pages_by_domain(self, domain: str, limit: int = 10, skip: int = 0) -> List[Dict[str, Any]]:
        return self.page_repo.get_pages_by_domain(domain, limit, skip)

    def get_page_detail(self, url: str) -> Optional[Dict[str, Any]]:
        page = self.page_repo.get_by_url(url)
        if page:
            page.pop("_id", None)
        return page

    def get_domain_stats(self, domain: str) -> Dict[str, Any]:
        links = self.link_repo.get_links_by_domain(domain)
        pages_count = self.page_repo.count_by_domain(domain)
        return {
            "domain": domain,
            "total_links": len(links),
            "total_pages_crawled": pages_count,
            "links_by_status": {
                status: len([l for l in links if l.get("status") == status])
                for status in ("pending", "extracted", "success", "error", "blocked")
            }
        }

    def delete_link(self, url: str):
        self.link_repo.delete(url)
        self.page_repo.delete_by_url(url)
        # Remove embeddings do Qdrant para a URL deletada
        try:
            self.embedding_service.delete_by_url(url)
        except Exception as e:
            logger.warning(f"Erro ao remover embedding de {url}: {e}")

    def delete_domain(self, domain: str) -> Dict[str, int]:
        result = {
            "links_deleted": self.link_repo.delete_by_domain(domain),
            "pages_deleted": self.page_repo.delete_by_domain(domain),
        }
        try:
            self.embedding_service.delete_by_domain(domain)
        except Exception as e:
            logger.warning(f"Erro ao remover embeddings do domínio {domain}: {e}")
        return result

    def get_stats(self) -> Dict[str, Any]:
        return {"links": self.stats["links"], "pages": self.stats["pages"]}
    
    def crawl_single_page(self, url: str) -> dict:
        try:
            # Garante que o link existe no banco antes de crawlear
            self.link_repo.add_links([url], depth=0)
            # Limpa visited_urls para que a URL possa ser visitada
            self.page_crawler.reset_session()
            result = self.page_crawler.crawl_page(url)
            if not result or not result.get("success"):
                err = result.get("error", "falha desconhecida") if result else "sem resposta"
                error_type = result.get("error_type", "") if result else ""
                if error_type == "robots_blocked":
                    self.link_repo.update_status(url, "blocked", err)
                else:
                    self.link_repo.update_status(url, "error", err)
                return {"success": False, "message": f"Erro ao crawlear: {err}", "title": ""}

            self._process_crawled_page(url, result)
            self.link_repo.update_status(url, "success")
            title = ""
            if result.get("content"):
                title = result["content"].get("title", "") or ""
            return {
                "success": True,
                "message": "Página crawleada com sucesso",
                "title": title,
            }
        except Exception as e:
            logger.exception(f"Erro ao crawlear página única {url}: {e}")
            return {"success": False, "message": str(e), "title": ""}

    def list_links(self, limit: int = 20, skip: int = 0, status: str = None, url_filter: str = None) -> dict:
        query = {}
        if status:
            query["status"] = status
        if url_filter:
            query["url"] = {"$regex": url_filter, "$options": "i"}

        total = self.link_repo.collection.count_documents(query)
        docs = list(
            self.link_repo.collection.find(query, {"_id": 0})
            .sort("created_at", -1)
            .skip(skip)
            .limit(limit)
        )
        for d in docs:
            for field in ("created_at", "updated_at", "last_crawled", "next_crawl"):
                if field in d and d[field] is not None:
                    d[field] = str(d[field])
        return {"links": docs, "total": total}
    def rescan_all(self) -> int:
        """Reseta todos os links para 'pending' para reprocessamento completo."""
        result = self.link_repo.collection.update_many(
            {},
            {"$set": {"status": "pending", "error": None}}
        )
        count = result.modified_count
        logger.info("RescanAll: %d link(s) marcados como pending", count)
        return count
