"""
tracing.py — utilitários de tracing distribuído (sem dependência externa).
Usado por search_server.py (RAG) e page_crawler.py (crawler).
"""
from __future__ import annotations

import json
import logging
import time
from dataclasses import asdict, dataclass
from typing import Optional

logger = logging.getLogger(__name__)

# Header/metadata key (minúsculo — padrão gRPC metadata).
TRACE_ID_HEADER = "x-trace-id"


def extract_trace_id(grpc_context) -> str:
    """Extrai o trace_id do metadata gRPC; retorna '' se ausente."""
    try:
        meta = dict(grpc_context.invocation_metadata())
        return meta.get(TRACE_ID_HEADER, "")
    except Exception:
        return ""


class Span:
    """Cronômetro para uma etapa individual."""

    def __init__(self, name: str) -> None:
        self.name = name
        self._start = time.perf_counter()
        self._elapsed_ms: Optional[float] = None

    def end(self) -> float:
        if self._elapsed_ms is None:
            self._elapsed_ms = (time.perf_counter() - self._start) * 1000
        return self._elapsed_ms

    @property
    def ms(self) -> float:
        if self._elapsed_ms is None:
            return (time.perf_counter() - self._start) * 1000
        return self._elapsed_ms


@dataclass
class RAGMetrics:
    """Métricas de uma query RAG — serializada em metrics_json no proto."""
    trace_id: str = ""
    retrieval_ms: float = 0.0      # Qdrant embedding + busca vetorial
    mongo_fetch_ms: float = 0.0    # fetch texto completo das fontes
    prompt_build_ms: float = 0.0   # construção do prompt
    llm_ms: float = 0.0            # chamada ao LLM
    internal_total_ms: float = 0.0 # soma de todas as etapas

    def compute_total(self) -> None:
        self.internal_total_ms = (
            self.retrieval_ms
            + self.mongo_fetch_ms
            + self.prompt_build_ms
            + self.llm_ms
        )

    def to_json(self) -> str:
        return json.dumps(asdict(self))

    def log_summary(self, query: str) -> None:
        logger.info(
            "\n%s\n"
            "  📊  TRACE %s — query: %r\n"
            "  ┌────────────────────────────────────────────────────────\n"
            "  │  Qdrant retrieval:        %10.3f ms\n"
            "  │  MongoDB fetch:           %10.3f ms\n"
            "  │  Prompt build:            %10.3f ms\n"
            "  │  LLM inference:           %10.3f ms\n"
            "  │  ─────────────────────────────────────────────────────\n"
            "  │  TOTAL Python internal:   %10.3f ms\n"
            "  └────────────────────────────────────────────────────────\n"
            "%s",
            "=" * 64,
            self.trace_id, query,
            self.retrieval_ms, self.mongo_fetch_ms,
            self.prompt_build_ms, self.llm_ms,
            self.internal_total_ms,
            "=" * 64,
        )


@dataclass
class CrawlerMetrics:
    """Métricas de uma operação de crawl."""
    trace_id: str = ""
    http_fetch_ms: float = 0.0
    html_parse_ms: float = 0.0
    embedding_ms: float = 0.0
    qdrant_upsert_ms: float = 0.0
    mongo_save_ms: float = 0.0
    internal_total_ms: float = 0.0

    def compute_total(self) -> None:
        self.internal_total_ms = (
            self.http_fetch_ms
            + self.html_parse_ms
            + self.embedding_ms
            + self.qdrant_upsert_ms
            + self.mongo_save_ms
        )

    def log_summary(self, url: str) -> None:
        logger.info(
            "[trace:%s] crawler url=%r http=%.0fms parse=%.0fms "
            "embed=%.0fms qdrant=%.0fms mongo=%.0fms total=%.0fms",
            self.trace_id, url,
            self.http_fetch_ms, self.html_parse_ms,
            self.embedding_ms, self.qdrant_upsert_ms,
            self.mongo_save_ms, self.internal_total_ms,
        )
