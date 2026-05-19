from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import logging
from datetime import datetime
from database.connection import mongo_connection
from service.crawler_service import CrawlerService
from pydantic import BaseModel
from grpc_server.admin_server import serve_admin
from grpc_server.search_server import serve_search
from service.llm_service import build_llm_client
import os

from schemas import (
    LinkCreate, LinkResponse, PageResponse, PageDetailResponse,
    LinkStatusResponse, CrawlResponse
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

crawler_service: CrawlerService = None


class SearchRequest(BaseModel):
    query: str
    limit: int = 5
    domain: str | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global crawler_service
    logger.info("Iniciando WebCrawler")
    try:
        mongo_connection.connect()
        db = mongo_connection.get_db()
        crawler_service = CrawlerService(db)

        admin_port = int(os.getenv("GRPC_ADMIN_PORT", "50051"))
        search_port = int(os.getenv("GRPC_SEARCH_PORT", "50052"))
        grpc_admin = serve_admin(crawler_service, port=admin_port)
        llm_client = build_llm_client()
        grpc_search = serve_search(
            crawler_service.embedding_service,
            page_repository=crawler_service.page_repo,
            llm_client=llm_client,
            port=search_port,
        )

        logger.info("Aplicação iniciada com sucesso")
    except Exception as e:
        logger.error(f"Erro ao iniciar a aplicação: {e}")
        raise

    yield

    try:
        grpc_admin.stop(grace=5)
        grpc_search.stop(grace=5)
        mongo_connection.disconnect()
        logger.info("Aplicação desligada com sucesso")
    except Exception as e:
        logger.error(f"Erro ao desligar a aplicação: {e}")


app = FastAPI(title="WebCrawler API - TCC2", version="0.1.0", lifespan=lifespan)


@app.post("/api/links", response_model=LinkResponse, tags=["Links"])
async def add_links(payload: LinkCreate):
    if not payload.urls:
        raise HTTPException(400, "Lista de URLs vazia")
    try:
        return LinkResponse(**crawler_service.add_links(payload.urls))
    except Exception as e:
        logger.error(f"Erro ao adicionar links: {e}")
        raise HTTPException(500, str(e))


@app.post("/api/links/extract", tags=["Links"])
async def extract_links(limit: int = Query(100, ge=1, le=1000)):
    try:
        return crawler_service.extract_links_from_pending(limit=limit)
    except Exception as e:
        logger.error(f"Erro ao extrair links: {e}")
        raise HTTPException(500, str(e))


@app.get("/api/links/status", response_model=LinkStatusResponse, tags=["Links"])
async def get_links_status():
    try:
        return LinkStatusResponse(**crawler_service.get_links_status())
    except Exception as e:
        logger.error(f"Erro ao obter status: {e}")
        raise HTTPException(500, str(e))


@app.get("/api/links/status/by-domain", tags=["Links"])
async def get_links_status_by_domain():
    try:
        return crawler_service.get_links_status_by_domain()
    except Exception as e:
        logger.error(f"Erro ao obter status por domínio: {e}")
        raise HTTPException(500, str(e))


@app.delete("/api/links/{url:path}", tags=["Links"])
async def delete_link(url: str):
    try:
        crawler_service.delete_link(url)
        return {"message": f"Link '{url}' deletado com sucesso"}
    except Exception as e:
        logger.error(f"Erro ao deletar link: {e}")
        raise HTTPException(500, str(e))


def _format_page_response(page: dict) -> PageResponse:
    return PageResponse(
        url=page["url"],
        title=page.get("title"),
        description=page.get("description"),
        status_code=page.get("status_code"),
        word_count=page.get("word_count", 0),
        crawled_at=page["crawled_at"],
    )


@app.get("/api/pages", response_model=list[PageResponse], tags=["Páginas"])
async def list_pages(limit: int = Query(10, ge=1, le=100), skip: int = Query(0, ge=0)):
    try:
        return [_format_page_response(p) for p in crawler_service.get_pages(limit, skip)]
    except Exception as e:
        logger.error(f"Erro ao listar páginas: {e}")
        raise HTTPException(500, str(e))


@app.get("/api/pages/domain/{domain}", response_model=list[PageResponse], tags=["Páginas"])
async def list_pages_by_domain(domain: str, limit: int = Query(10, ge=1, le=100), skip: int = Query(0, ge=0)):
    try:
        return [_format_page_response(p) for p in crawler_service.get_pages_by_domain(domain, limit, skip)]
    except Exception as e:
        logger.error(f"Erro ao listar páginas do domínio: {e}")
        raise HTTPException(500, str(e))


@app.get("/api/pages/{url:path}", response_model=PageDetailResponse, tags=["Páginas"])
async def get_page_detail(url: str):
    try:
        page = crawler_service.get_page_detail(url)
        if not page:
            raise HTTPException(404, "Página não encontrada")
        return PageDetailResponse(**page)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao obter página: {e}")
        raise HTTPException(500, str(e))


@app.get("/api/domains/{domain}/stats", tags=["Domínios"])
async def get_domain_stats(domain: str):
    try:
        return crawler_service.get_domain_stats(domain)
    except Exception as e:
        logger.error(f"Erro ao obter estatísticas do domínio: {e}")
        raise HTTPException(500, str(e))


@app.delete("/api/domains/{domain}", tags=["Domínios"])
async def delete_domain(domain: str):
    try:
        result = crawler_service.delete_domain(domain)
        return {"message": f"Domínio '{domain}' deletado com sucesso", **result}
    except Exception as e:
        logger.error(f"Erro ao deletar domínio: {e}")
        raise HTTPException(500, str(e))


@app.post("/api/crawl", response_model=CrawlResponse, tags=["Crawl"])
async def trigger_crawl(limit: int = Query(50, ge=1, le=1000)):
    try:
        crawler_service.crawl_pending_pages(limit=limit)
        return CrawlResponse(message="Crawling de páginas pendentes executado", timestamp=datetime.utcnow())
    except Exception as e:
        logger.error(f"Erro no crawl manual: {e}")
        raise HTTPException(500, str(e))


@app.post("/api/crawl/rescan", tags=["Crawl"])
async def rescan_all(limit: int = Query(500, ge=1, le=5000)):
    """Reescan completo: reseta todos os links para pending e dispara crawl em background."""
    try:
        count = crawler_service.rescan_all()
        import threading
        threading.Thread(
            target=crawler_service.crawl_pending_pages,
            kwargs={"limit": limit},
            daemon=True,
        ).start()
        return {"message": f"Reescan iniciado: {count} link(s) marcados para reprocessamento"}
    except Exception as e:
        logger.error(f"Erro no rescan: {e}")
        raise HTTPException(500, str(e))


@app.post("/api/search/embeddings", tags=["Search"])
async def search_embeddings(request: SearchRequest):
    try:
        results = crawler_service.search_embeddings(
            query=request.query, limit=request.limit, domain=request.domain or None
        )
        return {"query": request.query, "results_count": len(results), "results": results}
    except Exception as e:
        logger.error(f"Erro na busca: {e}")
        raise HTTPException(500, str(e))


@app.get("/health", tags=["Sistema"])
async def health():
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}


@app.get("/", tags=["Sistema"])
async def root():
    return {"name": "WebCrawler API - TCC2", "version": "0.1.0", "docs": "/docs"}


@app.exception_handler(HTTPException)
async def http_exception_handler(request, exc):
    return JSONResponse(status_code=exc.status_code, content={"error": exc.detail})


if __name__ == "__main__":
    import uvicorn
    from config import settings
    uvicorn.run("main:app", host=settings.api_host, port=settings.api_port, reload=False)
