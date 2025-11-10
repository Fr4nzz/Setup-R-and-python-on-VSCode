#!/usr/bin/env bash
#
# VSCode R & Python Setup - Linux/macOS Installation Script
# https://github.com/Fr4nzz/Setup-R-and-python-on-VSCode
#
# Usage: ./install.sh [OPTIONS]
#
# Options:
#   --r-only              Install only R and R tools
#   --python-only         Install only Python and Python tools
#   --package-manager     Choose R package manager: 'ppm' (default) or 'r2u' (Ubuntu only)
#   --skip-vscode         Skip VSCode installation
#   --skip-radian         Skip radian installation
#   --non-interactive     Run without prompts
#   -h, --help           Show help message
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
INSTALL_R=true
INSTALL_PYTHON=true
INSTALL_VSCODE=true
INSTALL_RADIAN=true
R_PACKAGE_MANAGER="ppm"
NON_INTERACTIVE=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --r-only)
      INSTALL_R=true
      INSTALL_PYTHON=false
      shift
      ;;
    --python-only)
      INSTALL_R=false
      INSTALL_PYTHON=true
      shift
      ;;
    --package-manager)
      R_PACKAGE_MANAGER="$2"
      shift 2
      ;;
    --skip-vscode)
      INSTALL_VSCODE=false
      shift
      ;;
    --skip-radian)
      INSTALL_RADIAN=false
      shift
      ;;
    --non-interactive)
      NON_INTERACTIVE=true
      shift
      ;;
    -h|--help)
      cat <<EOF
VSCode R & Python Setup - Installation Script

Usage: $0 [OPTIONS]

Options:
  --r-only              Install only R and R tools
  --python-only         Install only Python and Python tools
  --package-manager     Choose R package manager: 'ppm' (default) or 'r2u' (Ubuntu only)
  --skip-vscode         Skip VSCode installation
  --skip-radian         Skip radian installation
  --non-interactive     Run without prompts
  -h, --help           Show this help message

Examples:
  $0                                    # Install everything (R + Python + VSCode)
  $0 --r-only                           # Install only R tools
  $0 --python-only                      # Install only Python tools
  $0 --package-manager=r2u              # Use r2u for R packages (Ubuntu only)
  $0 --skip-vscode                      # Configure existing VSCode installation

For more information, visit: https://github.com/Fr4nzz/Setup-R-and-python-on-VSCode
EOF
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Use -h or --help for usage information"
      exit 1
      ;;
  esac
done

