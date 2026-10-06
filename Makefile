.DEFAULT_GOAL := help

# Eval options, for both targets:
#   MODE=all|output|triggers   which evals to run (default all)
#   RUNS=N                     runs per output case and arm (default 1)
#   MODEL=<model>              model for the runs (default sonnet)
#   J=N                        runs at once, 1-8 (default 4)
#   DRY_RUN=1                  list what would run, and run nothing
MODE ?= all
RUNS ?= 1
MODEL ?= sonnet
J ?= 4
EVAL_FLAGS = --mode $(MODE) --runs $(RUNS) --model $(MODEL) -j $(J) $(if $(DRY_RUN),--dry-run)

.PHONY: help evals eval

help: ## List targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "} {printf "  %-8s %s\n", $$1, $$2}'
	@echo
	@echo "  Options: MODE=all|output|triggers  RUNS=N  MODEL=<model>  J=N  DRY_RUN=1"

evals: ## Run the evals of every skill (costs money: try DRY_RUN=1 first)
	@scripts/run-evals.sh $(EVAL_FLAGS) skills plugins

eval: ## Run the evals of one skill, package or plugin: make eval P=plugins/gitflow
	@test -n "$(P)" || { echo "usage: make eval P=<skill, package or plugin path>" >&2; exit 1; }
	@scripts/run-evals.sh $(EVAL_FLAGS) $(P)
