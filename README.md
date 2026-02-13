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

- **Git** - [git-scm.com](https://git-scm.com) or `winget install Git.Git`
- **Python 3.11+** - [python.org](https://python.org) or `winget install Python.Python.3.11`
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

See the [main repository](https://github.com/sarukas/ally) for full documentation.

---

## Downloads

Download the latest tray app release from the [Releases](https://github.com/sarukas/ally-tray/releases) page.

| Platform | File |
|----------|------|
| Windows | `myally-tray.exe` |
| macOS | `myally-tray` (coming soon) |
| Linux | `myally-tray` (coming soon) |

## Integration

The tray application integrates with the [ally-updater](https://github.com/sarukas/ally/tree/main/packages/ally-updater) package for automatic updates.

## License

MIT
