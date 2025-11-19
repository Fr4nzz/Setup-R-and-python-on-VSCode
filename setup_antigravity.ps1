#
# Antigravity R & Python Setup - Windows
# Based on VSCode Setup by Fr4nzz
#

param(
    [switch]$ROnly,
    [switch]$PythonOnly,
    [switch]$SkipRadian,
    [switch]$NonInteractive,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# --- CONFIGURATION ---
$SettingsDir = "$env:APPDATA\Antigravity\User"
$SettingsFile = "$SettingsDir\settings.json"

# Dynamic CLI Detection
$EditorCmd = "antigravity"
$CmdInfo = Get-Command "antigravity" -ErrorAction SilentlyContinue
if ($CmdInfo) {
    $EditorCmd = $CmdInfo.Source
    Write-Host "[INFO] Resolved Antigravity CLI: $EditorCmd" -ForegroundColor Gray
}
# ---------------------

if ($Help) {
    Write-Host @"
Antigravity Setup Script
Usage: .\setup_antigravity.ps1
"@
    exit 0
}

$InstallR = -not $PythonOnly
$InstallPython = -not $ROnly
$InstallRadian = -not $SkipRadian

function Write-Info { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Blue }
function Write-Success { param([string]$Msg) Write-Host "[SUCCESS] $Msg" -ForegroundColor Green }
function Write-Error-Msg { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }
function Write-Warn { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }

function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($user)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Command {
    param([string]$Command)
    try { Get-Command $Command -ErrorAction Stop | Out-Null; return $true } catch { return $false }
}

# --- INSTALLATION LOGIC ---

function Install-Chocolatey {
    if (Test-Command choco) { return }
    Write-Info "Installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

$script:RBinPath = $null
function Find-R {
    $searchPaths = @("$env:ProgramFiles\R\*\bin\x64", "$env:ProgramFiles\R\*\bin")
    $allRPaths = @()
    foreach ($pattern in $searchPaths) {
        $found = Get-Item $pattern -ErrorAction SilentlyContinue
        if ($found) { foreach ($p in $found) { if ($allRPaths -notcontains $p.FullName) { $allRPaths += $p.FullName } } }
    }
    if ($allRPaths.Count -gt 0) { return ($allRPaths | Sort-Object -Descending)[0] }
    return $null
}

function Get-RscriptCommand {
    if ($script:RBinPath) { return Join-Path $script:RBinPath "Rscript.exe" }
    elseif (Test-Command Rscript) { return "Rscript" }
    else { return $null }
}

function Install-R {
    if (-not $InstallR) { return }
    if (Get-Command "R.exe" -ErrorAction SilentlyContinue) { Write-Success "R is installed"; return }
    Write-Info "Installing R..."
    choco install r.project -y
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    if (-not (Test-Command Rscript)) {
        $rBinPath = Find-R
        if ($rBinPath) { $script:RBinPath = $rBinPath; Write-Success "R found manually." }
    }
}

function Configure-R-Packages {
    if (-not $InstallR) { return }
    $rProfilePath = "$env:USERPROFILE\Documents\.Rprofile"
    $rProfileDir = Split-Path $rProfilePath -Parent
    if (-not (Test-Path $rProfileDir)) { New-Item -ItemType Directory -Path $rProfileDir -Force | Out-Null }
    if (-not (Test-Path $rProfilePath)) { Set-Content -Path $rProfilePath -Value 'local({ options(repos = c(CRAN = "https://cloud.r-project.org")) })' }
}

function Install-R-Packages {
    if (-not $InstallR) { return }
    Write-Info "Installing R packages..."
    $rscriptCmd = Get-RscriptCommand
    if (-not $rscriptCmd) { Write-Error-Msg "Rscript not found."; return }
    try { $ver = & $rscriptCmd -e "cat(paste0(R.version.string))"; Write-Host "  Detected: $ver" -ForegroundColor Gray } catch {}
    $rCode = "packages <- c('languageserver', 'httpgd', 'shiny', 'shinyWidgets'); for (pkg in packages) { if (!requireNamespace(pkg, quietly = TRUE)) { tryCatch(install.packages(pkg, repos = 'https://cloud.r-project.org', type = ifelse(.Platform`$OS.type == 'windows', 'both', 'source'), quiet = TRUE), error=function(e) cat('Failed to install', pkg, '\n')) } }"
    & $rscriptCmd -e $rCode
}

function Install-Radian {
    if (-not $InstallR -or -not $InstallRadian) { return }
    if (Test-Command radian) { Write-Success "radian is installed"; return }
    if (-not (Test-Command python)) { choco install python -y; $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User") }
    python -m pip install --user radian watchdog
}

function Install-Python {
    if (-not $InstallPython) { return }
    if (Test-Command python) { Write-Success "Python is installed"; return }
    choco install python -y
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

# --- ANTIGRAVITY LOGIC ---

function Check-Antigravity {
    if ((Test-Path $EditorCmd) -or (Get-Command $EditorCmd -ErrorAction SilentlyContinue)) {
        Write-Success "Antigravity CLI detected."
    } else {
        Write-Error-Msg "Antigravity CLI not found at '$EditorCmd'."
        Write-Host "Please install Antigravity manually and ensure it's in your PATH."
        exit 1
    }
}

function Update-SettingsFile {
    param($Mode) # "STANDARD" (Google keys only) or "HACK" (Inject extensions.gallery)
    
    if (-not (Test-Path $SettingsDir)) { New-Item -ItemType Directory -Path $SettingsDir -Force | Out-Null }
    if (-not (Test-Path $SettingsFile)) { Set-Content -Path $SettingsFile -Value '{}' }

    try {
        $json = Get-Content $SettingsFile -Raw
        if ($PSVersionTable.PSVersion.Major -ge 6) { $settings = $json | ConvertFrom-Json -AsHashtable } 
        else { 
            $settings = @{}
            ($json | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $settings[$_.Name] = $_.Value }
        }
    } catch { $settings = @{} }

    # ALWAYS set the correct Google Antigravity keys
    $settings["antigravity.marketplaceExtensionGalleryServiceURL"] = "https://marketplace.visualstudio.com/_apis/public/gallery"
    $settings["antigravity.marketplaceGalleryItemURL"] = "https://marketplace.visualstudio.com/items"

    # Handle the "Swap" Logic
    if ($Mode -eq "HACK") {
        # Inject standard key so dumb CLI can see Microsoft Marketplace
        $settings["extensions.gallery"] = @{
            "serviceUrl" = "https://marketplace.visualstudio.com/_apis/public/gallery";
            "cacheUrl" = "https://marketplace.visualstudio.com/_apis/public/gallery/cache";
            "itemUrl" = "https://marketplace.visualstudio.com/items"
        }
    } elseif ($settings.ContainsKey("extensions.gallery")) {
        # Remove standard key to prevent UI conflicts
        $settings.Remove("extensions.gallery")
    }

    # Path Configuration
    if ($InstallR) {
        $radianCmd = Get-Command radian -ErrorAction SilentlyContinue
        if ($radianCmd) { $settings["r.rterm.windows"] = $radianCmd.Source }
        $settings["r.plot.useHttpgd"] = $true
        $settings["r.bracketedPaste"] = $true
        $settings["r.sessionWatcher"] = $true
    }

    if ($InstallPython) {
        $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
        if ($pythonCmd) { $settings["python.defaultInterpreterPath"] = $pythonCmd.Source }
        $settings["python.terminal.activateEnvironment"] = $true
    }

    $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $SettingsFile
}

function Run-Extension-Install {
    param($ext)
    try {
        $proc = Start-Process -FilePath $EditorCmd -ArgumentList "--install-extension $ext --force" -NoNewWindow -Wait -PassThru -RedirectStandardError "$env:TEMP\ag_err.log"
        return $proc.ExitCode
    } catch {
        return 1
    }
}

function Install-Extensions {
    Write-Info "Setting up Marketplace Configuration..."
    
    # 1. Try the "Correct" way first (Google Settings only)
    Update-SettingsFile -Mode "STANDARD"

    $extensions = @()
    if ($InstallR) { $extensions += @("REditorSupport.r", "RDebugger.r-debugger", "Posit.shiny") }
    if ($InstallPython) { 
        # Note: We use the latest versions here. The environment check handles compatibility.
        $extensions += @("ms-python.python@2025.18.0", "ms-toolsai.jupyter@2025.8.0") 
    }

    $hackEnabled = $false

    foreach ($ext in $extensions) {
        Write-Host "  Installing $ext... " -NoNewline
        
        # Attempt 1: Install with current settings
        $exitCode = Run-Extension-Install $ext
        
        if ($exitCode -ne 0 -and -not $hackEnabled) {
            # FAILURE DETECTED: The CLI likely didn't respect the Google keys.
            Write-Host "RETRYING (Swap Mode)" -F Yellow
            
            # Enable "Hack Mode": Inject standard VS Code keys
            Update-SettingsFile -Mode "HACK"
            $hackEnabled = $true
            
            # Attempt 2: Install with Hack settings
            $exitCode = Run-Extension-Install $ext
        }

        if ($exitCode -eq 0) { Write-Host "OK" -F Green }
        else { Write-Host "FAILED" -F Red }
    }

    # Final Cleanup: Ensure we are back to STANDARD mode so UI doesn't break
    Write-Info "Finalizing Configuration..."
    Update-SettingsFile -Mode "STANDARD"
    Write-Success "Antigravity Configured."
}

function Main {
    if (-not (Test-Administrator)) { Write-Error-Msg "Run as Administrator required."; exit 1 }
    Check-Antigravity
    Install-Chocolatey
    Install-R
    Configure-R-Packages
    Install-R-Packages
    Install-Radian
    Install-Python
    
    Install-Extensions # Now handles the settings logic internally
    
    Write-Success "Antigravity Setup Complete!"
}

Main