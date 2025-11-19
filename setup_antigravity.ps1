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

function Set-Settings-For-Install {
    # INJECT standard 'extensions.gallery' so CLI works
    param($json)
    $json["extensions.gallery"] = @{
        "serviceUrl" = "https://marketplace.visualstudio.com/_apis/public/gallery";
        "cacheUrl" = "https://marketplace.visualstudio.com/_apis/public/gallery/cache";
        "itemUrl" = "https://marketplace.visualstudio.com/items"
    }
    return $json
}

function Set-Settings-For-Runtime {
    # REMOVE 'extensions.gallery' and USE 'antigravity' keys so UI works
    param($json)
    if ($json.ContainsKey("extensions.gallery")) { $json.Remove("extensions.gallery") }
    
    $json["antigravity.marketplaceExtensionGalleryServiceURL"] = "https://marketplace.visualstudio.com/_apis/public/gallery"
    $json["antigravity.marketplaceGalleryItemURL"] = "https://marketplace.visualstudio.com/items"

    # Paths
    if ($InstallR) {
        $radianCmd = Get-Command radian -ErrorAction SilentlyContinue
        if ($radianCmd) { $json["r.rterm.windows"] = $radianCmd.Source }
        $json["r.plot.useHttpgd"] = $true
        $json["r.bracketedPaste"] = $true
        $json["r.sessionWatcher"] = $true
    }
    if ($InstallPython) {
        $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
        if ($pythonCmd) { $json["python.defaultInterpreterPath"] = $pythonCmd.Source }
        $json["python.terminal.activateEnvironment"] = $true
    }
    return $json
}

function Update-SettingsFile {
    param($Mode)
    if (-not (Test-Path $SettingsDir)) { New-Item -ItemType Directory -Path $SettingsDir -Force | Out-Null }
    if (-not (Test-Path $SettingsFile)) { Set-Content -Path $SettingsFile -Value '{}' }
    
    try {
        $raw = Get-Content $SettingsFile -Raw
        if ($PSVersionTable.PSVersion.Major -ge 6) { $settings = $raw | ConvertFrom-Json -AsHashtable } 
        else { $settings = @{}; ($raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $settings[$_.Name] = $_.Value } }
    } catch { $settings = @{} }

    if ($Mode -eq "INSTALL") { $settings = Set-Settings-For-Install $settings }
    else { $settings = Set-Settings-For-Runtime $settings }

    $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $SettingsFile
}

function Install-Extensions {
    Write-Info "Temporarily enabling CLI Marketplace..."
    Update-SettingsFile -Mode "INSTALL"

    Write-Info "Installing Extensions (Pinned to 2025)..."
    $extensions = @()
    
    if ($InstallR) { 
        $extensions += @("REditorSupport.r", "RDebugger.r-debugger", "Posit.shiny") 
    }
    
    if ($InstallPython) { 
        # FORCE 2025 VERSIONS: We know these work manually. CLI needs to be forced.
        $extensions += @("ms-python.python@2025.18.0", "ms-toolsai.jupyter@2025.8.0") 
    }

    foreach ($ext in $extensions) {
        Write-Host "  Installing $ext... " -NoNewline
        try {
            $proc = Start-Process -FilePath $EditorCmd -ArgumentList "--install-extension $ext --force" -NoNewWindow -Wait -PassThru -RedirectStandardError "$env:TEMP\ag_err.log"
            if ($proc.ExitCode -eq 0) { Write-Host "OK" -F Green }
            else { Write-Host "FAILED" -F Red }
        } catch { Write-Host "ERROR" -F Red }
    }
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
    
    Install-Extensions
    
    Write-Info "Applying Final UI Settings..."
    Update-SettingsFile -Mode "RUNTIME"
    
    Write-Success "Antigravity Setup Complete!"
}

Main