# 自动加载 .env
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

REQUESTED_ENV := $(if $(filter command line,$(origin ENV)),$(ENV),)

.PHONY: ensure-env init up down enter tmux clean logs help

ensure-env:
	@./scripts/ensure-env.sh

init: ## 初始化并构建统一 dev 环境，如 make init ENV=go,python 或 ENV=all
	@./scripts/init.sh "$(REQUESTED_ENV)"

up: ## 构建并启动统一 dev 环境，必须显式传 ENV，如 make up ENV=go,python
	@./scripts/up.sh "$(REQUESTED_ENV)"

down: ## 停止当前统一 dev 环境
	@./scripts/down.sh

enter: ## 进入当前已启动的统一 dev 环境
	@./scripts/enter.sh "$(REQUESTED_ENV)"

tmux: ## 进入/附着当前统一 dev 环境里的 Tmux 会话
	@./scripts/tmux.sh "$(REQUESTED_ENV)"

clean: ## 清理统一 dev 容器和本项目组合镜像（保留 volumes）
	@./scripts/clean.sh

logs: ## 查看当前统一 dev 容器日志
	@./scripts/logs.sh

help: ## 显示帮助
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'
