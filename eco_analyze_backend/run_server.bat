@echo off
echo ====================================================
echo Starting EcoAnalyze FastAPI Backend Server
echo ====================================================
cd /d "%~dp0"

if exist "..\.venv\Scripts\python.exe" (
    echo Using project virtual environment: ..\.venv
    "..\.venv\Scripts\python.exe" -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
) else (
    python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
)

pause

