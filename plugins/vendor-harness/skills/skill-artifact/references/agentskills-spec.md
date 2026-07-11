# Agent Skills Specification Reference

Source: https://agentskills.io

## Required Frontmatter

name: skill-name          # lowercase a-z, 0-9, hyphens; matches directory name
description: Brief desc   # 1–1024 chars; used for skill discovery and catalog

## Optional Frontmatter (spec-defined)

license: MIT                    # license name or reference
compatibility: "requirements"   # max 500 chars; OS/environment requirements
metadata:                        # key-value map of arbitrary metadata
  author: org-name
  version: "0.1.0"
allowed-tools: Bash Read Write   # space-delimited; tools that run without prompting

## Vendor Extensions (Claude Code only, NOT in spec)

disable-model-invocation: false  # hide from agent catalog; user /invoke only
user-invocable: true             # hide from / menu if false
model: sonnet                    # override model for this skill
context: fork                    # run in isolated subagent
agent: general-purpose           # subagent type when context: fork
argument-hint: "[issue-number]"  # autocomplete hint shown to user

## Directory Layout

skill-name/
├── SKILL.md          # required
├── references/       # supporting docs; loaded on demand
├── scripts/          # executables; must be chmod +x
└── assets/           # templates, config, data

## Progressive Disclosure

1. Catalog: name + description only. Always in context for discovery.
2. Instructions: full SKILL.md body. Loaded when relevant or invoked.
3. Resources: scripts/, references/, assets/. Loaded on demand.

Keep descriptions under 130 chars for large skill collections.
Catalog budget: ~2% of context window (~53 skills on 200K context).
