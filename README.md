# VSCode R & Python Setup

Automated, cross-platform setup for VSCode with R and Python development environments. Install VSCode, R, Python, and all necessary extensions and configurations with a single command.

## Features

- **Unattended Installation**: One-command setup for complete R and Python development environment
- **Cross-Platform**: Works on Linux, macOS, and Windows
- **Architecture Agnostic**: Supports x86_64 (amd64) and ARM64 architectures
- **Binary Package Management**: Fast R package installation without compilation
  - **PPM (Posit Public Package Manager)**: Default, works on all Linux distributions
  - **r2u + bspm**: Ubuntu-specific, uses APT for R packages
- **Complete VSCode Integration**:
  - R and Python extensions
  - Jupyter support
  - Shiny app support with play button execution
  - Interactive plot viewers (httpgd for R, matplotlib for Python)
  - Debug tools and language servers
  - Optimized keybindings
- **Enhanced Terminals**: Optional radian for improved R console

## Quick Start

### Linux/macOS

**Install Everything (R + Python + VSCode)**:
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Setup-R-and-python-on-VSCode/main/install.sh | bash
```

**R Only**:
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Setup-R-and-python-on-VSCode/main/install.sh | bash -s -- --r-only
```

**Python Only**:
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Setup-R-and-python-on-VSCode/main/install.sh | bash -s -- --python-only
```

**With r2u (Ubuntu only)**:
```bash
curl -fsSL https://raw.githubusercontent.com/Fr4nzz/Setup-R-and-python-on-VSCode/main/install.sh | bash -s -- --package-manager=r2u
```

### Windows

**PowerShell (Run as Administrator)**:
```powershell
irm https://raw.githubusercontent.com/Fr4nzz/Setup-R-and-python-on-VSCode/main/install.ps1 | iex
```

**With Options**:
```powershell
irm https://raw.githubusercontent.com/Fr4nzz/Setup-R-and-python-on-VSCode/main/install.ps1 -OutFile install.ps1
.\install.ps1 -ROnly
# or
.\install.ps1 -PythonOnly
```

## Command-Line Options

### Linux/macOS (install.sh)

```bash
./install.sh [OPTIONS]

Options:
  --r-only              Install only R and R tools
  --python-only         Install only Python and Python tools
  --package-manager     Choose R package manager: 'ppm' (default) or 'r2u' (Ubuntu only)
  --skip-vscode         Skip VSCode installation (configure existing installation)
  --skip-radian         Skip radian installation (use default R console)
  --non-interactive     Run without prompts (use defaults)
  -h, --help           Show this help message
```

### Windows (install.ps1)

```powershell
.\install.ps1 [-ROnly] [-PythonOnly] [-SkipVSCode] [-SkipRadian] [-NonInteractive] [-Help]

Parameters:
  -ROnly              Install only R and R tools
  -PythonOnly         Install only Python and Python tools
  -SkipVSCode         Skip VSCode installation
  -SkipRadian         Skip radian installation
  -NonInteractive     Run without prompts
  -Help               Show help message