# Helper functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Detect OS and architecture
detect_system() {
  OS="$(uname -s)"
  ARCH="$(uname -m)"
  IS_WSL=false

  case "$OS" in
    Linux*)
      OS_TYPE="linux"

      # Detect WSL (Windows Subsystem for Linux)
      if grep -qiE "(microsoft|wsl)" /proc/version 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ]; then
        IS_WSL=true
      fi

      if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="$ID"
        DISTRO_VERSION="$VERSION_ID"
        DISTRO_CODENAME="${VERSION_CODENAME:-}"
      else
        DISTRO="unknown"
      fi
      ;;
    Darwin*)
      OS_TYPE="macos"
      DISTRO="macos"
      DISTRO_VERSION="$(sw_vers -productVersion)"
      ;;
    *)
      log_error "Unsupported OS: $OS"
      exit 1
      ;;
  esac

  case "$ARCH" in
    x86_64|amd64)
      ARCH_TYPE="x86_64"
      ;;
    aarch64|arm64)
      ARCH_TYPE="arm64"
      ;;
    *)
      log_error "Unsupported architecture: $ARCH"
      exit 1
      ;;
  esac

  if [ "$IS_WSL" = true ]; then
    log_info "Detected: WSL - $OS_TYPE ($DISTRO $DISTRO_VERSION) on $ARCH_TYPE"
  else
    log_info "Detected: $OS_TYPE ($DISTRO $DISTRO_VERSION) on $ARCH_TYPE"
  fi
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Install VSCode
install_vscode() {
  if [ "$INSTALL_VSCODE" = false ]; then
    log_info "Skipping VSCode installation"
    return 0
  fi

  if command_exists code; then
    log_success "VSCode is already installed"
    return 0
  fi

  # Special handling for WSL
  if [ "$IS_WSL" = true ]; then
    log_warn "Running in WSL (Windows Subsystem for Linux)"
    log_warn "VSCode should be installed on Windows, not in WSL"
    echo ""
    echo "To set up VSCode for WSL:"
    echo "  1. Install VSCode on Windows: https://code.visualstudio.com/"
    echo "  2. Install the 'Remote - WSL' extension in VSCode"
    echo "  3. The 'code' command will be available in WSL automatically"
    echo "  4. Re-run this script after VSCode is set up"
    echo ""
    log_warn "Skipping VSCode installation in WSL"
    return 0
  fi

  log_info "Installing VSCode..."

  case "$OS_TYPE" in
    linux)
      if [ "$DISTRO" = "ubuntu" ] || [ "$DISTRO" = "debian" ]; then
        # Install dependencies
        sudo apt-get update -qq
        sudo apt-get install -y wget gpg

        # Add Microsoft GPG key and repository
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
        sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
        sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
        rm -f packages.microsoft.gpg

        # Install VSCode
        sudo apt-get update -qq
        sudo apt-get install -y code
      elif [ "$DISTRO" = "fedora" ] || [ "$DISTRO" = "rhel" ] || [ "$DISTRO" = "centos" ]; then
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
        sudo dnf check-update || true
        sudo dnf install -y code
      elif [ "$DISTRO" = "arch" ] || [ "$DISTRO" = "manjaro" ]; then
        # Install from AUR using yay or paru if available, otherwise use official repo
        if command_exists yay; then
          yay -S --noconfirm visual-studio-code-bin
        elif command_exists paru; then
          paru -S --noconfirm visual-studio-code-bin
        else
          log_warn "AUR helper (yay/paru) not found. Installing code from official repo (OSS version)..."
          sudo pacman -S --noconfirm code
        fi
      else
        log_warn "Unknown Linux distribution. Please install VSCode manually from https://code.visualstudio.com/"
      fi
      ;;
    macos)
      if command_exists brew; then
        brew install --cask visual-studio-code
      else
        log_warn "Homebrew not found. Please install VSCode manually from https://code.visualstudio.com/"
        log_warn "Or install Homebrew from https://brew.sh/"
      fi
      ;;
  esac

  if command_exists code; then
    log_success "VSCode installed successfully"
  else
    log_warn "VSCode installation may have failed. Please check manually."
  fi
}

# Install R
install_r() {
  if ! [ "$INSTALL_R" = true ]; then
    return 0
  fi

  if command_exists R; then
    log_success "R is already installed ($(R --version | head -n1))"
  else
    log_info "Installing R..."

    case "$OS_TYPE" in
      linux)
        if [ "$DISTRO" = "ubuntu" ] || [ "$DISTRO" = "debian" ]; then
          # Install dependencies
          sudo apt-get update -qq
          sudo apt-get install -y --no-install-recommends software-properties-common dirmngr gnupg ca-certificates curl

          # Add CRAN repository
          curl -fsSL https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | sudo gpg --dearmor -o /usr/share/keyrings/cran_ubuntu_key.gpg
          echo "deb [arch=${ARCH_TYPE} signed-by=/usr/share/keyrings/cran_ubuntu_key.gpg] https://cloud.r-project.org/bin/linux/ubuntu ${DISTRO_CODENAME}-cran40/" | sudo tee /etc/apt/sources.list.d/cran_r.list >/dev/null

          # Install R
          sudo apt-get update -qq
          sudo apt-get install -y r-base r-base-dev
        elif [ "$DISTRO" = "fedora" ] || [ "$DISTRO" = "rhel" ] || [ "$DISTRO" = "centos" ]; then
          sudo dnf install -y R
        elif [ "$DISTRO" = "arch" ] || [ "$DISTRO" = "manjaro" ]; then
          sudo pacman -S --noconfirm r
        else
          log_warn "Unknown Linux distribution. Please install R manually from https://cloud.r-project.org/"
        fi
        ;;
      macos)
        if command_exists brew; then
          brew install r
        else
          log_warn "Homebrew not found. Please install R manually from https://cloud.r-project.org/"
        fi
        ;;
    esac

    if command_exists R; then
      log_success "R installed successfully"
    else
      log_error "R installation failed"
      exit 1
    fi
  fi
}

