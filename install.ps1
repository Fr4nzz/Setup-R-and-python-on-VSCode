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

# Script-level variable to store selected R bin path
$script:RBinPath = $null

# Find all R installations and let user choose
function Find-And-Select-R {
    param(
        [bool]$Interactive = $true
    )

    # Common R installation paths on Windows
    $searchPaths = @(
        "$env:ProgramFiles\R\*\bin\x64",
        "$env:ProgramFiles\R\*\bin",
        "${env:ProgramFiles(x86)}\R\*\bin\x64",
        "${env:ProgramFiles(x86)}\R\*\bin",
        "C:\Program Files\R\*\bin\x64",
        "C:\Program Files\R\*\bin"
    )

    # Find all R installations
    $allRPaths = @()
    foreach ($pattern in $searchPaths) {
        $found = Get-Item $pattern -ErrorAction SilentlyContinue
        if ($found) {
            foreach ($path in $found) {
                # Avoid duplicates
                if ($allRPaths -notcontains $path.FullName) {
                    $allRPaths += $path.FullName
                }
            }
        }
    }

    if ($allRPaths.Count -eq 0) {
        return $null
    }

    # Sort by version (descending) - latest first
    $allRPaths = $allRPaths | Sort-Object -Descending

    $selectedPath = $null

    # If multiple R versions found and interactive mode
    if ($allRPaths.Count -gt 1 -and $Interactive) {
        Write-Host ""
        Write-Host "[INFO] Multiple R installations found:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $allRPaths.Count; $i++) {
            $path = $allRPaths[$i]
            # Extract version from path (e.g., R-4.3.2)
            $version = "unknown"
            if ($path -match "R[/\\]R-([0-9.]+)[/\\]") {
                $version = $matches[1]
            }
            Write-Host "  [$($i + 1)] R $version - $path" -ForegroundColor White
        }
        Write-Host ""

        $defaultChoice = 1
        $prompt = "Select R version to use (1-$($allRPaths.Count)) [default: $defaultChoice (latest)]"
        $userInput = Read-Host $prompt

        if ([string]::IsNullOrWhiteSpace($userInput)) {
            $selection = $defaultChoice
        } else {
            $selection = [int]$userInput
        }

        if ($selection -ge 1 -and $selection -le $allRPaths.Count) {
            $selectedPath = $allRPaths[$selection - 1]
        } else {
            Write-Warn "Invalid selection. Using latest version (default)."
            $selectedPath = $allRPaths[0]
        }
    } else {
        # Single installation or non-interactive mode - use latest (first in sorted array)
        $selectedPath = $allRPaths[0]
    }

    Write-Info "Selected R at: $selectedPath"

    # Ask if user wants to add to PATH (default no)
    $addToPath = $false
    if ($Interactive) {
        Write-Host ""
        $pathPrompt = "Add R to PATH environment variable? (y/N) [default: N]"
        $pathInput = Read-Host $pathPrompt
        $addToPath = ($pathInput -eq "y" -or $pathInput -eq "Y")
    }

    if ($addToPath) {
        # Add to current session PATH
        if ($env:Path -notlike "*$selectedPath*") {
            $env:Path = "$selectedPath;$env:Path"
            Write-Info "Added R to current session PATH"
        }

        # Add to user PATH permanently
        $userPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
        if ($userPath -notlike "*$selectedPath*") {
            [System.Environment]::SetEnvironmentVariable("Path", "$userPath;$selectedPath", [System.EnvironmentVariableTarget]::User)
            Write-Success "Added R to user PATH permanently"
        }
    } else {
        Write-Info "R will not be added to PATH (you can add it manually later if needed)"
    }

    return $selectedPath
}

# Helper function to get Rscript command (either from PATH or using stored path)
function Get-RscriptCommand {
    if ($script:RBinPath) {
        return Join-Path $script:RBinPath "Rscript.exe"
    } elseif (Test-Command Rscript) {
        return "Rscript"
    } else {
        return $null
    }
}

# Install R
function Install-R {
    param(
        [bool]$Interactive = $true
    )

    if (-not $InstallR) {
        return
    }

    # Check for Rscript in PATH first
    if (Test-Command Rscript) {
        try {
            $rVersion = & Rscript --version 2>&1 | Select-String "R version" | Select-Object -First 1
            if (-not $rVersion) {
                $rVersion = "installed"
            }
            Write-Success "R is already installed ($rVersion)"
            return
        } catch {
            Write-Success "R is already installed"
            return
        }
    }

    # Rscript not in PATH, but R might be installed - search for it
    Write-Info "Rscript not in PATH, checking for R installation..."
    $rBinPath = Find-And-Select-R -Interactive $Interactive
    if ($rBinPath) {
        $script:RBinPath = $rBinPath
        $rscriptCmd = Get-RscriptCommand
        if ($rscriptCmd) {
            try {
                $rVersion = & $rscriptCmd --version 2>&1 | Select-String "R version" | Select-Object -First 1
                if (-not $rVersion) {
                    $rVersion = "installed"
                }
                Write-Success "R is already installed ($rVersion)"
                return
            } catch {
                Write-Success "R is already installed"
                return
            }
        }
    }

    Write-Info "Installing R..."
    choco install r.project -y

    # Refresh environment
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    # Try to find R installation if not in PATH
    if (-not (Test-Command Rscript)) {
        Write-Info "Rscript not in PATH, searching for R installation..."
        $rBinPath = Find-And-Select-R -Interactive $Interactive
        if ($rBinPath) {
            $script:RBinPath = $rBinPath
            Write-Success "R found and configured"
        }
    }

    # Verify installation
    $rscriptCmd = Get-RscriptCommand
    if ($rscriptCmd) {
        Write-Success "R installed successfully"
    } else {
        Write-Error-Message "R installation failed - could not find Rscript"
        exit 1
    }
}

