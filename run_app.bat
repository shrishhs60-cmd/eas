@echo off
title EAS - Environmental Analyzing System
echo ==========================================================
echo Starting EAS (Environmental Analyzing System)...
echo ==========================================================
cd /d "%~dp0"

:: 1. Check if backend is already responding on port 8000
powershell -Command "try { $r = Invoke-WebRequest -Uri 'http://127.0.0.1:8000/eas' -UseBasicParsing -TimeoutSec 2; exit 0 } catch { exit 1 }" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo EAS Backend is already running on http://127.0.0.1:8000/eas
) else (
    echo Starting EAS server in background across all network interfaces...
    start /b "" "d:\project\.venv\Scripts\python.exe" -m uvicorn eco_analyze_backend.main:app --host 0.0.0.0 --port 8000
    timeout /t 2 /nobreak >nul
)

:: 2. Check if Cloudflare Tunnel is running
powershell -Command "if (!(Get-Process -Name cloudflared -ErrorAction SilentlyContinue)) { exit 1 } else { exit 0 }" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Starting Cloudflare Tunnel in background...
    start /b "" "d:\project\cloudflared.exe" tunnel --url http://127.0.0.1:8000
    timeout /t 3 /nobreak >nul
)

:: 2. Launch EAS Native Window
echo Launching EAS Application...
if exist "C:\Program Files\Google\Chrome\Application\chrome.exe" (
    start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" --app="http://127.0.0.1:8000/eas" --window-size=1350,880
) else if exist "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" (
    start "" "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --app="http://127.0.0.1:8000/eas" --window-size=1350,880
) else (
    start "http://127.0.0.1:8000/eas"
)

echo.
echo ==========================================================
echo EAS is now live worldwide!
echo Public Link:  https://additional-carter-ata-mean.trycloudflare.com/eas
echo Local Link:   http://127.0.0.1:8000/eas
echo Network Link: http://192.168.23.20:8000/eas
echo ==========================================================