```

## What Gets Installed

### R Environment
- **R** (latest version from CRAN)
- **VSCode Extensions**:
  - `REditorSupport.r` - R language support
  - `RDebugger.r-debugger` - R debugging
  - `Posit.shiny` - Shiny app support with play button
- **R Packages**:
  - `languageserver` - Code intelligence
  - `httpgd` - Interactive plot viewer in VSCode
  - `shiny` - Web application framework
- **Radian** (optional): Enhanced R console with syntax highlighting
- **Binary Package Manager**:
  - **PPM** (default): Works on all platforms
  - **r2u + bspm** (Ubuntu): APT-based, faster on Ubuntu

### Python Environment
- **Python 3** (system package manager or Python.org)
- **VSCode Extensions**:
  - `ms-python.python` - Python language support
  - `ms-toolsai.jupyter` - Jupyter notebook support
- **Tools**:
  - `pip` - Package installer
  - `venv` - Virtual environment support

### VSCode
- **Visual Studio Code** (if not already installed)
- **Configured Settings**:
  - R terminal and plot integration
  - Python interpreter detection
  - Optimized editor settings
- **Keybindings**:
  - **R**: `Ctrl+Enter` (run line/selection), `Ctrl+Shift+Enter` (run chunk)
  - **Python**: `Ctrl+Enter` (run line/selection)
  - **Shiny**: `F5` or play button to run app

## Post-Installation

### Running Shiny Apps

1. Open an `app.R` file in VSCode
2. Click the **Run** button (play icon) in the top right
3. Select **"Run Shiny App"** from the menu
4. Or press **F5**

The app will launch and open in your default browser.

### R Plots

Plots automatically appear in the **PLOTS** panel in VSCode when using:
```r
plot(1:10)
ggplot(data, aes(x, y)) + geom_point()
```

### Python Plots

For matplotlib plots to show in VSCode:
```python
import matplotlib.pyplot as plt
plt.plot([1, 2, 3, 4])
plt.show()  # Opens in VSCode plot viewer
```

## R Package Management

### PPM (Posit Public Package Manager) - Default

Fast binary packages for Linux, source for macOS/Windows:
```r
install.packages("tidyverse")  # Installs as binary on Linux
```

Configuration is automatic. PPM repository is set in `~/.Rprofile` or `/etc/R/Rprofile.site`.

### r2u + bspm (Ubuntu Only)

Install R packages via APT (system package manager):
```r
install.packages("tidyverse")  # Uses apt-get behind the scenes
```

Or directly with apt:
```bash
sudo apt install r-cran-tidyverse
```

Benefits:
- Instant installation (no compilation)
- System-wide package management
- Shared dependencies with system packages

## Troubleshooting

### Shiny Apps Not Running with Play Button

1. Ensure Posit.shiny extension is installed:
   ```bash
   code --install-extension Posit.shiny
   ```

2. Restart VSCode

3. Open `app.R` file - the play button menu should show "Run Shiny App"

### R Plots Not Showing

1. Verify httpgd is installed:
   ```r
   install.packages("httpgd")
   ```

2. Check VSCode setting `r.plot.useHttpgd` is `true`:
   - Open Settings (Ctrl+,)
   - Search for "r.plot.useHttpgd"
   - Ensure it's checked

3. Restart R terminal in VSCode

### Python Run Button Missing

1. Reload VSCode window: `Ctrl+Shift+P` → "Developer: Reload Window"
2. Verify Python extension is installed
3. Open a `.py` file - the play button should appear

### radian Not Found (Linux/macOS)

Ensure `~/.local/bin` is in your PATH:
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## Manual Installation

If you prefer not to use the automated scripts, see [MANUAL_INSTALL.md](MANUAL_INSTALL.md) for step-by-step instructions.

## Architecture Support

- **Linux**: x86_64, ARM64 (aarch64)
- **macOS**: Intel (x86_64), Apple Silicon (ARM64)
- **Windows**: x86_64, ARM64

## Requirements

### Linux
- **Ubuntu/Debian**: 20.04+ (recommended)
- **Arch Linux/Manjaro**: Latest
- **Fedora/RHEL/CentOS**: Recent versions
- `curl` or `wget`
- `sudo` access

### macOS
- macOS 10.15 (Catalina) or later
- Command Line Tools for Xcode

### Windows
- Windows 10 or later
- PowerShell 5.1 or later
- Administrator privileges

## Contributing

Contributions welcome! Please open an issue or pull request.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

Based on scripts from [Termux-Fr4nz](https://github.com/Fr4nzz/Termux-Fr4nz) for setting up VSCode with R and Python in containerized environments.

## References

- [VSCode R Documentation](https://code.visualstudio.com/docs/languages/r)
- [VSCode Python Documentation](https://code.visualstudio.com/docs/python/python-quick-start)
- [Shiny VSCode Extension](https://marketplace.visualstudio.com/items?itemName=Posit.shiny)
- [r2u: CRAN as Ubuntu Binaries](https://github.com/eddelbuettel/r2u)
- [Posit Public Package Manager](https://packagemanager.posit.co/)
- [httpgd: HTTP Graphics Device](https://github.com/nx10/httpgd)
- [radian: Better R Console](https://github.com/randy3k/radian)
