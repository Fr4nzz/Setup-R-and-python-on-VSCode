#
# VSCode R & Python Setup - Windows Installation Script
# https://github.com/Fr4nzz/Setup-R-and-python-on-VSCode
#
# Usage: .\install.ps1 [-ROnly] [-PythonOnly] [-SkipVSCode] [-SkipRadian] [-NonInteractive] [-Help]
#
# Parameters:
#   -ROnly              Install only R and R tools
#   -PythonOnly         Install only Python and Python tools
#   -SkipVSCode         Skip VSCode installation
#   -SkipRadian         Skip radian installation
#   -NonInteractive     Run without prompts
#   -Help               Show help message
#

param(
    [switch]$ROnly,
    [switch]$PythonOnly,
    [switch]$SkipVSCode,
    [switch]$SkipRadian,
    [switch]$NonInteractive,
    [switch]$Help
)

# Enable strict mode
$ErrorActionPreference = "Stop"

# Show help
if ($Help) {
    Write-Host @"
VSCode R & Python Setup - Windows Installation Script

Usage: .\install.ps1 [-ROnly] [-PythonOnly] [-SkipVSCode] [-SkipRadian] [-NonInteractive] [-Help]

Parameters:
  -ROnly              Install only R and R tools
  -PythonOnly         Install only Python and Python tools
  -SkipVSCode         Skip VSCode installation
  -SkipRadian         Skip radian installation
  -NonInteractive     Run without prompts
  -Help               Show this help message

Examples:
  .\install.ps1                    # Install everything (R + Python + VSCode)
  .\install.ps1 -ROnly            # Install only R tools
  .\install.ps1 -PythonOnly       # Install only Python tools
  .\install.ps1 -SkipVSCode       # Configure existing VSCode installation

For more information, visit: https://github.com/Fr4nzz/Setup-R-and-python-on-VSCode
"@
    exit 0
}

# Set installation flags
$InstallR = -not $PythonOnly
$InstallPython = -not $ROnly
$InstallVSCode = -not $SkipVSCode
$InstallRadian = -not $SkipRadian

# Colors for output
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error-Message {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Check if running as administrator
function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($user)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check if command exists
function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Install Chocolatey
function Install-Chocolatey {
    if (Test-Command choco) {
        Write-Success "Chocolatey is already installed"
        return
    }

    Write-Info "Installing Chocolatey package manager..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    # Refresh environment
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    if (Test-Command choco) {
        Write-Success "Chocolatey installed successfully"
    } else {
        Write-Error-Message "Chocolatey installation failed"
        exit 1
    }
}

# Install VSCode
function Install-VSCode {
    if (-not $InstallVSCode) {
        Write-Info "Skipping VSCode installation"
        return
    }

    if (Test-Command code) {
        Write-Success "VSCode is already installed"
        return
    }

    Write-Info "Installing VSCode..."
    choco install vscode -y

    # Refresh environment
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    if (Test-Command code) {
        Write-Success "VSCode installed successfully"
    } else {
        Write-Warn "VSCode installation may have failed. Please check manually."
    }
}

# Install R
function Install-R {
    if (-not $InstallR) {
        return
    }

    if (Test-Command R) {
        $rVersion = (R --version 2>&1 | Select-String "R version" | Select-Object -First 1)
        Write-Success "R is already installed ($rVersion)"
        return
    }

    Write-Info "Installing R..."
    choco install r.project -y

    # Refresh environment
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    if (Test-Command R) {
        Write-Success "R installed successfully"
    } else {
        Write-Error-Message "R installation failed"
        exit 1
    }
}

# Configure R to use PPM
function Configure-R-Packages {
    if (-not $InstallR) {
        return
    }

    Write-Info "Configuring R to use Posit Public Package Manager (PPM)..."

    $rProfilePath = "$env:USERPROFILE\Documents\.Rprofile"
    $rProfileDir = Split-Path $rProfilePath -Parent

    if (-not (Test-Path $rProfileDir)) {
        New-Item -ItemType Directory -Path $rProfileDir -Force | Out-Null
    }

    $rProfileContent = @'
local({
  options(
    repos = c(
      CRAN = "https://packagemanager.posit.co/cran/latest"
    )
  )
})
'@

    Set-Content -Path $rProfilePath -Value $rProfileContent
    Write-Success "PPM configured in $rProfilePath"
}

# Install R packages
function Install-R-Packages {
    if (-not $InstallR) {
        return
    }

    Write-Info "Installing R packages (languageserver, httpgd, shiny, shinyWidgets)..."

    $rScript = @'
packages <- c("languageserver", "httpgd", "shiny", "shinyWidgets")
for (pkg in packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(sprintf("Installing %s...\n", pkg))
    install.packages(pkg, quiet = TRUE)
  } else {
    cat(sprintf("%s is already installed\n", pkg))
  }
}
'@

    # Use --quiet instead of --vanilla so Rprofile is read
    $rScript | R --quiet --no-save --slave

    Write-Success "R packages installed"
}

