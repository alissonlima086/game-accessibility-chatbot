import logging
import os
import requests

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = (
    "Você é um assistente especializado em acessibilidade em jogos digitais.\n"
    "Responda com base EXCLUSIVA no contexto fornecido.\n\n"

    "REGRAS:\n"
    "- Use apenas informações do contexto.\n"
    "- Não invente informações.\n"
    "- Pode fazer inferências diretas, desde que claramente suportadas pelo contexto.\n"
    "- Não mencione o contexto.\n"
    "- Não mencione a fonte ou referência, apenas disponibilize o link da fonte da informação.\n"
    "- Se a resposta não estiver no contexto, responda exatamente: "
    "'Não encontrei essa informação no material disponível.'\n\n"

    "ESTILO:\n"
    "- Responda em português.\n"
    "- Seja direto, técnico e natural, como orientação a desenvolvedores.\n"
    "- Evite introduções, conclusões ou frases desnecessárias.\n"
    "- Explique brevemente o motivo da recomendação.\n\n"

    "FORMATO:\n"
    "- Resposta objetiva e prática.\n"
    "- Use lista apenas quando houver múltiplos itens distintos.\n\n"

    "PRIORIDADE:\n"
    "- Em caso de dúvida, priorize fidelidade ao contexto em vez de completude.\n"
)
class OllamaClient:

    def __init__(self, base_url: str = "http://ollama:11434", model: str = "gemma4:e2b"):
        self.base_url = base_url.rstrip("/")
        self.model = model

    def complete(self, prompt: str) -> str:
        try:
            resp = requests.post(
                f"{self.base_url}/api/chat",
                json={
                    "model": self.model,
                    "messages": [
                        {"role": "system", "content": SYSTEM_PROMPT},
                        {"role": "user", "content": prompt},
                    ],
                    "stream": False,
                },
                timeout=120,
            )
            resp.raise_for_status()
            return resp.json()["message"]["content"].strip()
        except requests.exceptions.ConnectionError:
            logger.error(f"Ollama não está acessível em {self.base_url}")
            raise
        except Exception as e:
            logger.error(f"Erro Ollama: {e}")
            raise


class GroqClient:

    def __init__(self, api_key: str, model: str = "llama3-8b-8192"):
        self.api_key = api_key
        self.model = model
        self.base_url = "https://api.groq.com/openai/v1"

    def complete(self, prompt: str) -> str:
        try:
            resp = requests.post(
                f"{self.base_url}/chat/completions",
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": self.model,
                    "messages": [
                        {"role": "system", "content": SYSTEM_PROMPT},
                        {"role": "user", "content": prompt},
                    ],
                    "temperature": 0.3,
                    "max_tokens": 1024,
                },
                timeout=30,
            )
            resp.raise_for_status()
            return resp.json()["choices"][0]["message"]["content"].strip()
        except Exception as e:
            logger.error(f"Erro Groq: {e}")
            raise


def build_llm_client():
    provider = os.getenv("LLM_PROVIDER", "none").lower()

    if provider == "groq":
        api_key = os.getenv("GROQ_API_KEY", "")
        if not api_key:
            logger.warning("GROQ_API_KEY não definido, LLM desativado")
            return None
        model = os.getenv("GROQ_MODEL", "llama3-8b-8192")
        logger.info(f"LLM: Groq ({model})")
        return GroqClient(api_key=api_key, model=model)

    if provider == "ollama":
        base_url = os.getenv("OLLAMA_URL", "http://ollama:11434")
        model = os.getenv("OLLAMA_MODEL", "gemma4:e2b")
        logger.info(f"LLM: Ollama ({model}) em {base_url}")
        return OllamaClient(base_url=base_url, model=model)

    logger.info("LLM desativado (LLM_PROVIDER=none)")
    return None