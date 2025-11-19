#!/usr/bin/env bash
#
# Antigravity R & Python Setup - Linux/macOS
# Based on VSCode Setup by Fr4nzz
#

set -euo pipefail

# --- CONFIGURATION ---
EDITOR_CMD="antigravity"
if [[ "$OSTYPE" == "darwin"* ]]; then
    SETTINGS_DIR="$HOME/Library/Application Support/Antigravity/User"
else
    SETTINGS_DIR="$HOME/.config/Antigravity/User"
fi
SETTINGS_FILE="$SETTINGS_DIR/settings.json"
# ---------------------

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
INSTALL_R=true
INSTALL_PYTHON=true
INSTALL_RADIAN=true
R_PACKAGE_MANAGER="ppm"

# Parse Args
while [[ $# -gt 0 ]]; do
  case $1 in
    --r-only) INSTALL_R=true; INSTALL_PYTHON=false; shift ;;
    --python-only) INSTALL_R=false; INSTALL_PYTHON=true; shift ;;
    --skip-radian) INSTALL_RADIAN=false; shift ;;
    --package-manager) R_PACKAGE_MANAGER="$2"; shift 2 ;;
    *) shift ;;
  esac
done

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

check_editor() {
    if ! command_exists $EDITOR_CMD; then
        log_error "Antigravity CLI ($EDITOR_CMD) not found."
        log_error "Please install Antigravity manually and ensure 'antigravity' is in your PATH."
        exit 1
    fi
}

# --- REUSE INSTALLATION LOGIC ---

detect_system() {
  OS="$(uname -s)"
  ARCH="$(uname -m)"
  if [[ "$OS" == "Linux"* ]]; then
    if [ -f /etc/os-release ]; then . /etc/os-release; DISTRO="$ID"; DISTRO_CODENAME="${VERSION_CODENAME:-}"; fi
    OS_TYPE="linux"
    if [ "$ARCH" = "aarch64" ]; then ARCH_TYPE="arm64"; else ARCH_TYPE="x86_64"; fi
  else
    OS_TYPE="macos"
  fi
}

install_env() {
    log_info "Checking R and Python environment..."
    if [ "$INSTALL_R" = true ] && ! command_exists R; then
        log_error "R not found. Please run the main install.sh first or install R manually."
    fi
    if [ "$INSTALL_PYTHON" = true ] && ! command_exists python3; then
        log_error "Python not found. Please run the main install.sh first or install Python manually."
    fi
}

# --- ANTIGRAVITY CONFIG ---

configure_antigravity() {
    log_info "Configuring Antigravity settings..."
    mkdir -p "$SETTINGS_DIR"
    if [ ! -f "$SETTINGS_FILE" ]; then echo '{}' > "$SETTINGS_FILE"; fi
    if ! command_exists jq; then log_error "jq is required for this script."; exit 1; fi

    TMP=$(mktemp)

    # 1. Remove 'extensions.gallery' (Conflict)
    # 2. Add 'antigravity.marketplace...' (Success)
    jq 'del(.["extensions.gallery"]) | . + {
        "antigravity.marketplaceExtensionGalleryServiceURL": "https://marketplace.visualstudio.com/_apis/public/gallery",
        "antigravity.marketplaceGalleryItemURL": "https://marketplace.visualstudio.com/items"
    }' "$SETTINGS_FILE" > "$TMP" && mv "$TMP" "$SETTINGS_FILE"

    if [ "$INSTALL_R" = true ]; then
        RADIAN=$(command -v radian || echo "")
        jq --arg radian "$RADIAN" '. + {
            "r.rterm.linux": $radian,
            "r.rterm.mac": $radian,
            "r.plot.useHttpgd": true,
            "r.bracketedPaste": true,
             "r.sessionWatcher": true
        }' "$SETTINGS_FILE" > "$TMP" && mv "$TMP" "$SETTINGS_FILE"
    fi

    if [ "$INSTALL_PYTHON" = true ]; then
        PY=$(command -v python3)
        jq --arg py "$PY" '. + {
            "python.defaultInterpreterPath": $py,
            "python.terminal.activateEnvironment": true
        }' "$SETTINGS_FILE" > "$TMP" && mv "$TMP" "$SETTINGS_FILE"
    fi
    
    log_success "Settings updated."
}

install_extensions() {
    log_info "Installing Extensions..."
    EXTS=()
    if [ "$INSTALL_R" = true ]; then EXTS+=("REditorSupport.r" "Posit.shiny" "RDebugger.r-debugger"); fi
    if [ "$INSTALL_PYTHON" = true ]; then EXTS+=("ms-python.python" "ms-toolsai.jupyter"); fi

    for ext in "${EXTS[@]}"; do
        log_info "Installing $ext..."
        $EDITOR_CMD --install-extension "$ext" --force >/dev/null 2>&1 || true
    done
}

main() {
    detect_system
    check_editor
    install_env
    configure_antigravity
    install_extensions
    log_success "Antigravity Setup Complete."
}

main