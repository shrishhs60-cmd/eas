@echo off
title EAS - Deploy to GitHub & 24/7 Cloud
echo ==========================================================
echo EAS - 24/7 Cloud Deployment Helper
echo ==========================================================
echo.
echo Step 1: Create a new repository on https://github.com/new
echo         (Name it "eas" or "eas-environmental", keep it Public or Private)
echo.
set /p REPO_URL="Enter your GitHub repository URL (e.g. https://github.com/username/eas.git): "

if "%REPO_URL%"=="" (
    echo No URL entered. Aborting.
    pause
    exit /b
)

echo.
echo Connecting to GitHub and pushing EAS code...
git branch -M main
git remote remove origin >nul 2>&1
git remote add origin %REPO_URL%
git push -u origin main

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ==========================================================
    echo Code successfully pushed to GitHub!
    echo ==========================================================
    echo.
    echo Step 2: To make it live 24/7 permanently (even when PC is off):
    echo  1. Go to https://dashboard.render.com/register
    echo  2. Click "New +" -> "Web Service"
    echo  3. Select your GitHub repository
    echo  4. Click "Create Web Service"
    echo.
    echo Render will automatically detect the settings and give you
    echo a permanent 24/7 link like: https://eas-chennai.onrender.com/eas
    echo ==========================================================
) else (
    echo.
    echo Push failed. Please check your GitHub credentials or repository URL.
)

pause
