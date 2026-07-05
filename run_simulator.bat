@echo off
echo Building and running Passed Note watch face in simulator...
powershell -ExecutionPolicy Bypass -File "%~dp0build.ps1" -Run
pause
