#!/usr/bin/env bash
# Repo-side registration hook for TermQ's "Publish to Repository…" action.
#
# TermQ copies a validated YNH harness into <harness-dir> on a fresh worktree
# of this repo, then runs:
#
#   scripts/ynh-register.sh <harness-dir> <new|update>
#
# from the worktree root. This script finishes the repo-side registration:
#
#   1. verifies <harness-dir> is covered by a pnpm-workspace.yaml glob
#      (it never edits workspace topology — that is a reviewed decision)
#   2. generates/refreshes <harness-dir>/package.json from
#      <harness-dir>/.ynh-plugin/plugin.json, mapping same-repo includes to
#      @eyelock-assistants workspace:* dependencies (hand-added keys are kept)
#   3. runs `pnpm install --lockfile-only` so pnpm-lock.yaml stays green in CI
#
# `new` and `update` are treated identically (full regeneration). The script
# is idempotent, never commits or pushes, and works on any plain checkout —
# nothing here is TermQ-specific. JSON work lives in the sibling
# ynh-register.mjs (node is part of this repo's toolchain; jq is not).
#
# Note: harness entries under ynh/ deliberately carry no vendor manifests
# (.claude-plugin/, .cursor-plugin/) and are not indexed by the root
# marketplace files or scripts/sync-manifests.mjs (which only discovers
# .harness.json / .claude-plugin sources) — verified against ynh/termq-dev.
# Registration is therefore just the wrapper + lockfile.
#
# Exit codes: 0 success, 1 bad args/validation, 2 file not found, 3 tool error.

set -euo pipefail

prefix="ynh-register:"

usage() {
  {
    echo "usage: scripts/ynh-register.sh <harness-dir> <new|update>"
    echo "  <harness-dir>  harness directory relative to the repo root (e.g. ynh/my-harness)"
    echo "  <new|update>   whether this publish created the entry or overwrote an existing one"
  } >&2
}

fail() {
  echo "$prefix error: $1" >&2
  exit "$2"
}

if [ $# -ne 2 ]; then
  usage
  exit 1
fi

harness_dir="${1%/}"
harness_dir="${harness_dir#./}"
mode="$2"

case "$mode" in
  new | update) ;;
  *)
    usage
    fail "mode must be \"new\" or \"update\" (got \"$mode\")" 1
    ;;
esac

if [ -z "$harness_dir" ] || [ "$harness_dir" = "." ]; then
  fail "root-embedded harnesses are not supported — this repo keeps harnesses in ynh/<name>; publish to ynh/<name> instead of \".\"" 1
fi

case "$harness_dir" in
  /*) fail "harness dir must be relative to the repo root (got \"$harness_dir\")" 1 ;;
esac

if [ ! -f pnpm-workspace.yaml ]; then
  fail "no pnpm-workspace.yaml in $PWD — run this script from the repo root" 1
fi

if [ ! -d "$harness_dir" ]; then
  fail "harness directory \"$harness_dir\" does not exist under $PWD — publish the harness files first" 2
fi

manifest="$harness_dir/.ynh-plugin/plugin.json"
if [ ! -f "$manifest" ]; then
  fail "\"$manifest\" not found — a harness entry must carry its .ynh-plugin/plugin.json manifest" 2
fi

command -v node >/dev/null 2>&1 ||
  fail "node is required to generate the package.json wrapper — install Node 20+ (https://nodejs.org) and re-run" 3
command -v pnpm >/dev/null 2>&1 ||
  fail "pnpm is required to refresh pnpm-lock.yaml — install it (https://pnpm.io/installation, e.g. \`corepack enable\`) and re-run" 3

script_dir="$(cd "$(dirname "$0")" && pwd)"

echo "$prefix registering $harness_dir ($mode)"
node "$script_dir/ynh-register.mjs" "$harness_dir"

echo "$prefix refreshing pnpm-lock.yaml (pnpm install --lockfile-only)"
pnpm install --lockfile-only

echo "$prefix done — review with \`git status\` and commit when ready"