# Configure R package manager
configure_r_packages() {
  if ! [ "$INSTALL_R" = true ]; then
    return 0
  fi

  log_info "Configuring R package manager: $R_PACKAGE_MANAGER"

  case "$R_PACKAGE_MANAGER" in
    r2u)
      # r2u is only available on Ubuntu
      if [ "$OS_TYPE" != "linux" ] || ([ "$DISTRO" != "ubuntu" ] && [ "$DISTRO" != "debian" ]); then
        log_error "r2u is only available on Ubuntu/Debian. Using PPM instead."
        R_PACKAGE_MANAGER="ppm"
        configure_r_packages
        return 0
      fi

      log_info "Setting up r2u + bspm..."

      # Add r2u repository
      sudo gpg --homedir /tmp --no-default-keyring \
        --keyring /usr/share/keyrings/r2u.gpg \
        --keyserver keyserver.ubuntu.com \
        --recv-keys A1489FE2AB99A21A 67C2D66C4B1D4339 51716619E084DAB9 2>/dev/null || true

      # Check if r2u is available for this arch and version
      if [ "$ARCH_TYPE" = "x86_64" ] || { [ "$ARCH_TYPE" = "arm64" ] && [ "$DISTRO_CODENAME" = "noble" ]; }; then
        echo "deb [arch=${ARCH_TYPE} signed-by=/usr/share/keyrings/r2u.gpg] https://r2u.stat.illinois.edu/ubuntu ${DISTRO_CODENAME} main" | sudo tee /etc/apt/sources.list.d/r2u.list >/dev/null

        # Set preference for CRAN-Apt packages
        sudo tee /etc/apt/preferences.d/99-cranapt >/dev/null <<'EOF'
Package: *
Pin: release o=CRAN-Apt Project
Pin: release l=CRAN-Apt Packages
Pin-Priority: 700
EOF

        sudo apt-get update -qq

        # Install bspm
        if apt-cache show r-cran-bspm >/dev/null 2>&1; then
          sudo apt-get install -y r-cran-bspm python3-apt python3-dbus
        fi

        # Configure R to use bspm
        sudo tee /etc/R/Rprofile.site >/dev/null <<'EOF'
local({
  codename <- tryCatch(system("lsb_release -cs", intern = TRUE), error = function(e) "noble")
  options(
    repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/__linux__/%s/latest", codename)),
    pkgType = "source"
  )

  if (requireNamespace("bspm", quietly = TRUE)) {
    try({
      bspm::enable()
      options(bspm.sudo = TRUE, bspm.version.check = TRUE)
    }, silent = TRUE)
  }
})
EOF
        log_success "r2u + bspm configured"
      else
        log_warn "r2u not available for $ARCH_TYPE on $DISTRO_CODENAME. Using PPM instead."
        R_PACKAGE_MANAGER="ppm"
        configure_r_packages
      fi
      ;;
    ppm)
      log_info "Setting up Posit Public Package Manager (PPM)..."

      # Create Rprofile configuration
      if [ "$OS_TYPE" = "linux" ]; then
        CODENAME="${DISTRO_CODENAME:-noble}"
        sudo tee /etc/R/Rprofile.site >/dev/null <<EOF
local({
  codename <- tryCatch(system("lsb_release -cs", intern = TRUE), error = function(e) "$CODENAME")
  options(
    repos = c(
      PPM  = sprintf("https://packagemanager.posit.co/cran/__linux__/%s/latest", codename),
      CRAN = "https://cloud.r-project.org"
    ),
    HTTPUserAgent = sprintf(
      "R; R (%s %s %s %s)",
      getRversion(), R.version\$platform, R.version\$arch, R.version\$os
    )
  )
})
EOF
      else
        # macOS uses source packages from PPM
        cat > "$HOME/.Rprofile" <<'EOF'
local({
  options(
    repos = c(
      CRAN = "https://packagemanager.posit.co/cran/latest"
    )
  )
})
EOF
      fi

      log_success "PPM configured"
      ;;
    *)
      log_error "Unknown package manager: $R_PACKAGE_MANAGER"
      exit 1
      ;;
  esac
}

# Install R packages
install_r_packages() {
  if ! [ "$INSTALL_R" = true ]; then
    return 0
  fi

  log_info "Installing R packages (languageserver, httpgd, shiny)..."

  # Use --quiet instead of --vanilla so Rprofile.site is read
  Rscript --quiet --no-save -e '
    packages <- c("languageserver", "httpgd", "shiny")
    for (pkg in packages) {
      if (!requireNamespace(pkg, quietly = TRUE)) {
        cat(sprintf("Installing %s...\n", pkg))
        install.packages(pkg, quiet = TRUE)
      } else {
        cat(sprintf("%s is already installed\n", pkg))
      }
    }
  '

  log_success "R packages installed"
}

