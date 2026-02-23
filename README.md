# ally-tray

MyAlly System Tray Application - Binary releases for cross-platform auto-update.

## Overview

This repository hosts binary releases of the MyAlly system tray application. The tray app provides:

- 🚀 Backend process management (start/stop)
- 🌐 One-click frontend launch
- 📦 Automatic update checking
- 🔔 Update notifications with tray icon badge
- ⬆️ Update application via menu

## Installation

These scripts install the full **MyAlly** platform (backend, frontend, and dependencies) from the private [sarukas/ally](https://github.com/sarukas/ally) repository.

### Prerequisites

The installer will attempt to install missing prerequisites automatically, but you may need:

| Prerequisite | Required | Auto-installed? |
|---|---|---|
| **Git** | Yes | Yes (via winget / brew / apt) |
| **Python 3.11+** | Yes | Yes (via winget / brew / apt) |
| **Node.js 18+** | Yes | Yes (via platform installer) |
| **uv** | Yes | Yes (via astral.sh) |

- **Private repo access** — one of:
  - [GitHub CLI](https://cli.github.com/) (`gh`) authenticated with `gh auth login`
  - SSH key configured for GitHub
  - A GitHub [Personal Access Token](https://github.com/settings/tokens) with `repo` scope (you'll be prompted)

### Windows

Download https://raw.githubusercontent.com/sarukas/ally-tray/refs/heads/main/install.bat and double-click it or from a terminal:

```powershell
irm https://raw.githubusercontent.com/sarukas/ally-tray/refs/heads/main/install.ps1 | iex
```

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/sarukas/ally-tray/refs/heads/main/install.sh | bash
```

### Installer Options

#### install.bat / install.ps1 (Windows)

```
install.bat [--install-dir <path>] [--force] [--component <main-app|tray|all>]
```

| Flag | Description |
|---|---|
| `--install-dir <path>` | Custom installation directory (default: `%LOCALAPPDATA%\MyAlly`) |
| `--force` | Force reinstall of components |
| `--component <name>` | Update only a specific component (`main-app`, `tray`, or `all`) |

PowerShell equivalent flags: `-InstallDir`, `-Force`, `-Component`.

#### install.sh (macOS / Linux)

```bash
./install.sh [--install-dir <path>]
```

When piped (`curl | bash`), the installer runs non-interactively.

See the [main repository](https://github.com/sarukas/ally) for full documentation.

---

## Troubleshooting

### Clone fails with authentication error

Ensure you have access to the private [sarukas/ally](https://github.com/sarukas/ally) repository:

```bash
gh auth login       # Authenticate GitHub CLI
# Then re-run the installer
```

### Python not found after installation

Restart your terminal to pick up PATH changes, then re-run the installer.

### Backend won't start

Check logs at `~/.ally/logs/myally.log`. Common issues:
- Port 8080 already in use — check with `netstat -ano | findstr 8080` (Windows) or `lsof -i :8080` (macOS/Linux)
- Claude Agent SDK issue — the CLI is bundled with the SDK, no separate install needed. Run `uv sync --all-packages` in the app directory to fix.

### Updater fails mid-update

Re-run the installer — it's idempotent and will pick up where it left off. Use `--force` if a component is in a broken state.

## Integration

The tray application integrates with the [ally-updater](https://github.com/sarukas/ally/tree/main/packages/ally-updater) package for automatic updates. The installer scripts (`install.ps1`, `install.bat`, `install.sh`) are maintained in the main repository and synced here during releases.

## License

MIT
