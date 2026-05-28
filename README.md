# Game Accessibility Chatbot

Chatbot sobre acessibilidade em jogos com backend em Go, crawler em Python e frontend em Flutter Web.

---

## Requisitos

| Ferramenta     | Versão mínima |
|----------------|---------------|
| Docker         | 24.x          |
| Docker Compose | 2.x           |
| Flutter SDK    | 3.10.0        |
| Make           | qualquer      |
| Git            | qualquer      |

> **Windows:** use WSL 2 ou Git Bash para rodar o `make`.

---

## Variáveis de ambiente

### 1. Crawler — `servico-crawler/.env`

```bash
cp servico-crawler/.env.example servico-crawler/.env
```

```env
MONGODB_URL=mongodb://root:password@mongo:27017/webcrawler?authSource=admin
MONGODB_DB=webcrawler
CRAWL_INTERVAL=3600
REQUEST_TIMEOUT=10
API_HOST=0.0.0.0
API_PORT=8000

# LLM — Groq (recomendado, gratuito: console.groq.com)
LLM_PROVIDER=groq
GROQ_API_KEY=gsk_xxxxxxxxxxxxxxxxxxxx
GROQ_MODEL=llama-3.1-8b-instant

# Ou Ollama local (não requer chave):
# LLM_PROVIDER=ollama
# OLLAMA_URL=http://ollama:11434
# OLLAMA_MODEL=gemma4:e4b
```

### 2. Backend Go — `servico-chatbot/backend/.env`

```bash
cp servico-chatbot/backend/.env.example servico-chatbot/backend/.env
```

```env
DB_HOST=postgres
DB_PORT=5432
DB_USER=chatbot
DB_PASSWORD=chatbot123
DB_NAME=chatbot_db
DB_SSL_MODE=disable

SERVER_PORT=8080
SERVER_MODE=debug

GRPC_CRAWLER_HOST=webcrawler-api
GRPC_CRAWLER_ADMIN_PORT=50051
GRPC_CRAWLER_SEARCH_PORT=50052
GRPC_TIMEOUT=180

JWT_SECRET=troque_por_uma_string_aleatoria_longa   # gere com: openssl rand -hex 32
JWT_EXPIRATION=24

CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080,http://localhost:8081
```

### 3. Flutter — URL do backend

Edite `servico_flutter/lib/utils/theme.dart` se necessário:

```dart
const String kBaseUrl = 'http://localhost:8080';
```

---

## Execução

### Fluxo completo

```bash
make all
```

Executa em ordem:

| Passo | Comando              | O que faz                                   |
|-------|----------------------|---------------------------------------------|
| 1     | `make crawler`       | Sobe MongoDB + Qdrant + webcrawler-api       |
| 2     | `make wait-crawler`  | Aguarda o webcrawler-api ficar healthy       |
| 3     | `make chatbot`       | Sobe PostgreSQL + chatbot-api (Go)          |
| 4     | `make flutter`       | Inicia o Flutter Web em `http://localhost:8081` |


### Comandos individuais

```bash
make crawler        # sobe apenas o crawler e seus bancos
make chatbot        # sobe apenas o backend Go e o PostgreSQL
make flutter        # inicia apenas o frontend Flutter
make down           # para todos os containers
make logs-crawler   # acompanha logs do crawler
make logs-chatbot   # acompanha logs do backend
make help           # lista todos os targets disponíveis
```

---

## Portas

| Serviço        | Porta | Descrição                                         |
|----------------|-------|---------------------------------------------------|
| Flutter Web    | 8081  | Interface do usuário                              |
| Backend Go     | 8080  | API REST                                          |
| PostgreSQL     | 5432  | Banco do chatbot                                  |
| webcrawler-api | 50051 | gRPC Admin (gerenciar crawls)                     |
| webcrawler-api | 50052 | gRPC Search (busca semântica)                     |
| MongoDB        | 27017 | Banco do crawler                                  |
| Qdrant         | 6333  | Vector store (embeddings)                         |

---

## Documentação da API

Swagger disponível após subir o backend:

```
http://localhost:8080/swagger/index.html
```

---

## Primeiro acesso

1. Acesse `http://localhost:8081`
2. Crie uma conta via tela de registro
3. Faça login
4. Para disparar um crawl, acesse **Painel Admin** → **Gerenciar Crawler** e adicione as URLs de origem