# Configure R to use CRAN (Windows gets binaries by default, no PPM needed)
function Configure-R-Packages {
    if (-not $InstallR) {
        return
    }

    # Note: Windows CRAN mirrors serve binaries by default, so we don't need PPM
    # We'll just set a default CRAN mirror in .Rprofile for convenience
    Write-Info "Configuring R to use CRAN mirror..."

    $rProfilePath = "$env:USERPROFILE\Documents\.Rprofile"
    $rProfileDir = Split-Path $rProfilePath -Parent

    if (-not (Test-Path $rProfileDir)) {
        New-Item -ItemType Directory -Path $rProfileDir -Force | Out-Null
    }

    $rProfileContent = @'
local({
  options(
    repos = c(
      CRAN = "https://cloud.r-project.org"
    )
  )
})
'@

    Set-Content -Path $rProfilePath -Value $rProfileContent
    Write-Success "CRAN mirror configured in $rProfilePath"
}

# Install R packages
function Install-R-Packages {
    if (-not $InstallR) {
        return
    }

    Write-Info "Installing R packages (languageserver, httpgd, shiny, shinyWidgets)..."

    # Get Rscript command (from PATH or using full path)
    $rscriptCmd = Get-RscriptCommand
    if (-not $rscriptCmd) {
        Write-Error-Message "Rscript not found. Cannot install R packages."
        exit 1
    }

    # Use Rscript with -e parameter and explicit CRAN repo (Windows binaries by default)
    # Pass repos parameter directly to ensure CRAN mirror is set even if .Rprofile isn't loaded
    $rCode = "packages <- c('languageserver', 'httpgd', 'shiny', 'shinyWidgets'); for (pkg in packages) { if (!requireNamespace(pkg, quietly = TRUE)) { cat(sprintf('Installing %s...\n', pkg)); install.packages(pkg, repos = 'https://cloud.r-project.org', quiet = TRUE) } else { cat(sprintf('%s is already installed\n', pkg)) } }"

    & $rscriptCmd -e $rCode

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

    # Refresh PATH to get any updates
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

    # Add Python Scripts directory to PATH
    $pythonScriptsPattern = "$env:USERPROFILE\AppData\Roaming\Python\Python*\Scripts"
    $pythonScriptsPaths = Get-Item $pythonScriptsPattern -ErrorAction SilentlyContinue

    if ($pythonScriptsPaths) {
        # Get the most recent Python Scripts directory
        $scriptPath = $pythonScriptsPaths | Sort-Object -Property Name -Descending | Select-Object -First 1 | Select-Object -ExpandProperty FullName

        if ($scriptPath) {
            Write-Info "Found Python Scripts at: $scriptPath"

            # Add to current session PATH
            if ($env:Path -notlike "*$scriptPath*") {
                $env:Path = "$scriptPath;$env:Path"
                Write-Info "Added Python Scripts to current session PATH"
            }

            # Add to user PATH permanently
            $userPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
            if ($userPath -notlike "*$scriptPath*") {
                [System.Environment]::SetEnvironmentVariable("Path", "$userPath;$scriptPath", [System.EnvironmentVariableTarget]::User)
                Write-Info "Added Python Scripts to user PATH permanently"
            }
        }
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

    # Read existing settings (handle PowerShell 5.1 compatibility)
    $settingsJson = Get-Content $settingsFile -Raw

    # Try to use -AsHashtable (PowerShell 6+), otherwise convert manually
    $settings = $null
    try {
        # PowerShell 6+ has -AsHashtable parameter
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $settings = $settingsJson | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        } else {
            # PowerShell 5.1 - convert PSCustomObject to hashtable manually
            $settingsObj = $settingsJson | ConvertFrom-Json -ErrorAction Stop
            $settings = @{}
            if ($settingsObj) {
                $settingsObj.PSObject.Properties | ForEach-Object {
                    $settings[$_.Name] = $_.Value
                }
            }
        }
    } catch {
        $settings = @{}
    }

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
        Write-Host ""
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
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
    Install-R -Interactive (-not $NonInteractive)
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
        $rscriptCmd = Get-RscriptCommand
        if ($rscriptCmd) {
            try {
                $rVersion = & $rscriptCmd --version 2>&1 | Select-String "R version" | Select-Object -First 1
                Write-Host "  - R version: $rVersion"
            } catch {
                Write-Host "  - R: installed"
            }
        } else {
            Write-Host "  - R: installed"
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
