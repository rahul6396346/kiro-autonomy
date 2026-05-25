@echo off
REM ============================================================
REM  Kiro Autonomy installer - Windows double-click launcher
REM  Project: https://github.com/rahul6396346/kiro-autonomy
REM ============================================================

setlocal
set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%Enable-KiroFullAutonomy.ps1"

if not exist "%PS_SCRIPT%" (
    echo [ERROR] Could not find Enable-KiroFullAutonomy.ps1 next to this file.
    echo Looked at: %PS_SCRIPT%
    pause
    exit /b 1
)

REM Pass through any args (e.g. -Restore, -Recipe aggressive, -DryRun)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*
set "RC=%ERRORLEVEL%"

echo.
echo Press any key to close...
pause >nul
exit /b %RC%
