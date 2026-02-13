# MyAlly Installation Script for Windows
#
# This shim script bootstraps the ally-updater package and runs installation.
# It handles downloading Python if needed and setting up the updater.
#
# Usage:
#   irm https://get.myally.ai/install.ps1 | iex
#   OR
#   .\install.ps1 [-InstallDir <path>] [-Yes]

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$InstallDir,

    [Parameter(Mandatory=$false)]
    [switch]$Yes,

    [Parameter(Mandatory=$false)]
    [switch]$Help
)

# Configuration
$RepoOwner = "sarukas"
$RepoName = "ally"
$RepoUrl = "https://github.com/$RepoOwner/$RepoName"
$UpdaterPackage = "packages/ally-updater"
$MinPythonVersion = [Version]"3.11.0"

# Colors
$Script:Colors = @{
    Info    = "Cyan"
    Success = "Green"
    Warning = "Yellow"
    Error   = "Red"
}

function Write-Info    { param($msg) Write-Host "[INFO]  " -ForegroundColor $Script:Colors.Info -NoNewline; Write-Host $msg }
function Write-Success { param($msg) Write-Host "[OK]    " -ForegroundColor $Script:Colors.Success -NoNewline; Write-Host $msg }
function Write-Warn    { param($msg) Write-Host "[WARN]  " -ForegroundColor $Script:Colors.Warning -NoNewline; Write-Host $msg }
function Write-Err     { param($msg) Write-Host "[ERROR] " -ForegroundColor $Script:Colors.Error -NoNewline; Write-Host $msg }

function Show-Help {
    Write-Host @"
MyAlly Installation Script

Usage: .\install.ps1 [OPTIONS]

Options:
    -InstallDir <path>    Set installation directory
    -Yes                  Skip confirmation prompts
    -Help                 Show this help

Examples:
    .\install.ps1
    .\install.ps1 -InstallDir "C:\MyAlly" -Yes
    irm https://get.myally.ai/install.ps1 | iex
"@
}

function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}

function Get-PythonVersion {
    param([string]$PythonPath)
    try {
        $output = & $PythonPath --version 2>&1
        if ($output -match '(\d+\.\d+\.\d+)') {
            return [Version]$Matches[1]
        }
    } catch {}
    return $null
}

function Find-Python {
    $candidates = @("python", "python3", "py")

    foreach ($cmd in $candidates) {
        if (Test-Command $cmd) {
            $version = Get-PythonVersion $cmd
            if ($null -ne $version -and $version -ge $MinPythonVersion) {
                return @{ Command = $cmd; Version = $version }
            }
        }
    }

    # Try Python Launcher with version
    if (Test-Command "py") {
        try {
            $output = & py -3.11 --version 2>&1
            if ($output -match '(\d+\.\d+\.\d+)') {
                return @{ Command = "py -3.11"; Version = [Version]$Matches[1] }
            }
        } catch {}
    }

    return $null
}

function Install-Git {
    Write-Info "Git not found. Attempting to install..."

    if (Test-Command "winget") {
        Write-Info "Installing Git via winget..."
        & winget install -e --id Git.Git --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            Refresh-Path
            if (Test-Command "git") {
                Write-Success "Git installed successfully"
                return $true
            }
        }
    }

    Write-Err "Could not auto-install Git."
    Write-Info "Install manually: winget install Git.Git"
    Write-Info "             OR: Download from https://git-scm.com"
    return $false
}

function Test-Git {
    if (-not (Test-Command "git")) {
        return Install-Git
    }

    $gitVersion = & git --version 2>&1
    Write-Success "Git found: $gitVersion"
    return $true
}

function Install-Python {
    Write-Info "Python $MinPythonVersion+ not found. Attempting to install..."

    if (Test-Command "winget") {
        Write-Info "Installing Python via winget..."
        & winget install -e --id Python.Python.3.11 --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            Refresh-Path
            $python = Find-Python
            if ($null -ne $python) {
                Write-Success "Python installed: $($python.Command) ($($python.Version))"
                return $python
            }
        }
    }

    Write-Err "Could not auto-install Python."
    Write-Info "Install manually: winget install Python.Python.3.11"
    Write-Info "             OR: Download from https://python.org"
    return $null
}

function Install-Uv {
    if (Test-Command "uv") {
        $uvVersion = & uv --version 2>&1
        Write-Success "uv found: $uvVersion"
        return $true
    }

    Write-Info "Installing uv..."
    try {
        irm https://astral.sh/uv/install.ps1 | iex

        Refresh-Path

        if (Test-Command "uv") {
            $uvVersion = & uv --version 2>&1
            Write-Success "uv installed: $uvVersion"
            return $true
        }
    } catch {
        Write-Err "Failed to install uv: $_"
    }

    Write-Err "Could not install uv automatically"
    Write-Info "Install manually from: https://docs.astral.sh/uv/"
    return $false
}

