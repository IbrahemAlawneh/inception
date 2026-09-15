NAME        := inception
LOGIN       := ialalawn


SRCS_DIR    := ./srcs
COMPOSE_YML := $(SRCS_DIR)/docker-compose.yml
ENV_FILE    := $(SRCS_DIR)/.env
SECRETS_DIR := secrets

DATA_DIR    := /home/$(LOGIN)/data
WP_DATA     := $(DATA_DIR)/wordpress
DB_DATA     := $(DATA_DIR)/mariadb


DOCKER_CMP  := docker compose -f $(COMPOSE_YML)

GREEN       := \033[1;32m
YELLOW      := \033[1;33m
RED         := \033[1;31m
RESET       := \033[0m


all: setup
	@echo "$(YELLOW)Building and starting containers for $(NAME)...$(RESET)"
	@$(DOCKER_CMP) up -d --build
	@echo "$(GREEN)$(NAME) services are up and running!$(RESET)"


setup:
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "$(RED)Error: $(ENV_FILE) not found!$(RESET)"; exit 1; \
	fi
	@if [ ! -d $(SECRETS_DIR) ]; then \
		echo "$(RED)Error: $(SECRETS_DIR) directory not found!$(RESET)"; exit 1; \
	fi
	@mkdir -p $(WP_DATA) $(DB_DATA)


stop:
	@echo "$(YELLOW)Stopping $(NAME) services...$(RESET)"
	@$(DOCKER_CMP) stop
	@echo "$(GREEN)Services stopped.$(RESET)"


start:
	@echo "$(YELLOW)Starting $(NAME) services...$(RESET)"
	@$(DOCKER_CMP) start
	@echo "$(GREEN)Services started.$(RESET)"


down:
	@echo "$(YELLOW)Tearing down $(NAME) infrastructure...$(RESET)"
	@$(DOCKER_CMP) down
	@echo "$(GREEN)Containers and networks removed.$(RESET)"


clean:
	@echo "$(YELLOW)Stopping services and removing Docker named volumes...$(RESET)"
	@$(DOCKER_CMP) down -v
	@echo "$(GREEN)Clean complete.$(RESET)"

fclean: clean
	@echo "$(RED)Purging host persistent data in $(DATA_DIR)...$(RESET)"
	@sudo rm -rf $(WP_DATA)/*
	@sudo rm -rf $(DB_DATA)/*
	@echo "$(RED)Pruning unused Docker images and build caches...$(RESET)"
	@docker system prune -af --volumes > /dev/null 2>&1 || true
	@echo "$(GREEN)Infrastructure fully purged to clean state.$(RESET)"

re: fclean all

ps:
	@$(DOCKER_CMP) ps


logs:
	@$(DOCKER_CMP) logs -f

.PHONY: all setup stop start down clean fclean re ps logs