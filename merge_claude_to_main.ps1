#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

function Write-Info($msg) { Write-Host "[INFO] $msg" }
function Write-Warn($msg) { Write-Warning $msg }
function Fail($msg) { Write-Error $msg; exit 1 }

# Support argument and environment variables for behavior flags
$PushAfter = $false
$AllowDirty = $false
$AutoStash = $false

# Parse args
foreach ($arg in $args) {
  switch ($arg) {
    '--push'        { $PushAfter = $true }
    '--allow-dirty' { $AllowDirty = $true }
    '--autostash'   { $AutoStash = $true }
  }
}

# Apply env defaults only if not already set by args
if (-not $PushAfter -and $env:PUSH_AFTER) {
  if ($env:PUSH_AFTER -match '^(1|true|yes)$') { $PushAfter = $true }
}
if (-not $AllowDirty -and $env:ALLOW_DIRTY) {
  if ($env:ALLOW_DIRTY -match '^(1|true|yes)$') { $AllowDirty = $true }
}
if (-not $AutoStash -and $env:AUTOSTASH) {
  if ($env:AUTOSTASH -match '^(1|true|yes)$') { $AutoStash = $true }
}

# Ensure inside a git repo
git rev-parse --is-inside-work-tree *> $null 2>&1
if ($LASTEXITCODE -ne 0) { Fail "Not inside a git repository" }

# Ensure working tree is clean (or handle per flags)
git diff --quiet *> $null 2>&1; $dirty1 = $LASTEXITCODE
git diff --cached --quiet *> $null 2>&1; $dirty2 = $LASTEXITCODE
$isDirty = ($dirty1 -ne 0 -or $dirty2 -ne 0)

$stashMade = $false
$stashMarker = "auto-merge-$(Get-Date -UFormat %s)"
if ($isDirty) {
  if ($AutoStash) {
    Write-Info 'Autostashing local changes'
    git stash push -u -k -m $stashMarker | Out-Null
    $stashMade = (git stash list | Select-String -SimpleMatch $stashMarker) -ne $null
  } elseif ($AllowDirty) {
    Write-Warn 'Proceeding with dirty working tree as requested (--allow-dirty).'
  } else {
    Fail 'Working tree is not clean. Commit, stash, rerun with --allow-dirty, or use --autostash.'
  }
}

# Ensure origin exists
git remote get-url origin *> $null 2>&1
if ($LASTEXITCODE -ne 0) { Fail "Remote 'origin' not found. Add it with: git remote add origin <url>" }

Write-Info "Fetching latest refs from origin"
git fetch --prune origin

# Determine default branch
$MainBranch = ''
git show-ref --verify --quiet refs/remotes/origin/main *> $null 2>&1
if ($LASTEXITCODE -eq 0) { $MainBranch = 'main' }
elseif (git show-ref --verify --quiet refs/remotes/origin/master *> $null 2>&1; $LASTEXITCODE -eq 0) { $MainBranch = 'master' }
else { Fail "Neither origin/main nor origin/master found. Cannot determine default branch." }

Write-Info "Default branch detected: $MainBranch"

# Ensure we are on local main/master, creating it if needed
git show-ref --verify --quiet "refs/heads/$MainBranch" *> $null 2>&1
if ($LASTEXITCODE -eq 0) {
  Write-Info "Switching to local $MainBranch"
  git switch $MainBranch
} else {
  Write-Info "Creating local $MainBranch tracking origin/$MainBranch"
  git switch -c $MainBranch --track "origin/$MainBranch"
}

# Fast-forward local to remote head
Write-Info "Fast-forwarding $MainBranch to origin/$MainBranch"
git merge --ff-only "origin/$MainBranch"
if ($LASTEXITCODE -ne 0) { Fail "Unable to fast-forward $MainBranch; local history diverged. Resolve manually." }

# Find most recently updated remote branch under origin/claude/
Write-Info 'Locating latest remote branch matching ^origin/claude/'
$refs = git for-each-ref --sort=-committerdate --format='%(refname:short)' refs/remotes/origin
$claude = $refs | Where-Object { $_ -match '^origin/claude/' } | Select-Object -First 1
if (-not $claude) { Fail 'No remote branch matching ^origin/claude/ found on origin.' }
Write-Info "Selected branch: $claude"

# Show preview of incoming commits
Write-Info "Previewing commits to merge (origin/$MainBranch..$claude)"
git --no-pager log --oneline --decorate --graph "origin/$MainBranch..$claude" | Out-Host

# Perform merge with a merge commit
Write-Info "Merging $claude into $MainBranch"
git merge --no-ff --no-edit "$claude"
if ($LASTEXITCODE -ne 0) {
  Write-Warn 'Merge reported conflicts. Resolve them, then run: git add -A; git commit'
  exit 2
}

if ($PushAfter) {
  Write-Info "Pushing $MainBranch to origin"
  git push origin "$MainBranch"
}

Write-Info "Done. $MainBranch now contains $claude."

# Restore stashed changes
if ($stashMade) {
  Write-Info 'Restoring stashed local changes'
  git stash pop
  if ($LASTEXITCODE -ne 0) {
    Write-Warn 'Conflicts occurred while applying stashed changes. Resolve and commit manually.'
  }
}

# -----------------------------------------------------------------------------
# Quick one-liners to download and run this script anywhere
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
# -----------------------------------------------------------------------------
