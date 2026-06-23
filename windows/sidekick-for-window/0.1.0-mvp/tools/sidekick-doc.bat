@echo off
set "SCRIPT=%~dp0sidekick-doc.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
