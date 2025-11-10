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
ALLOW_DIRTY=false
AUTOSTASH=false

# Capture environment preferences before we override local vars
_PUSH_AFTER_ENV="${PUSH_AFTER:-}"
_ALLOW_DIRTY_ENV="${ALLOW_DIRTY:-}"
_AUTOSTASH_ENV="${AUTOSTASH:-}"

# Parse args
for arg in "$@"; do
  case "$arg" in
    --push)        PUSH_AFTER=true ;;
    --allow-dirty) ALLOW_DIRTY=true ;;
    --autostash)   AUTOSTASH=true ;;
  esac
done

# Apply env defaults (only if not set via args)
if [[ "$PUSH_AFTER" == false && -n "$_PUSH_AFTER_ENV" ]]; then
  case "${_PUSH_AFTER_ENV}" in 1|true|TRUE|True|yes|YES) PUSH_AFTER=true ;; esac
fi
if [[ "$ALLOW_DIRTY" == false && -n "$_ALLOW_DIRTY_ENV" ]]; then
  case "${_ALLOW_DIRTY_ENV}" in 1|true|TRUE|True|yes|YES) ALLOW_DIRTY=true ;; esac
fi
if [[ "$AUTOSTASH" == false && -n "_AUTOSTASH_ENV" ]]; then
  case "${_AUTOSTASH_ENV}" in 1|true|TRUE|True|yes|YES) AUTOSTASH=true ;; esac
fi

# Ensure we're in a git repo
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || error "Not inside a git repository"

# Ensure working tree is clean, unless allowed or autostash is enabled
DIRTY=false
if ! git diff --quiet || ! git diff --cached --quiet; then
  DIRTY=true
fi

STASH_MADE=false
STASH_MARKER="auto-merge-$(date +%s)"
if [[ "$DIRTY" == true ]]; then
  if [[ "$AUTOSTASH" == true ]]; then
    info "Autostashing local changes"
    git stash push -u -k -m "$STASH_MARKER" || true
    if git stash list | grep -q "$STASH_MARKER"; then
      STASH_MADE=true
    fi
  elif [[ "$ALLOW_DIRTY" == true ]]; then
    warn "Proceeding with dirty working tree as requested (--allow-dirty)."
  else
    error "Working tree is not clean. Commit, stash, rerun with --allow-dirty, or use --autostash."
  fi
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

# Restore stashed changes if we created a stash
if [[ "$STASH_MADE" == true ]]; then
  info "Restoring stashed local changes"
  if ! git stash pop; then
    warn "Conflicts occurred while applying stashed changes. Resolve and commit manually."
  fi
fi

# -----------------------------------------------------------------------------
# Quick one-liners to download and run this script anywhere
#
# Bash (merge locally):
#   curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Setup-R-and-python-on-VSCode/main/merge_claude_to_main.sh | bash
#
# Bash (merge and push):
#   PUSH_AFTER=1 curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Setup-R-and-python-on-VSCode/main/merge_claude_to_main.sh | bash
#
# Bash (allow dirty working tree):
#   ALLOW_DIRTY=1 curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Setup-R-and-python-on-VSCode/main/merge_claude_to_main.sh | bash
#
# Bash (autostash before merge):
#   AUTOSTASH=1 curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Setup-R-and-python-on-VSCode/main/merge_claude_to_main.sh | bash
#
# PowerShell (merge locally):
#   iwr -useb https://raw.githubusercontent.com/Fr4nzz/Setup-R-and-python-on-VSCode/main/merge_claude_to_main.ps1 | iex
#
# PowerShell (merge and push):
#   $env:PUSH_AFTER=1; iwr -useb https://raw.githubusercontent.com/Fr4nzz/Setup-R-and-python-on-VSCode/main/merge_claude_to_main.ps1 | iex
#
# PowerShell (allow dirty working tree):
#   $env:ALLOW_DIRTY=1; iwr -useb https://raw.githubusercontent.com/Fr4nzz/Setup-R-and-python-on-VSCode/main/merge_claude_to_main.ps1 | iex
#
# PowerShell (autostash before merge):
#   $env:AUTOSTASH=1; iwr -useb https://raw.githubusercontent.com/Fr4nzz/Setup-R-and-python-on-VSCode/main/merge_claude_to_main.ps1 | iex
# -----------------------------------------------------------------------------
