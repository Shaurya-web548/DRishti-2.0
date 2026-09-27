@echo off
rem Double-click to put DRishti on a public link. Close the window or press
rem Ctrl+C in it to take the site offline again.
title DRishti - live
cd /d "%~dp0"
where pwsh >nul 2>nul
if %errorlevel%==0 (set "PS=pwsh") else (set "PS=powershell")
%PS% -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-public.ps1"
echo.
pause
