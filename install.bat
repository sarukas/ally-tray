@echo off
REM MyAlly Installation Script - Batch Wrapper
REM
REM This wrapper launches the PowerShell installation script.
REM It provides a simple double-click installation experience on Windows.
REM Works both from the repository root (finds install.ps1 locally) and
REM as a standalone download (fetches install.ps1 from GitHub).
REM
REM Usage:
REM   install.bat [--install-dir <path>] [--force] [--component <main-app|tray|all>]

setlocal enabledelayedexpansion

REM Get the directory where this script is located
set "SCRIPT_DIR=%~dp0"

REM --- Locate or download install.ps1 ---
set "PS_SCRIPT=%SCRIPT_DIR%install.ps1"
if not exist "!PS_SCRIPT!" (
    echo install.ps1 not found locally. Downloading from GitHub...
    set "PS_SCRIPT=%TEMP%\myally-install-%RANDOM%.ps1"
    powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/sarukas/ally-tray/main/install.ps1' -OutFile '!PS_SCRIPT!'"
    if !errorlevel! neq 0 (
        echo.
        echo [ERROR] Failed to download install.ps1 from GitHub.
        echo         Check your internet connection and try again.
        pause
        exit /b 1
    )
    echo [OK] Downloaded install.ps1
    echo.
)

REM Convert arguments to PowerShell format
set "PS_ARGS="
:parse_args
if "%~1"=="" goto run_installer

if /i "%~1"=="--install-dir" (
    set "PS_ARGS=!PS_ARGS! -InstallDir "%~2""
    shift
    shift
    goto parse_args
)

if /i "%~1"=="--force" (
    set "PS_ARGS=!PS_ARGS! -Force"
    shift
    goto parse_args
)

if /i "%~1"=="--component" (
    set "PS_ARGS=!PS_ARGS! -Component "%~2""
    shift
    shift
    goto parse_args
)

if /i "%~1"=="--help" (
    set "PS_ARGS=!PS_ARGS! -Help"
    shift
    goto parse_args
)

if /i "%~1"=="-h" (
    set "PS_ARGS=!PS_ARGS! -Help"
    shift
    goto parse_args
)

REM Unknown argument, skip
shift
goto parse_args

:run_installer
REM Check if PowerShell is available
where powershell >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] PowerShell is not available on this system.
    echo Please install PowerShell or run install.ps1 directly.
    pause
    exit /b 1
)

REM Run the PowerShell script
echo Starting MyAlly Installer / Updater...
echo.

powershell.exe -ExecutionPolicy Bypass -File "!PS_SCRIPT!" !PS_ARGS!

REM Check result
set "EXIT_CODE=!errorlevel!"
if !EXIT_CODE! neq 0 (
    echo.
    if !EXIT_CODE! equ 1 (
        echo Operation cancelled or failed.
    ) else (
        echo [ERROR] Operation failed with error code !EXIT_CODE!
    )
    pause
    exit /b !EXIT_CODE!
)

echo.
echo Done!
pause