function Clone-Repo {
    param([string]$Destination)

    # Method 1: gh CLI (handles auth automatically)
    if (Test-Command "gh") {
        Write-Info "Trying clone via GitHub CLI (gh)..."
        & gh repo clone "$RepoOwner/$RepoName" $Destination -- --depth 1 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Cloned via gh CLI"
            return $true
        }
        Write-Warn "gh clone failed (not authenticated?). Trying next method..."
    }

    # Method 2: plain git clone (works with SSH keys or credential manager)
    Write-Info "Trying clone via git..."
    & git clone --depth 1 $RepoUrl $Destination 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Cloned via git"
        return $true
    }

    # Method 3: prompt for GitHub Personal Access Token
    Write-Warn "The repository is private. A GitHub Personal Access Token (PAT) is required."
    Write-Info "Create one at: https://github.com/settings/tokens (needs 'repo' scope)"
    Write-Host ""
    $token = Read-Host "GitHub PAT"
    if ([string]::IsNullOrEmpty($token)) {
        Write-Err "No token provided. Cannot clone private repository."
        return $false
    }

    & git clone --depth 1 "https://${token}@github.com/$RepoOwner/$RepoName.git" $Destination 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Cloned via PAT"
        return $true
    }

    Write-Err "All clone methods failed. Check your credentials and try again."
    return $false
}

function Main {
    if ($Help) {
        Show-Help
        return
    }

    Write-Host ""
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host "  MyAlly Installation" -ForegroundColor Cyan
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Info "Detected platform: Windows"

    # Check prerequisites
    Write-Info "Checking prerequisites..."

    if (-not (Test-Git)) {
        exit 1
    }

    # Find or install Python
    $python = Find-Python
    if ($null -eq $python) {
        $python = Install-Python
        if ($null -eq $python) {
            exit 1
        }
    } else {
        Write-Success "Python found: $($python.Command) ($($python.Version))"
    }

    # Install uv
    if (-not (Install-Uv)) {
        exit 1
    }

    # Early Node.js check (non-blocking - ally-updater handles installation)
    if (Test-Command "node") {
        try {
            $nodeOutput = & node --version 2>&1
            if ($nodeOutput -match '(\d+)') {
                $nodeMajor = [int]$Matches[1]
                if ($nodeMajor -ge 18) {
                    Write-Success "Node.js found: $nodeOutput"
                } else {
                    Write-Warn "Node.js $nodeOutput found, but >= 18 required. The installer will attempt to upgrade it."
                }
            }
        } catch {}
    } else {
        Write-Warn "Node.js not found. The installer will attempt to install it."
    }

    # Set default install directory
    if ([string]::IsNullOrEmpty($InstallDir)) {
        $InstallDir = Join-Path $env:LOCALAPPDATA "MyAlly"
    }

    # Check for existing installation
    $isUpdate = $false
    $existingAppDir = Join-Path $InstallDir "app"
    if (Test-Path $existingAppDir) {
        $isUpdate = $true
        Write-Success "Found existing installation at: $InstallDir"
    } else {
        Write-Info "Installation directory: $InstallDir"
    }

    # Confirm for fresh installs only (updates are confirmed by ally-updater CLI)
    if (-not $Yes -and -not $isUpdate) {
        $response = Read-Host "Continue with installation? [Y/n]"
        if ($response -match '^[nN]') {
            Write-Info "Installation cancelled."
            exit 1
        }
    }

    # Create temp directory
    $tmpDir = Join-Path $env:TEMP "myally-install-$(Get-Random)"
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

    try {
        Write-Info "Downloading MyAlly Update Script..."

        # Clone repository (shallow, with auth fallback)
        $repoDir = Join-Path $tmpDir "ally"
        if (-not (Clone-Repo -Destination $repoDir)) {
            Write-Err "Failed to clone repository"
            exit 1
        }

        # Verify ally-updater package exists
        $updaterDir = Join-Path $repoDir $UpdaterPackage
        if (-not (Test-Path $updaterDir)) {
            Write-Err "ally-updater package not found in repository"
            Write-Err "Expected path: $updaterDir"
            Write-Info "The repository may not have been set up correctly."
            exit 1
        }

        Write-Info "Setting up installation environment..."

        # Create a virtual environment for the updater
        $venvDir = Join-Path $tmpDir "venv"
        & uv venv $venvDir --python 3.11
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Failed to create virtual environment"
            exit 1
        }

        # Get venv Python path
        $venvPython = Join-Path $venvDir "Scripts\python.exe"

        Write-Info "Installing ally-updater..."

        # Install updater in the venv using uv (uv doesn't need pip in venv)
        Set-Location $updaterDir
        & uv pip install -e . --python $venvPython
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Failed to install ally-updater"
            exit 1
        }

        if ($isUpdate) {
            Write-Info "Starting update..."
        } else {
            Write-Info "Starting installation..."
        }

        # Run updater using the venv Python
        $installArgs = @("--install-dir", $InstallDir)
        if ($Yes) {
            $installArgs += "--yes"
        }

        & $venvPython -m ally_updater @installArgs
        $updaterExitCode = $LASTEXITCODE
    }
    finally {
        # Cleanup
        Set-Location $env:USERPROFILE
        Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Propagate updater exit code
    if ($updaterExitCode -ne 0) {
        exit $updaterExitCode
    }
}

# Run main
Main
