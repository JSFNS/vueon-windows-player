@echo off
setlocal
cd /d "%~dp0"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-VueOn.ps1" -SkipAutoLogon -MigrateLegacyStartup
set "RESULT=%ERRORLEVEL%"
if not "%RESULT%"=="0" echo VueOn installation returned exit code %RESULT%.
pause
exit /b %RESULT%
