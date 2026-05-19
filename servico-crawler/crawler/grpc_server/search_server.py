import re
import grpc
import logging
import sys
import os
from concurrent import futures
from urllib.parse import urlparse

sys.path.insert(0, os.path.dirname(__file__))

import crawler_pb2 as pb
import crawler_pb2_grpc as pb_grpc
from tracing import Span, RAGMetrics, extract_trace_id

logger = logging.getLogger(__name__)

STOPWORDS_PT = {
    "bom", "boa", "dia", "tarde", "noite", "olá", "oi", "hey", "hello",
    "o", "a", "os", "as", "um", "uma", "uns", "umas",
    "de", "do", "da", "dos", "das", "em", "no", "na", "nos", "nas",
    "por", "para", "com", "sem", "sob", "sobre", "entre", "até", "ao", "à",
    "aos", "às", "pelo", "pela", "pelos", "pelas", "num", "numa",
    "me", "meu", "minha", "meus", "minhas", "você", "voce", "eu", "ele",
    "ela", "nos", "nós", "eles", "elas", "isso", "isto", "aqui", "ali",
    "lá", "se", "que", "quem", "qual", "quais", "seu", "sua", "seus", "suas",
    "é", "são", "foi", "eram", "ser", "estar", "ter", "há",
    "pode", "podem", "poderia", "poderiam", "deve", "devem", "deveria",
    "seria", "seriam", "tem", "têm", "tinha", "tinham", "fazer", "faz",
    "feito", "sendo", "tendo", "existe", "existem",
    "e", "ou", "mas", "porém", "pois", "porque", "quando", "como",
    "onde", "enquanto", "portanto", "então", "assim", "também", "já",
    "ainda", "além", "disso", "nisso", "nisto",
    "o que", "como", "quando", "quanto", "quanta", "quantos", "quantas",
    "algum", "alguma", "alguns", "algumas", "nenhum", "nenhuma", "todo",
    "toda", "todos", "todas", "cada", "qualquer",
    "jogo", "jogos", "game", "games", "gaming",
    "influencia", "influenciam", "afeta", "afetam", "impacta", "impactam",
    "funciona", "funcionam", "ajuda", "ajudam", "serve", "servem",
    "significa", "significam", "devo", "devemos", "preciso", "precisamos",
    "quero", "queremos", "gostaria",
    "favor", "por favor", "obrigado", "obrigada", "tipo", "tal", "etc",
}

_MAX_TEXT_CHARS = 1200


def _extract_base_url(url: str) -> str:
    try:
        parsed = urlparse(url)
        return f"{parsed.scheme}://{parsed.netloc}"
    except Exception:
        return url


def _clean_query(query: str) -> str:
    cleaned = re.sub(r"[^\w\s]", " ", query.lower())
    words = [w for w in cleaned.split() if w not in STOPWORDS_PT and len(w) > 2]
    result = " ".join(words)
    return result if result else query


def _truncate(text: str, max_chars: int) -> str:
    if len(text) <= max_chars:
        return text
    truncated = text[:max_chars]
    last_space = truncated.rfind(" ")
    if last_space > max_chars * 0.8:
        truncated = truncated[:last_space]
    return truncated + "…"