# Install radian
function Install-Radian {
    if (-not $InstallR -or -not $InstallRadian) {
        return
    }

    if (Test-Command radian) {
        Write-Success "radian is already installed"
        return
    }

    Write-Info "Installing radian (enhanced R console) and watchdog (for Shiny devmode)..."

    # Ensure pip is available
    if (-not (Test-Command python)) {
        Write-Info "Python not found. Installing Python first..."
        choco install python -y
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }

    # Install radian and watchdog
    python -m pip install --user radian watchdog

    # Add Python scripts to PATH
    $pythonScripts = "$env:USERPROFILE\AppData\Roaming\Python\Python*\Scripts"
    $scriptPath = Get-Item $pythonScripts -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    if ($scriptPath -and $env:Path -notlike "*$scriptPath*") {
        [System.Environment]::SetEnvironmentVariable("Path", $env:Path + ";$scriptPath", [System.EnvironmentVariableTarget]::User)
        $env:Path += ";$scriptPath"
    }

    if (Test-Command radian) {
        Write-Success "radian installed successfully"
    } else {
        Write-Warn "radian installation may have failed. You can use default R console."
    }
}

# Install Python
function Install-Python {
    if (-not $InstallPython) {
        return
    }

    if (Test-Command python) {
        $pythonVersion = (python --version 2>&1)
        Write-Success "Python is already installed ($pythonVersion)"
        return
    }

    Write-Info "Installing Python..."
    choco install python -y

    # Refresh environment
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    if (Test-Command python) {
        Write-Success "Python installed successfully"
    } else {
        Write-Error-Message "Python installation failed"
        exit 1
    }
}

# Install VSCode extensions
function Install-VSCode-Extensions {
    if (-not (Test-Command code)) {
        Write-Warn "VSCode not found. Skipping extension installation."
        return
    }

    Write-Info "Installing VSCode extensions..."

    $extensions = @()

    if ($InstallR) {
        $extensions += @("REditorSupport.r", "RDebugger.r-debugger", "Posit.shiny")
    }

    if ($InstallPython) {
        $extensions += @("ms-python.python", "ms-toolsai.jupyter")
    }

    foreach ($ext in $extensions) {
        Write-Info "Installing extension: $ext"
        code --install-extension $ext 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "Failed to install $ext (may already be installed)"
        }
    }

    Write-Success "VSCode extensions installed"
}

# Configure VSCode settings
function Configure-VSCode {
    if (-not (Test-Command code)) {
        Write-Warn "VSCode not found. Skipping configuration."
        return
    }

    Write-Info "Configuring VSCode settings..."

    $settingsDir = "$env:APPDATA\Code\User"
    $settingsFile = "$settingsDir\settings.json"

    # Create directory if it doesn't exist
    if (-not (Test-Path $settingsDir)) {
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
    }

    # Create settings file if it doesn't exist
    if (-not (Test-Path $settingsFile)) {
        Set-Content -Path $settingsFile -Value '{}'
    }

    # Read existing settings
    $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue
    if (-not $settings) {
        $settings = @{}
    }

    # Configure R settings
    if ($InstallR) {
        $radianCmd = Get-Command radian -ErrorAction SilentlyContinue
        if ($radianCmd) {
            $radianPath = $radianCmd.Source
            # Escape backslashes for JSON
            $radianPath = $radianPath -replace '\\', '\\'
            $settings["r.rterm.windows"] = $radianPath
        }

        $settings["r.alwaysUseActiveTerminal"] = $false
        $settings["r.bracketedPaste"] = $true
        $settings["r.plot.useHttpgd"] = $true
        $settings["r.sessionWatcher"] = $true
        $settings["r.rterm.option"] = @("--no-save", "--no-restore")

        if (-not $settings.ContainsKey("[r]")) {
            $settings["[r]"] = @{}
        }
        $settings["[r]"]["editor.inlineSuggest.enabled"] = $false
    }

    # Configure Python settings
    if ($InstallPython) {
        $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
        if ($pythonCmd) {
            $pythonPath = $pythonCmd.Source
            # Escape backslashes for JSON
            $pythonPath = $pythonPath -replace '\\', '\\'
            $settings["python.defaultInterpreterPath"] = $pythonPath
        }

        $settings["python.terminal.activateEnvironment"] = $true

        if (-not $settings.ContainsKey("[python]")) {
            $settings["[python]"] = @{}
        }
        $settings["[python]"]["editor.formatOnSave"] = $true
        $settings["[python]"]["editor.inlineSuggest.enabled"] = $false
    }

    # Save settings
    $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsFile

    Write-Success "VSCode settings configured"
}

