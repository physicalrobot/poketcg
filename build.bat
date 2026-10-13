@echo off
rem Double-click to build poketcg.gbc (runs build.sh inside WSL Ubuntu).
wsl -d Ubuntu --cd "%~dp0." -- bash ./build.sh %*
pause
