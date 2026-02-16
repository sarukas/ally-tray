#!/bin/bash
# MyAlly Installation Script
#
# This shim script bootstraps the ally-updater package and runs installation.
# It handles downloading Python if needed and setting up the updater.
#
# Usage:
#   curl -fsSL https://get.myally.ai/install.sh | bash
#   OR
#   ./install.sh [--install-dir <path>] [--yes]

set -e

# Configuration
REPO_OWNER="sarukas"
REPO_NAME="ally"
REPO_URL="https://github.com/$REPO_OWNER/$REPO_NAME"
UPDATER_PACKAGE="packages/ally-updater"
MIN_PYTHON_VERSION="3.11"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Detect platform
detect_platform() {
    case "$(uname -s)" in
        Darwin*) echo "macos" ;;
        Linux*)  echo "linux" ;;
        *)       echo "unknown" ;;
    esac
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Compare version numbers (returns 0 if $1 >= $2)
version_gte() {
    [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

# Get Python version
get_python_version() {
    local python_cmd="$1"
    "$python_cmd" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1
}

# Find suitable Python
find_python() {
    # Check common names, including versioned binaries (Homebrew keg-only)
    for cmd in python3 python python3.13 python3.12 python3.11; do
        if command_exists "$cmd"; then
            version=$(get_python_version "$cmd")
            if version_gte "$version" "$MIN_PYTHON_VERSION"; then
                echo "$cmd"
                return 0
            fi
        fi
    done

    # On macOS, check Homebrew keg-only paths directly
    if [ "$(detect_platform)" = "macos" ]; then
        local brew_prefix
        brew_prefix="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
        for pyver in 3.13 3.12 3.11; do
            local brew_python="$brew_prefix/opt/python@$pyver/bin/python$pyver"
            if [ -x "$brew_python" ]; then
                version=$(get_python_version "$brew_python")
                if version_gte "$version" "$MIN_PYTHON_VERSION"; then
                    echo "$brew_python"
                    return 0
                fi
            fi
        done
    fi

    return 1
}

# Install Git
install_git() {
    info "Git not found. Attempting to install..."
    case "$(detect_platform)" in
        macos)
            # Try xcode-select first (installs Git as part of CLT)
            if xcode-select --install 2>/dev/null; then
                # Wait briefly for the install dialog
                info "Xcode Command Line Tools installer launched."
                info "Please complete the installation, then re-run this script."
                exit 1
            fi
            if command_exists brew; then
                brew install git && return 0
            fi
            ;;
        linux)
            if command_exists apt; then
                sudo apt update && sudo apt install -y git && return 0
            elif command_exists dnf; then
                sudo dnf install -y git && return 0
            elif command_exists pacman; then
                sudo pacman -S --noconfirm git && return 0
            fi
            ;;
    esac
    error "Could not auto-install Git."
    info "Install manually:"
    info "  macOS: xcode-select --install  OR  brew install git"
    info "  Debian/Ubuntu: sudo apt install git"
    info "  Fedora: sudo dnf install git"
    return 1
}

# Check Git (attempts install if missing)
check_git() {
    if ! command_exists git; then
        install_git || exit 1
    fi
    success "Git found: $(git --version)"
}

# Install Python
install_python() {
    info "Python $MIN_PYTHON_VERSION+ not found. Attempting to install..."
    case "$(detect_platform)" in
        macos)
            if command_exists brew; then
                brew install python@3.11 && return 0
            fi
            info "Install Homebrew first: https://brew.sh"
            ;;
        linux)
            if command_exists apt; then
                sudo apt update && sudo apt install -y python3.11 python3.11-venv && return 0
            elif command_exists dnf; then
                sudo dnf install -y python3.11 && return 0
            elif command_exists pacman; then
                sudo pacman -S --noconfirm python && return 0
            fi
            ;;
    esac
    error "Could not auto-install Python."
    info "Install manually:"
    info "  macOS: brew install python@3.11"
    info "  Debian/Ubuntu: sudo apt install python3.11"
    info "  Fedora: sudo dnf install python3.11"
    return 1
}

# Check/install uv
check_uv() {
    if command_exists uv; then
        success "uv found: $(uv --version)"
        return 0
    fi

    info "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh

    # Source the environment (uv installs to ~/.local/bin or ~/.cargo/bin)
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

    if command_exists uv; then
        success "uv installed: $(uv --version)"
        return 0
    fi

    error "Failed to install uv"
    return 1
}

# Check if a clone error is an authentication/permission issue (vs disk, network, etc.)
is_auth_error() {
    local stderr_output="$1"
    # Common auth-related patterns from git/gh
    echo "$stderr_output" | grep -qiE \
        'authentication|unauthorized|403|401|permission denied|could not read from remote|invalid credentials|bad credentials|token|login required'
}

