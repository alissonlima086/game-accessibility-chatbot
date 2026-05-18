.PHONY: all up down crawler chatbot flutter logs-crawler logs-chatbot network wait-crawler help

CRAWLER_DIR  := servico-crawler
CHATBOT_DIR  := servico-chatbot/backend
FLUTTER_DIR  := servico_flutter
FLUTTER_PORT := 8081

ifeq ($(OS),Windows_NT)
  FLUTTER := flutter.bat
else
  FLUTTER := flutter
endif

## Sobe tudo: crawler → wait → chatbot → flutter
all: crawler wait-crawler chatbot flutter

## Cria a rede compartilhada (fallback, caso o crawler não tenha subido ainda)
network:
	docker network create webcrawler-network 2>/dev/null || true

## Aguarda o webcrawler-api ficar saudável
wait-crawler:
	@echo ">>> Aguardando webcrawler-api ficar saudavel..."
	@until docker inspect --format='{{.State.Health.Status}}' webcrawler-api 2>/dev/null | grep -q healthy; do \
		echo "  ... aguardando"; sleep 3; \
	done
	@echo ">>> webcrawler-api pronto."

## Sobe o crawler (mongo + qdrant + crawler) — ele mesmo cria a webcrawler-network
crawler:
	@echo ">>> Subindo crawler..."
	docker compose -f $(CRAWLER_DIR)/docker-compose.yml up -d --build
	@echo ">>> Crawler ok."

## Sobe o backend do chatbot (postgres + chatbot-api)
chatbot: network
	@echo ">>> Subindo chatbot..."
	docker compose -f $(CHATBOT_DIR)/docker-compose.yml up -d --build
	@echo ">>> Chatbot ok."

## Roda o Flutter no web-server
flutter:
	@echo ">>> Flutter na porta $(FLUTTER_PORT)..."
	cd $(FLUTTER_DIR) && $(FLUTTER) run -d web-server --web-port $(FLUTTER_PORT)

## Para todos os containers
down:
	docker compose -f $(CHATBOT_DIR)/docker-compose.yml down
	docker compose -f $(CRAWLER_DIR)/docker-compose.yml down

## Logs do crawler
logs-crawler:
	docker compose -f $(CRAWLER_DIR)/docker-compose.yml logs -f

## Logs do chatbot
logs-chatbot:
	docker compose -f $(CHATBOT_DIR)/docker-compose.yml logs -f

help:
	@echo ""
	@echo "Targets disponíveis:"
	@echo "  all            Sobe crawler + chatbot + flutter (fluxo completo)"
	@echo "  network        Cria a rede webcrawler-network (fallback/idempotente)"
	@echo "  crawler        Sobe apenas o docker-compose do crawler"
	@echo "  chatbot        Sobe apenas o docker-compose do chatbot"
	@echo "  flutter        Roda o Flutter em web-server :$(FLUTTER_PORT)"
	@echo "  wait-crawler   Aguarda webcrawler-api ficar healthy"
	@echo "  down           Para todos os containers"
	@echo "  logs-crawler   Logs do crawler"
	@echo "  logs-chatbot   Logs do chatbot"
	@echo ""