@echo off

:main
:: Run few assign and swap commands for demo.
:: The commands are stored in the "commands" file.

setlocal EnableDelayedExpansion
cls
timeout /nobreak /t 5 > nul
set counter=1
cd /d "%~dp0"
for /f "eol=# tokens=1*" %%c in (commands) do (
    cls
    echo.
    echo [94mcommand #!counter![0m^> [93;1m%%c[0m %%d
    echo.
    cmd /c %%c %%d
    timeout /nobreak /t 5 > nul
    set /a counter+=1
)
cls
echo.
echo [93;1massign[0m
call assign
echo.
echo.
echo [93;1mswap[0m
call swap
endlocal