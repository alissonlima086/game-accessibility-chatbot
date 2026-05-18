from pydantic import BaseModel, HttpUrl, field_validator
from typing import List, Optional
from datetime import datetime

class LinkCreate(BaseModel):
    urls: List[HttpUrl]

    @field_validator("urls")
    @classmethod
    def validate_urls(cls, v):
        if not v:
            raise ValueError("Lista de URLs não pode ser vazia")
        if len(v) > 500:
            raise ValueError("Muitos URLs. Limite de 500")
        return v

    model_config = {
        "json_schema_extra": {
            "example": {
                "urls": [
                    "https://google.com",
                    "https://unitins.br",
                    "https://github.com"
                ]
            }
        }
    }

class LinkResponse(BaseModel):
    added: int
    duplicated: int
    errors: Optional[int] = None
    total: int

class LinkStatusResponse(BaseModel):
    total: int
    pending: int
    success: int
    error: int

class PageResponse(BaseModel):
    url: str
    title: Optional[str] = None
    description: Optional[str] = None
    status_code: Optional[int] = None
    word_count: int = 0
    crawled_at: datetime
    keywords: Optional[List[str]] = None

class PageDetailResponse(BaseModel):
    url: str
    html_content: str
    title: Optional[str] = None
    description: Optional[str] = None
    status_code: Optional[int] = None
    word_count: int = 0
    language: Optional[str] = None
    extracted_links: Optional[List[str]] = None
    crawled_at: datetime
    keywords: Optional[List[str]] = None

class CrawlResponse(BaseModel):
    message: str
    timestamp: datetime
