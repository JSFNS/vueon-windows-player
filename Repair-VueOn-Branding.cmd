@echo off
setlocal
cd /d "%~dp0"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Maintenance\Repair-Branding.ps1"
set "RESULT=%ERRORLEVEL%"
if not "%RESULT%"=="0" echo VueOn branding repair did not complete. Do not reset Windows.
pause
exit /b %RESULT%
