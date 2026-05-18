import logging
import uuid
from sentence_transformers import SentenceTransformer
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct, Filter, FieldCondition, MatchValue, FilterSelector
from langchain.text_splitter import RecursiveCharacterTextSplitter
import hashlib
import numpy as np

logger = logging.getLogger(__name__)


class EmbeddingService:
    def __init__(self, qdrant_url="http://localhost:6333", model_name="all-MiniLM-L6-v2"):
        self.client = QdrantClient(url=qdrant_url)
        self.model = SentenceTransformer(model_name)
        self.collection_name = "page_embeddings"
        self.splitter = RecursiveCharacterTextSplitter(
            chunk_size=1000,
            chunk_overlap=200,
            separators=["\n\n", "\n", " ", ""]
        )
        self._ensure_collection()

    def _ensure_collection(self):
        try:
            self.client.get_collection(self.collection_name)
        except:
            logger.info(f"Criando collection {self.collection_name}")
            self.client.create_collection(
                collection_name=self.collection_name,
                vectors_config=VectorParams(size=384, distance=Distance.COSINE)
            )

    def process_page(self, url: str, text_content: str, metadata: dict = None) -> dict:
        if not text_content or not text_content.strip():
            return {"success": False, "error": "Conteúdo vazio", "chunks_count": 0}

        try:
            chunks = self.splitter.split_text(text_content)
            if not chunks:
                return {"success": False, "error": "Nenhum chunk gerado", "chunks_count": 0}

            embeddings = self.model.encode(chunks)
            points = []
            for idx, (chunk_text, embedding) in enumerate(zip(chunks, embeddings)):
                chunk_id = hashlib.md5(f"{url}_{idx}".encode()).hexdigest()[:16]
                point_id = int(uuid.uuid5(uuid.NAMESPACE_URL, f"{url}_{idx}").int % (2**63 - 1))
                if isinstance(embedding, np.ndarray):
                    embedding = embedding.tolist()
                points.append(PointStruct(
                    id=point_id,
                    vector=embedding,
                    payload={
                        "url": url,
                        "chunk_id": chunk_id,
                        "chunk_index": idx,
                        "chunk_text": chunk_text,
                        "total_chunks": len(chunks),
                        **(metadata or {})
                    }
                ))

            self.client.upsert(self.collection_name, points=points)
            logger.info(f"✓ {url} ({len(chunks)} chunks)")
            return {"success": True, "url": url, "chunks_count": len(chunks)}

        except Exception as e:
            logger.error(f"✗ {url}: {str(e)}")
            return {"success": False, "error": str(e), "url": url}

    def process_pending_pages(self, page_repository, batch_size: int = 50) -> dict:
        logger.info("Processando embeddings para páginas pendentes...")
        processed = 0
        failed = 0
        skip = 0

        while True:
            pages = page_repository.get_pending_embeddings(limit=batch_size, skip=skip)
            if not pages:
                break

            for page in pages:
                url = page.get("url")
                text_content = page.get("text_content", "")
                page_repository.set_embedding_processing(url)

                result = self.process_page(url, text_content, {
                    "domain": page.get("domain"),
                    "title": page.get("title"),
                })

                if result["success"]:
                    processed += 1
                    page_repository.set_embedding_completed(url, result["chunks_count"])
                else:
                    failed += 1
                    page_repository.set_embedding_failed(url, result.get("error", "Erro desconhecido"))

            skip += batch_size

        logger.info(f"Embedding concluído: {processed} processadas, {failed} falhadas")
        return {"processed": processed, "failed": failed, "total": processed + failed}

    def retry_failed_pages(self, page_repository, batch_size: int = 50) -> dict:
        logger.info("Reprocessando páginas que falharam...")
        reset_count = page_repository.reset_failed_embeddings()
        logger.info(f"Resetadas {reset_count} páginas")
        return self.process_pending_pages(page_repository, batch_size)

    def delete_by_url(self, url: str) -> int:
        """Remove todos os pontos do Qdrant associados a uma URL."""
        try:
            result = self.client.delete(
                collection_name=self.collection_name,
                points_selector=FilterSelector(
                    filter=Filter(
                        must=[FieldCondition(key="url", match=MatchValue(value=url))]
                    )
                ),
            )
            logger.info(f"Embeddings removidos para {url}: {result}")
            return 1
        except Exception as e:
            logger.error(f"Erro ao deletar embeddings de {url}: {e}")
            return 0

    def delete_by_domain(self, domain: str) -> int:
        """Remove todos os pontos do Qdrant associados a um domínio."""
        try:
            result = self.client.delete(
                collection_name=self.collection_name,
                points_selector=FilterSelector(
                    filter=Filter(
                        must=[FieldCondition(key="domain", match=MatchValue(value=domain))]
                    )
                ),
            )
            logger.info(f"Embeddings removidos para domínio {domain}: {result}")
            return 1
        except Exception as e:
            logger.error(f"Erro ao deletar embeddings do domínio {domain}: {e}")
            return 0

    def search(self, query: str, limit: int = 5, domain: str = None) -> list:
        if not self.client or not self.model:
            logger.error("Qdrant não disponível para busca")
            return []
        try:
            try:
                info = self.client.get_collection(self.collection_name)
                logger.info(f"Collection '{self.collection_name}' tem {info.points_count} pontos")
            except Exception as e:
                logger.error(f"Collection '{self.collection_name}' não existe: {e}")
                return []

            query_embedding = self.model.encode(query)
            if isinstance(query_embedding, np.ndarray):
                query_embedding = query_embedding.tolist()

            logger.info(f"Buscando: '{query}' | Domain filter: {domain}")

            query_filter = None
            if domain:
                query_filter = Filter(
                    must=[FieldCondition(key="domain", match=MatchValue(value=domain))]
                )

            results = self.client.query_points(
                collection_name=self.collection_name,
                query=query_embedding,
                limit=limit,
                query_filter=query_filter,
                score_threshold=0.1
            ).points

            logger.info(f"Busca retornou {len(results)} resultados")
            return [
                {
                    "score": r.score,
                    "url": (r.payload or {}).get("url"),
                    "chunk_text": (r.payload or {}).get("chunk_text"),
                    "chunk_index": (r.payload or {}).get("chunk_index"),
                    "total_chunks": (r.payload or {}).get("total_chunks"),
                }
                for r in results
            ]

        except Exception as e:
            logger.error(f"Erro na busca: {str(e)}", exc_info=True)
            return []
