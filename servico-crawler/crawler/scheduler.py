from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.interval import IntervalTrigger
from config import settings
import logging
from datetime import datetime

logger = logging.getLogger(__name__)

scheduler = BackgroundScheduler()
crawler_service = None

def start_scheduler(service):
    global crawler_service
    crawler_service = service

    try:
        scheduler.remove_all_jobs()

        if settings.run_scheduler_on_first_day:
            scheduler.add_job(
                _crawl_job,
                CronTrigger(
                    day=1,
                    hour=settings.scheduler_hour,
                    minute=settings.scheduler_minute
                ),
                id="crawl_job",
                name="Crawl mensal (primeiro dia)",
                misfire_grace_time=3600,
                replace_existing=True
            )
            logger.info(f"Scheduler mensal iniciado às {settings.scheduler_hour:02d}:{settings.scheduler_minute:02d}")
        else:
            scheduler.add_job(
                _crawl_job,
                IntervalTrigger(seconds=settings.crawl_interval),
                id="crawl_job",
                name="Crawl por intervalo",
                misfire_grace_time=900,
                replace_existing=True
            )
            logger.info(f"Scheduler iniciado (intervalo de {settings.crawl_interval}s)")

        scheduler.start()
    except Exception as e:
        logger.error(f"Erro ao iniciar scheduler: {e}")
        raise

def _crawl_job():
    global crawler_service
    try:
        if crawler_service:
            logger.info(f"Crawl automático iniciado - {datetime.utcnow().isoformat()}")
            crawler_service.crawl_pending_pages()
            logger.info("Crawl automático finalizado")
    except Exception as e:
        logger.error(f"Erro no scheduler: {e}")

def stop_scheduler():
    try:
        if scheduler.running:
            scheduler.shutdown()
            logger.info("Scheduler desligado")
    except Exception as e:
        logger.error(f"Erro ao desligar scheduler: {e}")

def get_scheduler_info():
    return {
        "running": scheduler.running,
        "jobs": [
            {
                "id": job.id,
                "name": job.name,
                "trigger": str(job.trigger),
                "next_run_time": str(job.next_run_time) if job.next_run_time else None
            }
            for job in scheduler.get_jobs()
        ]
    }
