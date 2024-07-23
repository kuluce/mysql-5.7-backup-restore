.PHONY: help down up ps

all: help

down:
	@echo "Stopping containers..."
	@docker-compose down

up:
	@echo "Starting containers..."
	@docker-compose up -d

ps:
	@echo "Listing containers..."
	@docker-compose ps

help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  down    Stop containers"
	@echo "  up      Start containers"
	@echo "  ps      List containers"
	@echo "  help    Show this help message"