# Install radian
install_radian() {
  if ! [ "$INSTALL_R" = true ] || ! [ "$INSTALL_RADIAN" = true ]; then
    return 0
  fi

  if command_exists radian; then
    log_success "radian is already installed"
    return 0
  fi

  log_info "Installing radian (enhanced R console) and watchdog (for Shiny devmode)..."

  # Ensure pip is available
  if ! command_exists pip3 && ! command_exists pip; then
    case "$OS_TYPE" in
      linux)
        if [ "$DISTRO" = "arch" ] || [ "$DISTRO" = "manjaro" ]; then
          sudo pacman -S --noconfirm python-pip
        else
          sudo apt-get update -qq
          sudo apt-get install -y python3-pip
        fi
        ;;
      macos)
        if command_exists brew; then
          brew install python3
        fi
        ;;
    esac
  fi

  # Install radian and watchdog (for Shiny devmode file watching)
  if command_exists pip3; then
    pip3 install --user radian watchdog
  elif command_exists pip; then
    pip install --user radian watchdog
  fi

  # Add ~/.local/bin to PATH if not already there
  LOCAL_BIN="$HOME/.local/bin"
  if [ -d "$LOCAL_BIN" ]; then
    if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
      if [ "$OS_TYPE" = "macos" ]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
      else
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
      fi
      export PATH="$LOCAL_BIN:$PATH"
    fi
  fi

  if command_exists radian; then
    log_success "radian installed successfully"
  else
    log_warn "radian installation may have failed. You can use default R console."
  fi
}

# Install Python
install_python() {
  if ! [ "$INSTALL_PYTHON" = true ]; then
    return 0
  fi

  if command_exists python3; then
    log_success "Python is already installed ($(python3 --version))"
  else
    log_info "Installing Python..."

    case "$OS_TYPE" in
      linux)
        if [ "$DISTRO" = "ubuntu" ] || [ "$DISTRO" = "debian" ]; then
          sudo apt-get update -qq
          sudo apt-get install -y python3 python3-pip python3-venv
        elif [ "$DISTRO" = "fedora" ] || [ "$DISTRO" = "rhel" ] || [ "$DISTRO" = "centos" ]; then
          sudo dnf install -y python3 python3-pip
        elif [ "$DISTRO" = "arch" ] || [ "$DISTRO" = "manjaro" ]; then
          sudo pacman -S --noconfirm python python-pip
        fi
        ;;
      macos)
        if command_exists brew; then
          brew install python3
        else
          log_warn "Homebrew not found. Please install Python manually from https://www.python.org/"
        fi
        ;;
    esac

    if command_exists python3; then
      log_success "Python installed successfully"
    else
      log_error "Python installation failed"
      exit 1
    fi
  fi
}

# Install VSCode extensions
install_vscode_extensions() {
  if ! command_exists code; then
    log_warn "VSCode not found. Skipping extension installation."
    return 0
  fi

  log_info "Installing VSCode extensions..."

  EXTENSIONS=()

  if [ "$INSTALL_R" = true ]; then
    EXTENSIONS+=("REditorSupport.r" "RDebugger.r-debugger" "Posit.shiny")
  fi

  if [ "$INSTALL_PYTHON" = true ]; then
    EXTENSIONS+=("ms-python.python" "ms-toolsai.jupyter")
  fi

  for ext in "${EXTENSIONS[@]}"; do
    log_info "Installing extension: $ext"
    code --install-extension "$ext" 2>/dev/null || log_warn "Failed to install $ext (may already be installed)"
  done

  log_success "VSCode extensions installed"
}