# Configure VSCode keybindings
function Configure-Keybindings {
    if (-not (Test-Command code)) {
        return
    }

    Write-Info "Configuring VSCode keybindings..."

    $settingsDir = "$env:APPDATA\Code\User"
    $keybindingsFile = "$settingsDir\keybindings.json"

    # Create keybindings file if it doesn't exist
    if (-not (Test-Path $keybindingsFile)) {
        Set-Content -Path $keybindingsFile -Value '[]'
    }

    # Read existing keybindings
    $keybindings = Get-Content $keybindingsFile -Raw | ConvertFrom-Json
    if (-not $keybindings) {
        $keybindings = @()
    } else {
        $keybindings = @($keybindings)
    }

    # Add R keybindings
    if ($InstallR) {
        $keybindings += @(
            @{
                key = "ctrl+enter"
                command = "r.runSelection"
                when = "editorTextFocus && editorLangId == 'r'"
            },
            @{
                key = "ctrl+shift+enter"
                command = "r.runCurrentChunk"
                when = "editorTextFocus && editorLangId == 'r'"
            }
        )
    }

    # Add Python keybindings
    if ($InstallPython) {
        $keybindings += @(
            @{
                key = "ctrl+enter"
                command = "python.execSelectionInTerminal"
                when = "editorTextFocus && editorLangId == 'python'"
            }
        )
    }

    # Save keybindings
    $keybindings | ConvertTo-Json -Depth 10 | Set-Content -Path $keybindingsFile

    Write-Success "VSCode keybindings configured"
}

# Main installation flow
function Main {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "  VSCode R & Python Setup"
    Write-Host "=========================================="
    Write-Host ""

    # Check administrator privileges
    if (-not (Test-Administrator)) {
        Write-Error-Message "This script must be run as Administrator"
        Write-Host "Please right-click PowerShell and select 'Run as Administrator'"
        exit 1
    }

    # Detect system
    $arch = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
    $osVersion = [System.Environment]::OSVersion.Version
    Write-Info "Detected: Windows $osVersion on $arch"

    Write-Host ""
    Write-Host "Installation Configuration:"
    Write-Host "  - Install R: $InstallR"
    if ($InstallR) {
        Write-Host "    - Install radian: $InstallRadian"
    }
    Write-Host "  - Install Python: $InstallPython"
    Write-Host "  - Install VSCode: $InstallVSCode"
    Write-Host ""

    if (-not $NonInteractive) {
        $response = Read-Host "Continue with installation? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Info "Installation cancelled"
            exit 0
        }
    }

    Write-Host ""
    Write-Info "Starting installation..."
    Write-Host ""

    # Install components
    Install-Chocolatey
    Install-VSCode
    Install-R
    Configure-R-Packages
    Install-R-Packages
    Install-Radian
    Install-Python
    Install-VSCode-Extensions
    Configure-VSCode
    Configure-Keybindings

    Write-Host ""
    Write-Host "=========================================="
    Write-Success "Installation complete!"
    Write-Host "=========================================="
    Write-Host ""

    if ($InstallR) {
        Write-Host "R Environment:"
        if (Test-Command R) {
            $rVersion = (R --version 2>&1 | Select-String "R version" | Select-Object -First 1)
            Write-Host "  - R version: $rVersion"
        }
        if (Test-Command radian) {
            $radianPath = (Get-Command radian).Source
            Write-Host "  - Radian: $radianPath"
        }
        Write-Host ""
    }

    if ($InstallPython) {
        Write-Host "Python Environment:"
        if (Test-Command python) {
            $pythonVersion = (python --version 2>&1)
            Write-Host "  - Python version: $pythonVersion"
        }
        Write-Host ""
    }

    if (Test-Command code) {
        Write-Host "VSCode:"
        $codeVersion = (code --version 2>&1 | Select-Object -First 1)
        Write-Host "  - VSCode: $codeVersion"
        Write-Host ""
    }

    Write-Host "Next Steps:"
    if (Test-Command code) {
        Write-Host "  1. Restart VSCode (if running)"
    }
    if ($InstallR) {
        Write-Host "  2. Open an R file (.R) and press Ctrl+Enter to run code"
        Write-Host "  3. For Shiny apps, open app.R and click the Run button"
    }
    if ($InstallPython) {
        Write-Host "  4. Open a Python file (.py) and press Ctrl+Enter to run code"
    }
    Write-Host ""
    Write-Host "For troubleshooting, visit: https://github.com/Fr4nzz/Setup-R-and-python-on-VSCode"
    Write-Host ""
}

# Run main installation
Main
