from typing import Set, Dict, Tuple
import logging

logger = logging.getLogger(__name__)


class StatusCodeClassifier:

    SUCCESS_CODES: Set[int] = {200, 201, 202, 203, 204, 205, 206}
    
    REDIRECT_CODES: Set[int] = {300, 301, 302, 303, 304, 305, 306, 307, 308}
    
    CLIENT_ERROR_CODES: Set[int] = {400, 401, 402, 403, 404, 405, 406, 408, 409, 410, 411, 412, 413, 414,  415, 416, 417, 418, 421, 422, 423, 424,425, 426, 428, 429, 431, 451}
    
    SERVER_ERROR_CODES: Set[int] = {500, 501, 502, 503, 504, 505, 506, 507, 508, 510, 511}
    
    CUSTOM_CODES: Set[int] = {520, 521, 522, 523, 524, 525, 526, 527, 530, 598, 599}
    
    RATE_LIMIT_CODES: Set[int] = {429, 420}
    
    def __init__(self):
        self.classification_cache: Dict[int, str] = {}
    
    def classify(self, status_code: int) -> str:
        if status_code in self.classification_cache:
            return self.classification_cache[status_code]
        
        if status_code in self.SUCCESS_CODES or status_code in self.REDIRECT_CODES:
            classification = "success"
        elif status_code in self.RATE_LIMIT_CODES:
            classification = "rate_limit"
        elif status_code in self.CLIENT_ERROR_CODES:
            classification = "permanent_error"
        elif status_code in self.SERVER_ERROR_CODES:
            classification = "temporary_error"
        elif status_code in self.CUSTOM_CODES:
            classification = "temporary_error"
        else:
            classification = "unknown"
        
        self.classification_cache[status_code] = classification
        return classification
    
    def is_temporary_error(self, status_code: int) -> bool:
        return self.classify(status_code) in ["temporary_error", "rate_limit"]
    
    def is_permanent_error(self, status_code: int) -> bool:
        return self.classify(status_code) == "permanent_error"
    
    def is_success(self, status_code: int) -> bool:
        return self.classify(status_code) == "success"
    
    def should_retry_later(self, status_code: int) -> bool:
        classification = self.classify(status_code)
        return classification in ["temporary_error", "rate_limit"]
    
    
    def should_delete_from_queue(self, status_code: int) -> bool: # deleta da queue atual, mas pode tentar de novo na proxima
        return self.is_permanent_error(status_code)
    
    def get_error_message(self, status_code: int, reason: str = None) -> str:
        classification = self.classify(status_code)
        
        messages = {
            "success": f"HTTP {status_code} - Sucesso",
            "temporary_error": f"HTTP {status_code} - Erro temporário (servidor com problema)",
            "permanent_error": f"HTTP {status_code} - Erro permanente (URL/conteúdo inválido)",
            "rate_limit": f"HTTP {status_code} - Rate limit (aguarde e retente)",
            "unknown": f"HTTP {status_code} - Erro desconhecido",
        }
        
        message = messages.get(classification, f"HTTP {status_code}")
        if reason:
            message += f" - {reason}"
        
        return message
    
    def get_action_for_error(self, status_code: int) -> Dict[str, any]:
        classification = self.classify(status_code)
        
        if status_code in self.SUCCESS_CODES or status_code in self.REDIRECT_CODES:
            return {
                'classification': classification,
                'should_delete': False,
                'should_retry': False,
                'should_log_as': 'info',
                'suggestion': 'Página crawleada com sucesso'
            }
        
        elif self.is_permanent_error(status_code):
            return {
                'classification': classification,
                'should_delete': True,
                'should_retry': False, 
                'should_log_as': 'warning',
                'suggestion': 'URL inválida ou conteúdo não acessível permanentemente'
            }
        
        elif self.should_retry_later(status_code):
            return {
                'classification': classification,
                'should_delete': False, 
                'should_retry': True,
                'should_log_as': 'warning',
                'suggestion': 'Retentar em próxima execução quando servidor se recuperar'
            }
        
        else:
            return {
                'classification': classification,
                'should_delete': False,
                'should_retry': True,
                'should_log_as': 'error',
                'suggestion': 'Erro desconhecido, investigar'
            }
    
    def get_statistics(self) -> Dict[str, int]:
        stats = {
            'cached_codes': len(self.classification_cache),
            'success_count': sum(1 for v in self.classification_cache.values() if v == 'success'),
            'temp_error_count': sum(1 for v in self.classification_cache.values() if v == 'temporary_error'),
            'perm_error_count': sum(1 for v in self.classification_cache.values() if v == 'permanent_error'),
            'rate_limit_count': sum(1 for v in self.classification_cache.values() if v == 'rate_limit'),
        }
        return stats
    
    def clear_cache(self):
        """Limpa o cache de classificações"""
        self.classification_cache.clear()


status_classifier = StatusCodeClassifier()