# Configure VSCode settings
configure_vscode() {
  if ! command_exists code; then
    log_warn "VSCode not found. Skipping configuration."
    return 0
  fi

  log_info "Configuring VSCode settings..."

  # Determine settings path
  case "$OS_TYPE" in
    linux)
      SETTINGS_DIR="$HOME/.config/Code/User"
      ;;
    macos)
      SETTINGS_DIR="$HOME/Library/Application Support/Code/User"
      ;;
  esac

  mkdir -p "$SETTINGS_DIR"
  SETTINGS_FILE="$SETTINGS_DIR/settings.json"

  # Create settings file if it doesn't exist
  if [ ! -f "$SETTINGS_FILE" ]; then
    echo '{}' > "$SETTINGS_FILE"
  fi

  # Check if jq is available
  if ! command_exists jq; then
    log_info "Installing jq for JSON manipulation..."
    case "$OS_TYPE" in
      linux)
        if [ "$DISTRO" = "ubuntu" ] || [ "$DISTRO" = "debian" ]; then
          sudo apt-get update -qq
          sudo apt-get install -y jq
        elif [ "$DISTRO" = "fedora" ] || [ "$DISTRO" = "rhel" ] || [ "$DISTRO" = "centos" ]; then
          sudo dnf install -y jq
        elif [ "$DISTRO" = "arch" ] || [ "$DISTRO" = "manjaro" ]; then
          sudo pacman -S --noconfirm jq
        fi
        ;;
      macos)
        if command_exists brew; then
          brew install jq
        fi
        ;;
    esac
  fi

  # Configure R settings
  if [ "$INSTALL_R" = true ] && command_exists jq; then
    RADIAN_PATH="$(command -v radian 2>/dev/null || echo "")"
    R_TERM_SETTING="radian"

    if [ -z "$RADIAN_PATH" ]; then
      R_TERM_SETTING=""
    fi

    TEMP_SETTINGS=$(mktemp)

    if [ -n "$R_TERM_SETTING" ]; then
      if [ "$OS_TYPE" = "macos" ]; then
        jq '. + {
          "r.rterm.mac": "'"$RADIAN_PATH"'",
          "r.alwaysUseActiveTerminal": true,
          "r.bracketedPaste": true,
          "r.plot.useHttpgd": true,
          "r.sessionWatcher": true,
          "r.rterm.option": ["--no-save", "--no-restore"],
          "[r]": {
            "editor.inlineSuggest.enabled": false
          }
        }' "$SETTINGS_FILE" > "$TEMP_SETTINGS" && mv "$TEMP_SETTINGS" "$SETTINGS_FILE"
      else
        jq '. + {
          "r.rterm.linux": "'"$RADIAN_PATH"'",
          "r.alwaysUseActiveTerminal": true,
          "r.bracketedPaste": true,
          "r.plot.useHttpgd": true,
          "r.sessionWatcher": true,
          "r.rterm.option": ["--no-save", "--no-restore"],
          "[r]": {
            "editor.inlineSuggest.enabled": false
          }
        }' "$SETTINGS_FILE" > "$TEMP_SETTINGS" && mv "$TEMP_SETTINGS" "$SETTINGS_FILE"
      fi
    else
      jq '. + {
        "r.alwaysUseActiveTerminal": true,
        "r.bracketedPaste": true,
        "r.plot.useHttpgd": true,
        "r.sessionWatcher": true,
        "r.rterm.option": ["--no-save", "--no-restore"],
        "[r]": {
          "editor.inlineSuggest.enabled": false
        }
      }' "$SETTINGS_FILE" > "$TEMP_SETTINGS" && mv "$TEMP_SETTINGS" "$SETTINGS_FILE"
    fi
  fi

  # Configure Python settings
  if [ "$INSTALL_PYTHON" = true ] && command_exists jq; then
    PYTHON_PATH="$(command -v python3)"
    TEMP_SETTINGS=$(mktemp)
    jq '. + {
      "python.defaultInterpreterPath": "'"$PYTHON_PATH"'",
      "python.terminal.activateEnvironment": true,
      "[python]": {
        "editor.formatOnSave": true,
        "editor.inlineSuggest.enabled": false
      }
    }' "$SETTINGS_FILE" > "$TEMP_SETTINGS" && mv "$TEMP_SETTINGS" "$SETTINGS_FILE"
  fi

  log_success "VSCode settings configured"
}

