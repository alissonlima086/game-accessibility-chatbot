import logging
import grpc
logger = logging.getLogger(__name__)
import threading
from concurrent import futures
from datetime import datetime

import sys
import os
sys.path.insert(0, os.path.dirname(__file__))

import crawler_pb2 as pb
import crawler_pb2_grpc as pb_grpc


class AdminServicer(pb_grpc.AdminServiceServicer):
    def __init__(self, crawler_service):
        self.svc = crawler_service

    def AddLinks(self, request, context):
        result = self.svc.add_links(list(request.urls))
        return pb.AddLinksResponse(
            added=result.get("added", 0),
            duplicated=result.get("duplicated", 0),
            errors=result.get("errors", 0),
        )

    def ExtractLinks(self, request, context):
        limit = request.limit or 100
        result = self.svc.extract_links_from_pending(limit=limit)
        return pb.ExtractLinksResponse(
            processed=result.get("processed", 0),
            links_added=result.get("links_added", 0),
            errors=result.get("errors", 0),
        )

    def CrawlSinglePage(self, request, context):
        try:
            result = self.svc.crawl_single_page(request.url)
            return pb.CrawlSinglePageResponse(
                success=result.get("success", False),
                message=result.get("message", ""),
                title=result.get("title", ""),
            )
        except Exception as e:
            return pb.CrawlSinglePageResponse(success=False, message=str(e), title="")

    def GetLinksStatus(self, request, context):
        status = self.svc.get_links_status()
        return pb.LinksStatusResponse(
            total=status.get("total", 0),
            pending=status.get("pending", 0),
            success=status.get("success", 0),
            error=status.get("error", 0),
            blocked=status.get("blocked", 0),
        )

    def GetLinksStatusByDomain(self, request, context):
        domains = self.svc.get_links_status_by_domain()
        items = [
            pb.LinkDomainStat(
                domain=d.get("domain", ""),
                total=d.get("total", 0),
                pending=d.get("pending", 0),
                success=d.get("success", 0),
                error=d.get("error", 0),
            )
            for d in domains
        ]
        return pb.LinksByDomainResponse(domains=items)

    def ListLinks(self, request, context):
        limit = request.limit or 20
        skip = request.skip or 0
        status_filter = request.status or None
        url_filter = request.url_filter or None
        logger.info(f"ListLinks | limit={limit} skip={skip} status={status_filter} url_filter={url_filter}")
        result = self.svc.list_links(limit=limit, skip=skip, status=status_filter, url_filter=url_filter)
        items = [
            pb.LinkItem(
                url=l.get("url", ""),
                status=l.get("status", ""),
                depth=l.get("depth", 0),
                domain=l.get("domain", ""),
                created_at=str(l.get("created_at", "")),
                updated_at=str(l.get("updated_at", "")),
                error_message=l.get("error", "") or "",
            )
            for l in result.get("links", [])
        ]
        return pb.ListLinksResponse(links=items, total=result.get("total", 0))

    def DeleteLink(self, request, context):
        try:
            self.svc.delete_link(request.url)
            return pb.OperationResponse(success=True, message="Link deletado")
        except Exception as e:
            return pb.OperationResponse(success=False, message=str(e))

    def ListPages(self, request, context):
        pages = self.svc.get_pages(limit=request.limit or 10, skip=request.skip or 0)
        return pb.ListPagesResponse(pages=[_to_page_summary(p) for p in pages])

    def ListPagesByDomain(self, request, context):
        pages = self.svc.get_pages_by_domain(
            request.domain, limit=request.limit or 10, skip=request.skip or 0
        )
        return pb.ListPagesResponse(pages=[_to_page_summary(p) for p in pages])

    def GetPage(self, request, context):
        page = self.svc.get_page_detail(request.url)
        if not page:
            context.set_code(grpc.StatusCode.NOT_FOUND)
            context.set_details("Página não encontrada")
            return pb.PageDetailResponse()
        return pb.PageDetailResponse(
            url=page.get("url", ""),
            title=page.get("title", ""),
            description=page.get("description", ""),
            text_content=page.get("text_content", ""),
            summary=page.get("summary", ""),
            word_count=page.get("word_count", 0),
            keywords=page.get("keywords", []),
            language=page.get("language", ""),
            status_code=page.get("status_code", 0),
            crawled_at=str(page.get("crawled_at", "")),
            embedding_status=page.get("embedding_status", ""),
            chunks_count=page.get("chunks_count", 0),
        )

    def GetDomainStats(self, request, context):
        stats = self.svc.get_domain_stats(request.domain)
        by_status = stats.get("links_by_status", {})
        return pb.DomainStatsResponse(
            domain=stats.get("domain", ""),
            total_links=stats.get("total_links", 0),
            total_pages_crawled=stats.get("total_pages_crawled", 0),
            pending=by_status.get("pending", 0),
            extracted=by_status.get("extracted", 0),
            success=by_status.get("success", 0),
            error=by_status.get("error", 0),
            blocked=by_status.get("blocked", 0),
        )

    def DeleteDomain(self, request, context):
        result = self.svc.delete_domain(request.domain)
        return pb.DeleteDomainResponse(
            links_deleted=result.get("links_deleted", 0),
            pages_deleted=result.get("pages_deleted", 0),
        )

    def TriggerCrawl(self, request, context):
        limit = request.limit or 50
        # Executa em background para não bloquear o gRPC e evitar deadline exceeded
        thread = threading.Thread(
            target=self.svc.crawl_pending_pages,
            kwargs={"limit": limit},
            daemon=True,
        )
        thread.start()
        return pb.CrawlResponse(
            message=f"Crawling iniciado em background (limite: {limit} páginas)",
            timestamp=datetime.utcnow().isoformat(),
        )


def _to_page_summary(p: dict) -> pb.PageSummary:
    return pb.PageSummary(
        url=p.get("url", ""),
        title=p.get("title", ""),
        description=p.get("description", ""),
        status_code=p.get("status_code", 0),
        word_count=p.get("word_count", 0),
        crawled_at=str(p.get("crawled_at", "")),
    )


def serve_admin(crawler_service, port: int = 50051):
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    pb_grpc.add_AdminServiceServicer_to_server(AdminServicer(crawler_service), server)
    server.add_insecure_port(f"[::]:{port}")
    server.start()
    return server