# Check clone stderr for known non-auth errors and print a helpful message.
# Returns 0 if a non-auth error was detected (caller should abort), 1 otherwise.
check_clone_error() {
    local stderr_output="$1"
    local dest="$2"

    # Clean up partial directory left by failed clone attempt
    rm -rf "$dest" 2>/dev/null

    # No output to analyze — fall through to auth logic
    if [ -z "$stderr_output" ]; then
        return 1
    fi

    # Disk space
    if echo "$stderr_output" | grep -qiE 'no space left on device|disk quota exceeded|not enough space|ENOSPC'; then
        error "Clone failed: insufficient disk space."
        info "Free up disk space and try again."
        info "Details: $stderr_output"
        return 0
    fi

    # Network / DNS
    if echo "$stderr_output" | grep -qiE 'could not resolve host|network is unreachable|connection timed out|connection refused|SSL|unable to access'; then
        error "Clone failed: network error."
        info "Check your internet connection and try again."
        info "Details: $stderr_output"
        return 0
    fi

    # Destination already exists
    if echo "$stderr_output" | grep -qiE 'already exists and is not an empty directory'; then
        error "Clone failed: destination directory already exists."
        info "Details: $stderr_output"
        return 0
    fi

    # Not an auth error either — unknown failure, show details and abort
    if ! is_auth_error "$stderr_output"; then
        error "Clone failed with unexpected error."
        info "Details: $stderr_output"
        return 0
    fi

    # It IS an auth error — let the caller continue to auth fallback
    return 1
}

# Clone the private repository with auth fallback
# Tries: 1) gh CLI  2) plain git clone  3) PAT prompt
clone_repo() {
    local dest="$1"
    local clone_stderr

    # Method 1: gh CLI (handles auth automatically)
    if command_exists gh; then
        info "Trying clone via GitHub CLI (gh)..."
        clone_stderr=$(gh repo clone "$REPO_OWNER/$REPO_NAME" "$dest" -- --depth 1 2>&1 >/dev/null)
        if [ $? -eq 0 ]; then
            success "Cloned via gh CLI"
            return 0
        fi

        # Check if it's a non-auth error (disk, network, etc.) — abort early
        if check_clone_error "$clone_stderr" "$dest"; then
            return 1
        fi

        # It's an auth error — try interactive login if possible
        if [ -t 0 ]; then
            warn "gh is not authenticated. Starting interactive login..."
            if gh auth login; then
                info "Retrying clone after authentication..."
                clone_stderr=$(gh repo clone "$REPO_OWNER/$REPO_NAME" "$dest" -- --depth 1 2>&1 >/dev/null)
                if [ $? -eq 0 ]; then
                    success "Cloned via gh CLI (after login)"
                    return 0
                fi
                if check_clone_error "$clone_stderr" "$dest"; then
                    return 1
                fi
            fi
            warn "gh authentication/clone failed. Trying next method..."
        else
            warn "gh clone failed (not authenticated, and stdin is piped — cannot run interactive login). Trying next method..."
        fi
    fi

    # Method 2: plain git clone (works with SSH keys or credential manager)
    info "Trying clone via git..."
    clone_stderr=$(git clone --depth 1 "$REPO_URL" "$dest" 2>&1 >/dev/null)
    if [ $? -eq 0 ]; then
        success "Cloned via git"
        return 0
    fi

    # Check for non-auth errors before falling through to PAT prompt
    if check_clone_error "$clone_stderr" "$dest"; then
        return 1
    fi

    # Method 3: prompt for GitHub Personal Access Token
    warn "The repository is private. A GitHub Personal Access Token (PAT) is required."
    info "Create one at: https://github.com/settings/tokens (needs 'repo' scope)"
    echo ""
    # When piped (curl | bash), stdin is not a terminal — cannot prompt for PAT
    if [ ! -t 0 ]; then
        error "Cannot prompt for credentials when piped. Run the script directly instead:"
        info "  curl -fsSL https://get.myally.ai/install.sh -o install.sh && bash install.sh"
        return 1
    fi

    read -rp "GitHub PAT: " github_token
    if [ -z "$github_token" ]; then
        error "No token provided. Cannot clone private repository."
        return 1
    fi

    clone_stderr=$(git clone --depth 1 "https://${github_token}@github.com/$REPO_OWNER/$REPO_NAME.git" "$dest" 2>&1 >/dev/null)
    if [ $? -eq 0 ]; then
        success "Cloned via PAT"
        return 0
    fi

    # Show the actual error instead of a generic message
    if check_clone_error "$clone_stderr" "$dest"; then
        return 1
    fi

    error "All clone methods failed. Check your credentials and try again."
    return 1
}

