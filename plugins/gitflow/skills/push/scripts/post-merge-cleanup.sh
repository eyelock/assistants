#!/bin/bash
# Post-merge worktree cleanup.
# Usage: post-merge-cleanup.sh <main-repo> <worktree-path> <branch>
set -e

MAIN_REPO="$1"
WORKTREE_PATH="$2"
BRANCH="$3"

if [ -z "$MAIN_REPO" ] || [ -z "$WORKTREE_PATH" ] || [ -z "$BRANCH" ]; then
    echo "Usage: post-merge-cleanup.sh <main-repo> <worktree-path> <branch>" >&2
    exit 1
fi

cd "$MAIN_REPO"
git worktree remove "$WORKTREE_PATH" 2>/dev/null || echo "Worktree already removed"
git branch -d "$BRANCH" 2>/dev/null || echo "Local branch already deleted"
if git ls-remote --exit-code origin "$BRANCH" 2>/dev/null; then
    git push origin --delete "$BRANCH"
else
    echo "Remote branch already deleted"
fi
