@echo off

:main <%* = arguments>
:: Count the number of arguments passed to the script.
:: This script is intended to be called from another script or command line.

for /f usebackq %%c in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0\get_argsCount.ps1" %*
`) do exit /b %%~c