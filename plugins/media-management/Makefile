PLUGIN_NAME := media-management
PLUGIN_DIR  := $(HOME)/.claude/plugins/repos/$(PLUGIN_NAME)
SHELL       := /bin/bash

# All skill script directories
SKILL_SCRIPTS := $(wildcard skills/*/scripts/*.sh)
# All test scripts
TEST_SCRIPTS  := $(wildcard tests/scripts/*.sh tests/hooks/*.sh)
# All shellcheck-able scripts
ALL_SCRIPTS   := $(SKILL_SCRIPTS) hooks/validate-bash-command.sh \
                 tests/run-tests.sh tests/fixtures/generate-fixtures.sh \
                 $(TEST_SCRIPTS)

.DEFAULT_GOAL := help

.PHONY: help install uninstall fixtures test test-scripts test-hooks lint validate check clean

help: ## Show available targets
	@echo "Media Management Plugin — Development Targets"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Typical workflow:"
	@echo "  make check       # lint + validate + test (run before committing)"
	@echo "  make install     # symlink plugin for local use"

install: validate ## Symlink plugin into ~/.claude/plugins/repos for local use
	@mkdir -p "$(dir $(PLUGIN_DIR))"
	@if [ -L "$(PLUGIN_DIR)" ]; then \
		echo "Symlink already exists: $(PLUGIN_DIR)"; \
	elif [ -e "$(PLUGIN_DIR)" ]; then \
		echo "Error: $(PLUGIN_DIR) exists and is not a symlink" >&2; exit 1; \
	else \
		ln -s "$(CURDIR)" "$(PLUGIN_DIR)"; \
		echo "Installed: $(PLUGIN_DIR) -> $(CURDIR)"; \
	fi

uninstall: ## Remove plugin symlink from ~/.claude/plugins/repos
	@if [ -L "$(PLUGIN_DIR)" ]; then \
		rm "$(PLUGIN_DIR)"; \
		echo "Removed: $(PLUGIN_DIR)"; \
	else \
		echo "No symlink found at $(PLUGIN_DIR)"; \
	fi

fixtures: ## Generate test audio fixtures
	@bash tests/fixtures/generate-fixtures.sh tests/fixtures

test: fixtures ## Run full test suite
	@bash tests/run-tests.sh

test-scripts: fixtures ## Run script tests only
	@bash tests/run-tests.sh --scripts-only

test-hooks: ## Run hook tests only
	@bash tests/run-tests.sh --hooks-only

lint: ## Shellcheck all scripts
	@echo "Running shellcheck..."
	@shellcheck $(ALL_SCRIPTS)
	@echo "All scripts pass shellcheck."

validate: ## Validate plugin structure, frontmatter, and conventions
	@echo "Validating plugin structure..."
	@errors=0; \
	\
	echo "  Checking plugin manifest..."; \
	if [ ! -f .claude-plugin/plugin.json ]; then \
		echo "    FAIL: .claude-plugin/plugin.json not found"; errors=$$((errors+1)); \
	elif ! jq -e '.name and .description and .version' .claude-plugin/plugin.json > /dev/null 2>&1; then \
		echo "    FAIL: plugin.json missing required fields (name, description, version)"; errors=$$((errors+1)); \
	else \
		echo "    OK: plugin.json"; \
	fi; \
	\
	echo "  Checking settings..."; \
	if [ ! -f .claude/settings.json ]; then \
		echo "    FAIL: .claude/settings.json not found"; errors=$$((errors+1)); \
	elif ! jq empty .claude/settings.json 2>/dev/null; then \
		echo "    FAIL: .claude/settings.json is not valid JSON"; errors=$$((errors+1)); \
	else \
		echo "    OK: settings.json"; \
	fi; \
	\
	echo "  Checking hooks..."; \
	if [ ! -f hooks/hooks.json ]; then \
		echo "    FAIL: hooks/hooks.json not found"; errors=$$((errors+1)); \
	elif ! jq empty hooks/hooks.json 2>/dev/null; then \
		echo "    FAIL: hooks/hooks.json is not valid JSON"; errors=$$((errors+1)); \
	else \
		echo "    OK: hooks.json"; \
	fi; \
	\
	echo "  Checking SKILL.md frontmatter..."; \
	for skill_dir in skills/*/; do \
		skill=$$(basename "$$skill_dir"); \
		skill_file="$$skill_dir/SKILL.md"; \
		if [ ! -f "$$skill_file" ]; then \
			echo "    FAIL: $$skill — missing SKILL.md"; errors=$$((errors+1)); \
			continue; \
		fi; \
		if ! head -1 "$$skill_file" | grep -q '^---$$'; then \
			echo "    FAIL: $$skill — SKILL.md missing YAML frontmatter"; errors=$$((errors+1)); \
			continue; \
		fi; \
		fm=$$(awk '/^---$$/{if(n++)exit;next}n' "$$skill_file"); \
		fm_name=$$(echo "$$fm" | grep '^name:' | head -1); \
		fm_desc=$$(echo "$$fm" | grep '^description:' | head -1); \
		if [ -z "$$fm_name" ]; then \
			echo "    FAIL: $$skill — frontmatter missing 'name'"; errors=$$((errors+1)); \
		fi; \
		if [ -z "$$fm_desc" ]; then \
			echo "    FAIL: $$skill — frontmatter missing 'description'"; errors=$$((errors+1)); \
		fi; \
		fm_name_val=$$(echo "$$fm_name" | sed 's/^name: *//'); \
		if [ "$$fm_name_val" != "$$skill" ]; then \
			echo "    FAIL: $$skill — frontmatter name '$$fm_name_val' does not match directory"; errors=$$((errors+1)); \
		else \
			echo "    OK: $$skill"; \
		fi; \
	done; \
	\
	echo "  Checking agent frontmatter..."; \
	for agent_file in agents/*.md; do \
		[ -f "$$agent_file" ] || continue; \
		agent=$$(basename "$$agent_file" .md); \
		if ! head -1 "$$agent_file" | grep -q '^---$$'; then \
			echo "    FAIL: $$agent — missing YAML frontmatter"; errors=$$((errors+1)); \
			continue; \
		fi; \
		fm=$$(awk '/^---$$/{if(n++)exit;next}n' "$$agent_file"); \
		fm_name=$$(echo "$$fm" | grep '^name:' | head -1); \
		fm_desc=$$(echo "$$fm" | grep '^description:' | head -1); \
		fm_tools=$$(echo "$$fm" | grep '^tools:' | head -1); \
		if [ -z "$$fm_name" ]; then \
			echo "    FAIL: $$agent — frontmatter missing 'name'"; errors=$$((errors+1)); \
		fi; \
		if [ -z "$$fm_desc" ]; then \
			echo "    FAIL: $$agent — frontmatter missing 'description'"; errors=$$((errors+1)); \
		fi; \
		if [ -z "$$fm_tools" ]; then \
			echo "    FAIL: $$agent — frontmatter missing 'tools'"; errors=$$((errors+1)); \
		fi; \
		if [ -n "$$fm_name" ] && [ -n "$$fm_desc" ]; then \
			echo "    OK: $$agent"; \
		fi; \
	done; \
	\
	echo "  Checking script executability..."; \
	for script in $(SKILL_SCRIPTS) hooks/validate-bash-command.sh; do \
		if [ ! -x "$$script" ]; then \
			echo "    FAIL: $$script is not executable"; errors=$$((errors+1)); \
		fi; \
	done; \
	exec_count=$$(echo "$(SKILL_SCRIPTS) hooks/validate-bash-command.sh" | wc -w | tr -d ' '); \
	echo "    OK: $$exec_count scripts are executable"; \
	\
	echo "  Checking script shebangs..."; \
	for script in $(SKILL_SCRIPTS) hooks/validate-bash-command.sh; do \
		if ! head -1 "$$script" | grep -q '^#!/'; then \
			echo "    FAIL: $$script missing shebang"; errors=$$((errors+1)); \
		fi; \
	done; \
	echo "    OK: all scripts have shebangs"; \
	\
	echo "  Checking SKILL.md script references..."; \
	for skill_dir in skills/*/; do \
		skill=$$(basename "$$skill_dir"); \
		skill_file="$$skill_dir/SKILL.md"; \
		ref_errors=0; \
		grep -oE 'skills/[a-zA-Z0-9_-]+/scripts/[a-zA-Z0-9_-]+\.sh' "$$skill_file" 2>/dev/null | sort -u | while read -r ref; do \
			if [ ! -f "$$ref" ]; then \
				echo "    FAIL: $$skill — references $$ref but file not found"; ref_errors=$$((ref_errors+1)); \
			fi; \
		done; \
		grep -oE '(bash |^)scripts/[a-zA-Z0-9_-]+\.sh' "$$skill_file" 2>/dev/null | sed 's/^bash //' | sort -u | while read -r ref; do \
			if [ -d "$$skill_dir/scripts" ] && [ ! -f "$$skill_dir/$$ref" ]; then \
				echo "    FAIL: $$skill — references $$ref but file not found in $$skill_dir"; ref_errors=$$((ref_errors+1)); \
			fi; \
		done; \
		echo "    OK: $$skill script references"; \
	done; \
	\
	echo ""; \
	if [ $$errors -gt 0 ]; then \
		echo "Validation FAILED: $$errors error(s)"; exit 1; \
	else \
		echo "Validation passed."; \
	fi

check: lint validate test ## Lint + validate + test (full CI check)
	@echo ""
	@echo "All checks passed."

clean: uninstall ## Remove generated fixtures and plugin symlink
	@rm -f tests/fixtures/*.mp3 tests/fixtures/*.wav
	@echo "Cleaned test fixtures."