# Main installation
main() {
    echo ""
    echo "=================================="
    echo "  MyAlly Installation"
    echo "=================================="
    echo ""

    local install_dir=""
    local auto_yes=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-dir)
                install_dir="$2"
                shift 2
                ;;
            --yes|-y)
                auto_yes=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --install-dir <path>   Set installation directory"
                echo "  --yes, -y              Skip confirmation prompts"
                echo "  --help, -h             Show this help"
                exit 0
                ;;
            *)
                warn "Unknown option: $1"
                shift
                ;;
        esac
    done

    # Detect platform
    platform=$(detect_platform)
    info "Detected platform: $platform"

    if [ "$platform" = "unknown" ]; then
        error "Unsupported platform"
        exit 1
    fi

    # Check prerequisites
    info "Checking prerequisites..."
    check_git

    # Find or install Python
    if python_cmd=$(find_python); then
        success "Python found: $python_cmd ($(get_python_version "$python_cmd"))"
    else
        install_python || exit 1
        # Refresh PATH so newly installed Python is discoverable
        hash -r 2>/dev/null
        if [ "$(detect_platform)" = "macos" ] && command_exists brew; then
            export PATH="$(brew --prefix)/opt/python@3.11/bin:$PATH"
        fi
        # Retry finding Python after install
        if python_cmd=$(find_python); then
            success "Python installed: $python_cmd ($(get_python_version "$python_cmd"))"
        else
            error "Python was installed but could not be found. You may need to restart your shell."
            exit 1
        fi
    fi

    # Check/install uv
    check_uv || exit 1

    # Early Node.js check (non-blocking - ally-updater handles installation)
    if command_exists node; then
        node_version=$(node --version 2>/dev/null | grep -oE '[0-9]+' | head -1)
        if [ -n "$node_version" ] && [ "$node_version" -ge 18 ] 2>/dev/null; then
            success "Node.js found: $(node --version)"
        else
            warn "Node.js $(node --version 2>/dev/null) found, but >= 18 required. The installer will attempt to upgrade it."
        fi
    else
        warn "Node.js not found. The installer will attempt to install it."
    fi

    # Set default install directory
    if [ -z "$install_dir" ]; then
        case "$platform" in
            macos)
                install_dir="$HOME/Library/Application Support/MyAlly"
                ;;
            linux)
                install_dir="${XDG_DATA_HOME:-$HOME/.local/share}/myally"
                ;;
        esac
    fi

    # Check for existing installation
    is_update=false
    existing_app_dir="$install_dir/app"
    if [ -d "$existing_app_dir" ]; then
        is_update=true
        success "Found existing installation at: $install_dir"
    else
        info "Installation directory: $install_dir"
    fi

    # Confirm for fresh installs only (updates are confirmed by ally-updater CLI)
    # When piped (curl | bash), stdin is not a terminal — skip prompt and assume yes
    if [ "$auto_yes" != true ] && [ "$is_update" != true ] && [ -t 0 ]; then
        read -p "Continue with installation? [Y/n] " response
        case "$response" in
            [nN][oO]|[nN])
                info "Installation cancelled."
                exit 1
                ;;
        esac
    fi

    # Create temp directory for bootstrap
    tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" EXIT

    info "Downloading MyAlly Update Script..."

    # Clone repository (shallow, with auth fallback)
    if ! clone_repo "$tmp_dir/ally"; then
        error "Failed to clone repository"
        exit 1
    fi

    # Verify ally-updater package exists
    updater_dir="$tmp_dir/ally/$UPDATER_PACKAGE"
    if [ ! -d "$updater_dir" ]; then
        error "ally-updater package not found in repository"
        error "Expected path: $updater_dir"
        info "The repository may not have been set up correctly."
        exit 1
    fi

    info "Setting up installation environment..."

    # Create a virtual environment for the updater
    venv_dir="$tmp_dir/venv"
    uv venv "$venv_dir" --python 3.11
    if [ $? -ne 0 ]; then
        error "Failed to create virtual environment"
        exit 1
    fi

    # Get venv Python path
    venv_python="$venv_dir/bin/python"

    info "Installing ally-updater..."

    # Install updater in the venv using uv (uv doesn't need pip in venv)
    cd "$updater_dir"
    uv pip install -e . --python "$venv_python"
    if [ $? -ne 0 ]; then
        error "Failed to install ally-updater"
        exit 1
    fi

    if [ "$is_update" = true ]; then
        info "Starting update..."
    else
        info "Starting installation..."
    fi

    # Run updater using the venv Python (use array to preserve paths with spaces)
    install_args=("--install-dir" "$install_dir")
    if [ "$auto_yes" = true ] || [ ! -t 0 ]; then
        # Pass --yes when explicitly requested OR when stdin is piped (curl | bash)
        # since updater's input() calls will get EOFError on piped stdin
        install_args+=("--yes")
    fi

    # Run updater and capture exit code (don't use exec - let trap cleanup run)
    "$venv_python" -m ally_updater "${install_args[@]}"
    updater_exit_code=$?

    # Cleanup happens via trap on EXIT
    # Propagate updater exit code
    exit $updater_exit_code
}

# Run main
main "$@"
