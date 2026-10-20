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

.PHONY: help evals eval skillspector docs

help: ## List targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "} {printf "  %-13s %s\n", $$1, $$2}'
	@echo
	@echo "  Options: MODE=all|output|triggers  RUNS=N  MODEL=<model>  J=N  DRY_RUN=1"

evals: ## Run the evals of every skill (costs money: try DRY_RUN=1 first)
	@scripts/run-evals.sh $(EVAL_FLAGS) skills plugins

eval: ## Run the evals of one skill, package or plugin: make eval P=plugins/gitflow
	@test -n "$(P)" || { echo "usage: make eval P=<skill, package or plugin path>" >&2; exit 1; }
	@scripts/run-evals.sh $(EVAL_FLAGS) $(P)

# The same scan CI runs (needs Docker). Fixtures are test data, not shipped skills.
skillspector: ## Scan every skill with SkillSpector, as CI does (needs Docker)
	@docker run --rm -v "$(CURDIR):/scan:ro" ghcr.io/eyelock/skillspector:1 gate . \
		--exclude '*/evals/files/*' --exclude 'e2e-fixtures/*'

docs: ## Serve docs/ at http://localhost:3000 with live reload (needs npx)
	@command -v npx >/dev/null 2>&1 || { echo "npx not found. Install Node.js to browse docs locally." >&2; exit 1; }
	@npx --yes docsify-cli@4.4.4 serve docs
