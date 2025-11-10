#!/usr/bin/env bash
set -euo pipefail

# Merge the latest remote branch matching "claude/" into main (or master).
# - Fetches from origin
# - Ensures local main/master is at the remote head (fast-forward)
# - Finds the most recently updated remote branch that matches /^origin\/claude\//i
# - Merges that branch into main with a merge commit
#
# Usage:
#   ./merge_claude_to_main.sh [--push]
#
# Options:
#   --push   Push the updated main branch to origin after merge

info()  { echo "[INFO] $*"; }
warn()  { echo "[WARN] $*" >&2; }
error() { echo "[ERROR] $*" >&2; exit 1; }

PUSH_AFTER=false
if [[ ${1:-} == "--push" ]]; then
  PUSH_AFTER=true
fi

# Ensure we're in a git repo
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || error "Not inside a git repository"

# Ensure working tree is clean to avoid accidental resets/merges over local changes
if ! git diff --quiet || ! git diff --cached --quiet; then
  error "Working tree is not clean. Commit or stash changes before running."
fi

# Ensure origin exists
if ! git remote get-url origin >/dev/null 2>&1; then
  error "Remote 'origin' not found. Add it with: git remote add origin <url>"
fi

info "Fetching latest refs from origin"
git fetch --prune origin

# Determine main branch name (prefer main, fallback to master)
MAIN_BRANCH=""
if git show-ref --verify --quiet refs/remotes/origin/main; then
  MAIN_BRANCH="main"
elif git show-ref --verify --quiet refs/remotes/origin/master; then
  MAIN_BRANCH="master"
else
  error "Neither origin/main nor origin/master found. Cannot determine default branch."
fi

info "Default branch detected: ${MAIN_BRANCH}"

# Ensure we have a local branch tracking the remote default branch
if git show-ref --verify --quiet "refs/heads/${MAIN_BRANCH}"; then
  info "Switching to local ${MAIN_BRANCH}"
  git switch "${MAIN_BRANCH}"
else
  info "Creating local ${MAIN_BRANCH} tracking origin/${MAIN_BRANCH}"
  git switch -c "${MAIN_BRANCH}" --track "origin/${MAIN_BRANCH}"
fi

# Fast-forward local main to remote head
info "Fast-forwarding ${MAIN_BRANCH} to origin/${MAIN_BRANCH}"
git merge --ff-only "origin/${MAIN_BRANCH}" || error "Unable to fast-forward ${MAIN_BRANCH}; local history diverged. Resolve manually."

# Find the most recently updated remote branch whose name contains "claude" (case-insensitive)
info "Locating latest remote branch matching /^origin\\/claude\\//i"
CLAUDE_REMOTE_BRANCH=$(git for-each-ref \
  --sort=-committerdate \
  --format='%(refname:short)' \
  refs/remotes/origin \
  | grep -i '^origin/claude/' \
  | head -n 1 || true)

if [[ -z "${CLAUDE_REMOTE_BRANCH}" ]]; then
  error "No remote branch matching /^origin\\/claude\\//i found on origin."
fi

info "Selected branch: ${CLAUDE_REMOTE_BRANCH}"

# Show preview of incoming commits
info "Previewing commits to merge (origin/${MAIN_BRANCH}..${CLAUDE_REMOTE_BRANCH})"
git --no-pager log --oneline --decorate --graph "origin/${MAIN_BRANCH}..${CLAUDE_REMOTE_BRANCH}" || true

# Perform the merge with a merge commit
info "Merging ${CLAUDE_REMOTE_BRANCH} into ${MAIN_BRANCH}"
git merge --no-ff --no-edit "${CLAUDE_REMOTE_BRANCH}" || {
  warn "Merge reported conflicts. Resolve them, then run: git add -A && git commit"
  exit 2
}

if ${PUSH_AFTER}; then
  info "Pushing ${MAIN_BRANCH} to origin"
  git push origin "${MAIN_BRANCH}"
fi

info "Done. ${MAIN_BRANCH} now contains ${CLAUDE_REMOTE_BRANCH}."