class SearchServicer(pb_grpc.SearchServiceServicer):
    def __init__(self, embedding_service, page_repository=None, llm_client=None):
        self.embedding_service = embedding_service
        self.page_repository = page_repository
        self.llm_client = llm_client

    def Search(self, request, context):
        query = request.query
        limit = request.limit if request.limit > 0 else 5
        domain = request.domain or None

        if not query:
            context.set_code(grpc.StatusCode.INVALID_ARGUMENT)
            context.set_details("query não pode ser vazia")
            return pb.SearchResponse()

        # ── Extrai trace_id do metadata gRPC ──────────────────────────────
        trace_id = extract_trace_id(context)
        metrics = RAGMetrics(trace_id=trace_id)
        logger.info("[trace:%s] query recebida: %r", trace_id, query)

        # ── 1. Qdrant: embedding + busca vetorial ─────────────────────────
        try:
            search_query = _clean_query(query)
            logger.info("[trace:%s] query original: %r | limpa: %r", trace_id, query, search_query)

            span = Span("qdrant retrieval")
            raw_results = self.embedding_service.search(search_query, limit=limit, domain=domain)
            metrics.retrieval_ms = span.end()
            logger.info("[trace:%s] qdrant: %d resultado(s) em %.0fms",
                        trace_id, len(raw_results), metrics.retrieval_ms)

        except Exception as e:
            logger.error("[trace:%s] qdrant error: %s", trace_id, e)
            context.set_code(grpc.StatusCode.INTERNAL)
            context.set_details(str(e))
            return pb.SearchResponse()

        # ── 2. MongoDB: fetch texto completo ──────────────────────────────
        span = Span("mongo fetch")
        context_parts = []
        for r in raw_results:
            url = r.get("url", "")
            full_text = self._fetch_full_text(url)
            text = full_text or r.get("chunk_text", "")
            if text:
                context_parts.append((url, _truncate(text, _MAX_TEXT_CHARS)))
        metrics.mongo_fetch_ms = span.end()
        logger.info("[trace:%s] mongo fetch: %.0fms", trace_id, metrics.mongo_fetch_ms)

        # ── 3. Construção do prompt ───────────────────────────────────────
        span = Span("prompt build")
        context_chunks = "\n\n---\n\n".join(
            f"[Fonte: {url}]\n{text}" for url, text in context_parts
        )
        metrics.prompt_build_ms = span.end()

        # ── 4. LLM: geração da resposta ───────────────────────────────────
        span = Span("llm inference")
        answer = self._generate_answer(query, context_parts, context_chunks)
        metrics.llm_ms = span.end()
        logger.info("[trace:%s] llm: %.0fms", trace_id, metrics.llm_ms)

        # ── Métricas finais ───────────────────────────────────────────────
        metrics.compute_total()
        metrics.log_summary(query)

        results = [
            pb.SearchResult(
                score=r.get("score", 0.0),
                url=r.get("url", ""),
                chunk_text=r.get("chunk_text", ""),
                chunk_index=r.get("chunk_index", 0),
                total_chunks=r.get("total_chunks", 0),
            )
            for r in raw_results
        ]

        return pb.SearchResponse(
            query=query,
            answer=answer,
            results_count=len(results),
            results=results,
            metrics_json=metrics.to_json(),
        )

    def _fetch_full_text(self, url: str) -> str:
        if not self.page_repository:
            return ""
        try:
            page = self.page_repository.get_by_url(url)
            if page and page.get("text_content"):
                return page["text_content"].strip()
            base_url = _extract_base_url(url)
            if base_url != url:
                page = self.page_repository.get_by_url(base_url)
                if page and page.get("text_content"):
                    return page["text_content"].strip()
            return ""
        except Exception as e:
            logger.error("Erro ao buscar texto completo para %s: %s", url, e)
            return ""

    def _generate_answer(self, query: str, context_parts: list, context_chunks: str) -> str:
        if self.llm_client:
            try:
                prompt = (
                    f"Contexto:\n{context_chunks}\n\n"
                    f"Pergunta: {query}\n\nResposta:"
                )
                return self.llm_client.complete(prompt)
            except Exception as e:
                logger.error("Erro no LLM: %s", e)

        if not context_parts:
            return "Nenhuma informação encontrada para essa pergunta."

        lines = ["Encontrei as seguintes informações:\n"]
        for i, (url, text) in enumerate(context_parts, 1):
            lines.append(f"**Fonte {i}:** {url}\n\n{text}\n")
            if i < len(context_parts):
                lines.append("---\n")
        lines.append("\n> Para mais detalhes, acesse os links acima.")
        return "\n".join(lines)


def serve_search(embedding_service, page_repository=None, llm_client=None, port: int = 50052):
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    pb_grpc.add_SearchServiceServicer_to_server(
        SearchServicer(embedding_service, page_repository=page_repository, llm_client=llm_client),
        server,
    )
    server.add_insecure_port(f"[::]:{port}")
    server.start()
    return server
