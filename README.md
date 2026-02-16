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

## ally-updater CLI

After installation, updates are managed by the **ally-updater** CLI. The tray app checks for updates automatically, but you can also run it directly:

```
ally-updater                              # Update all components (non-interactive)
ally-updater update                       # Same as above
ally-updater update main-app              # Update only the main application
ally-updater update tray                  # Update only the tray binary
ally-updater update main-app --force      # Force reinstall main-app
ally-updater update --force               # Force reinstall all
ally-updater update --interactive         # Per-component prompts
ally-updater update-node                  # Update Node.js separately
ally-updater check                        # Check for updates without applying
ally-updater config check                 # Check pending config migrations
ally-updater config migrate               # Apply config migrations
ally-updater config history               # Show migration history
```

### Key behaviors

- **Non-interactive by default** — runs without prompts, ideal for automation and tray-triggered updates.
- **Component as positional argument** — `update main-app` not `--component main-app`.
- **Node.js updates are explicit** — use `update-node`; never auto-selected during regular updates.
- **`--interactive`** — enables per-component prompts for granular control over what gets updated.
- **`--force`** — force reinstall even if up-to-date. Works per-component: `update tray --force`.

### Global flags

| Flag | Description |
|---|---|
| `--install-dir <path>` | Custom installation directory |
| `--json` | Machine-readable JSON output |
| `--verbose` / `-v` | Verbose output |
| `--quiet` / `-q` | Suppress non-essential output |
| `--version` | Show ally-updater version |

### Backwards compatibility

Old flags still work with deprecation warnings:

| Old | New equivalent |
|---|---|
| `ally-updater --check` | `ally-updater check` |
| `ally-updater --confirm` | `ally-updater update --interactive` |
| `ally-updater --component main-app` | `ally-updater update main-app` |
| `ally-updater --force --component main-app --yes` | `ally-updater update main-app --force` |
| `ally-updater --yes` | `ally-updater` (non-interactive is now default) |

---

## Installation Layout

```
<install-dir>/                  # Default: %LOCALAPPDATA%\MyAlly (Windows)
├── app/                        #          ~/Library/Application Support/MyAlly (macOS)
│   ├── .venv/                  #          ~/.local/share/myally (Linux)
│   ├── services/myally/        # Backend (FastAPI + SQLite)
│   └── apps/ally-frontend/     # Frontend (React)
├── tray/
│   └── myally-tray.exe         # Tray launcher binary
└── mcp-servers/                # MCP server extensions (future)
```

Configuration and data are stored in `~/.ally/`:

| Path | Contents |
|---|---|
| `~/.ally/config.yaml` | Installation config |
| `~/.ally/myally.db` | SQLite database (WAL mode) |
| `~/.ally/logs/` | Log files (daily rotation) |
| `~/.ally/tray.yaml` | Tray launcher settings |

---

## Downloads

Download the latest tray app release from the [Releases](https://github.com/sarukas/ally-tray/releases) page.

| Platform | File |
|----------|------|
| Windows | `myally-tray.exe` |
| macOS | `myally-tray` (coming soon) |
| Linux | `myally-tray` (coming soon) |

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
