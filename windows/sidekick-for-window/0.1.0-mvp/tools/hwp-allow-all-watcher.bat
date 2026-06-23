@echo off
set "SCRIPT=%~dp0hwp-allow-all-watcher.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
