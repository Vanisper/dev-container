# 自动加载 .env
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# 默认环境，支持逗号分隔或 all
ENV ?= rust
COMPOSE_ENV_FILE := $(if $(wildcard .env),--env-file .env,)
COMPOSE := COMPOSE_PROJECT_NAME=$${COMPOSE_PROJECT_NAME:-dev} docker compose $(COMPOSE_ENV_FILE)
AVAILABLE_ENVS := $(sort $(patsubst envs/%/docker-compose.yml,%,$(wildcard envs/*/docker-compose.yml)))
comma := ,
empty :=
space := $(empty) $(empty)

ifeq ($(ENV),all)
	ENVS := $(AVAILABLE_ENVS)
else
	ENVS := $(subst $(comma),$(space),$(ENV))
endif

.PHONY: init up down enter clean logs help

init: ## 初始化环境，如 make init ENV=rust,go 或 make init ENV=all
	@for env in $(ENVS); do 		echo "🚀 初始化 $$env..."; 		./scripts/init.sh $$env; 	done

up: ## 启动环境，如 make up ENV=rust,go
	@for env in $(ENVS); do 		echo "➡️  启动 $$env..."; 		$(COMPOSE) -f envs/$$env/docker-compose.yml up -d; 	done

down: ## 停止环境，如 make down ENV=rust,go
	@for env in $(ENVS); do 		echo "➡️  停止 $$env..."; 		$(COMPOSE) -f envs/$$env/docker-compose.yml down; 	done

enter: ## 进入指定环境（单次一个），如 make enter ENV=go
	@./scripts/enter.sh $(ENV)

clean: ## 清理所有镜像和容器（保留 volumes）
	@for env in $(AVAILABLE_ENVS); do 		$(COMPOSE) -f envs/$$env/docker-compose.yml down --rmi local 2>/dev/null || true; 	done

logs: ## 查看指定环境日志，如 make logs ENV=rust
	@$(COMPOSE) -f envs/$(ENV)/docker-compose.yml logs -f

help: ## 显示帮助
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'