# Configure VSCode keybindings
configure_keybindings() {
  if ! command_exists code; then
    return 0
  fi

  log_info "Configuring VSCode keybindings..."

  case "$OS_TYPE" in
    linux)
      SETTINGS_DIR="$HOME/.config/Code/User"
      ;;
    macos)
      SETTINGS_DIR="$HOME/Library/Application Support/Code/User"
      ;;
  esac

  KEYBINDINGS_FILE="$SETTINGS_DIR/keybindings.json"

  # Create keybindings file if it doesn't exist
  if [ ! -f "$KEYBINDINGS_FILE" ]; then
    echo '[]' > "$KEYBINDINGS_FILE"
  fi

  if ! command_exists jq; then
    return 0
  fi

  TEMP_KEYBINDINGS=$(mktemp)

  # Add R keybindings
  if [ "$INSTALL_R" = true ]; then
    jq '. + [
      {
        "key": "ctrl+enter",
        "command": "r.runSelection",
        "when": "editorTextFocus && editorLangId == '\''r'\''"
      },
      {
        "key": "ctrl+shift+enter",
        "command": "r.runCurrentChunk",
        "when": "editorTextFocus && editorLangId == '\''r'\''"
      }
    ]' "$KEYBINDINGS_FILE" > "$TEMP_KEYBINDINGS" && mv "$TEMP_KEYBINDINGS" "$KEYBINDINGS_FILE"
  fi

  # Add Python keybindings
  if [ "$INSTALL_PYTHON" = true ]; then
    TEMP_KEYBINDINGS=$(mktemp)
    jq '. + [
      {
        "key": "ctrl+enter",
        "command": "python.execSelectionInTerminal",
        "when": "editorTextFocus && editorLangId == '\''python'\''"
      }
    ]' "$KEYBINDINGS_FILE" > "$TEMP_KEYBINDINGS" && mv "$TEMP_KEYBINDINGS" "$KEYBINDINGS_FILE"
  fi

  log_success "VSCode keybindings configured"
}

# Main installation flow
main() {
  echo ""
  echo "=========================================="
  echo "  VSCode R & Python Setup"
  echo "=========================================="
  echo ""

  # Auto-detect non-interactive mode when stdin is not a TTY (e.g., piped from curl)
  if [ "$NON_INTERACTIVE" = false ] && [ ! -t 0 ]; then
    log_info "Detected non-interactive environment (stdin not a TTY)"
    log_info "Enabling non-interactive mode automatically"
    NON_INTERACTIVE=true
  fi

  detect_system

  echo ""
  echo "Installation Configuration:"
  echo "  - Install R: $INSTALL_R"
  if [ "$INSTALL_R" = true ]; then
    echo "    - Package Manager: $R_PACKAGE_MANAGER"
    echo "    - Install radian: $INSTALL_RADIAN"
  fi
  echo "  - Install Python: $INSTALL_PYTHON"
  echo "  - Install VSCode: $INSTALL_VSCODE"
  echo ""

  if [ "$NON_INTERACTIVE" = false ]; then
    read -p "Continue with installation? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      log_info "Installation cancelled"
      exit 0
    fi
  else
    log_info "Running in non-interactive mode - proceeding automatically"
  fi

  echo ""
  log_info "Starting installation..."
  echo ""

  # Install components
  install_vscode
  install_r
  configure_r_packages
  install_r_packages
  install_radian
  install_python
  install_vscode_extensions
  configure_vscode
  configure_keybindings

  echo ""
  echo "=========================================="
  log_success "Installation complete!"
  echo "=========================================="
  echo ""

  if [ "$INSTALL_R" = true ]; then
    echo "R Environment:"
    echo "  - R version: $(R --version | head -n1 || echo 'Not installed')"
    echo "  - Package manager: $R_PACKAGE_MANAGER"
    if command_exists radian; then
      echo "  - Radian: $(command -v radian)"
    fi
    echo ""
  fi

  if [ "$INSTALL_PYTHON" = true ]; then
    echo "Python Environment:"
    echo "  - Python version: $(python3 --version || echo 'Not installed')"
    echo ""
  fi

  if command_exists code; then
    echo "VSCode:"
    echo "  - VSCode: $(code --version | head -n1 || echo 'Not installed')"
    echo ""
  fi

  echo "Next Steps:"
  if command_exists code; then
    echo "  1. Restart VSCode (if running)"
  fi
  if [ "$INSTALL_R" = true ]; then
    echo "  2. Open an R file (.R) and press Ctrl+Enter to run code"
    echo "  3. For Shiny apps, open app.R and click the Run button"
  fi
  if [ "$INSTALL_PYTHON" = true ]; then
    echo "  4. Open a Python file (.py) and press Ctrl+Enter to run code"
  fi
  echo ""
  echo "For troubleshooting, visit: https://github.com/Fr4nzz/Setup-R-and-python-on-VSCode"
  echo ""
}

# Run main installation
main
