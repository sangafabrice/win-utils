@echo off

:main <%1 = disk filter argument> <%2 = drive letter> <%3 = disk partition number [= 1]>
:: Assign the drive letter to the disk partition.
:: the script log file path: %temp%\dp-assign-drive-letter.log

setlocal EnableExtensions EnableDelayedExpansion
:: Script GUID to easily identify the script runner process
set guid=/guid:5d972861-1b53-49ea-8d6c-5debe634f8d2& set commandName=%~n0& set commandPath=%~f0& set commandParent=%~dp0& set powershell=powershell -NoProfile -ExecutionPolicy ByPass -File& set lib=!commandParent!\lib& set tempRoot=%temp%\dp-assign-drive-letter& set tempRoot=!tempRoot:\\=\!& set defaultPartitionIndexArg=1&
:startParsing
call :dequoteArgument %*
call :log RUNNING: %commandPath% %returnedArg%
if "%returnedArg%" equ "%guid%" goto :afterCommand
cmd /s /c " "%lib%\get_argsCount.cmd" %* " & set argCount=!errorlevel!&
if errorlevel 4 call :help || goto :farEnd
if not errorlevel 2 call :help || goto :farEnd
call :dequoteArgument %~2 & set driverLetterArg=!returnedArg!& set assigneeDiskIndex=& set assignorVolumeId=&
call :dequoteArgument %~1
call :isPartitionSpecifierLetter "%returnedArg%" || if not errorlevel 0 ( for /f "tokens=2 delims=:" %%l in ("%returnedArg%") do call :echoError 201 %%~l || goto :farEnd ) else goto :partitionParsing
if "%argCount%"=="3" call :echoError 201 %~3 || goto :farEnd
:volumeParsing
for /f "tokens=2 delims=:" %%l in ("%returnedArg%") do for /f %%L in ('%powershell% "%lib%\convertTo_upperDriveLetter.ps1" %%~l') do (
	call :isPartitionNot_C_Drive %%~L || goto :farEnd
	call :getPartitionName %%~L assigneeDiskIndex assigneePartitionIndex assigneePartitionName || call :echoError 209 %%~L || goto :farEnd
	set "assigneeCurrentLetter=%%~L"
)
call :setNonPositionedArgs %driverLetterArg% %defaultPartitionIndexArg% driveLetter || call :echoError 201 %driverLetterArg% || goto :farEnd
goto :getComputedInfo
:partitionParsing
set diskFilterArg=%returnedArg%& set diskSearchFilter=&
call :getDiskFilterClause diskFilterArg diskSearchFilter || call :echoError 201 %1 || goto :farEnd
call :dequoteArgument %~3 & set partitionIndexArg=!returnedArg!&
if not defined partitionIndexArg set "partitionIndexArg=%defaultPartitionIndexArg%"
call :setNonPositionedArgs %driverLetterArg% %partitionIndexArg% driveLetter assigneePartitionIndex || call :echoError 202 "%~2" "%partitionIndexArg%" || goto :farEnd
%powershell% "%lib%\get_diskIndex.ps1" "%diskSearchFilter%" %assigneePartitionIndex%
if errorlevel 0 ( set "assigneeDiskIndex=%errorlevel%" ) else ( if not errorlevel -999 ( call :echoError 203 %assigneePartitionIndex% %errorlevel:-999=% ) else if %errorlevel%==-999 call :echoError 204 ) || goto :farEnd
set assigneePartitionName=Disk #%assigneeDiskIndex%, Partition #%assigneePartitionIndex%
call :getDriveLetter %assigneeDiskIndex% %assigneePartitionIndex% assigneeCurrentLetter || if errorlevel 1 ( goto :getComputedInfo ) else goto :farEnd
call :isPartitionNot_C_Drive %assigneeCurrentLetter% || goto :farEnd
:getComputedInfo
call :isPartitionNot_C_Drive %driveLetter% || goto :farEnd
if "%driveLetter%"=="%assigneeCurrentLetter%" goto :end
set assigneePartitionName=Disk #%assigneeDiskIndex%, Partition #%assigneePartitionIndex%& set assignorNextLetter=%assigneeCurrentLetter%&
call :echoTitle %driveLetter% "%assigneePartitionName%"
if defined assigneeCurrentLetter call :echoNeutralWarning 106 "%assigneePartitionName%" %assigneeCurrentLetter%
:command
echo %driveLetter%:_%assigneeCurrentLetter%:| find /i "%~d0" > nul && xcopy "%commandParent%" "%tempRoot%" /i /y /s > nul 2>&1 && cd /d "%tempRoot%" 2> nul && set "commandPath=%tempRoot%\%~nx0"
:: Restart the runner process with the guid argument
cmd /d /c "%commandPath%" %guid%
goto :farEnd
:afterCommand
for /f "tokens=1,2" %%i in ('%powershell% "%lib%\get_process.ps1"') do call :log [PROCESS ID: %%~j] [PARENT PROCESS ID: %%~i]& set "processId= [%%~j]"& cmd /c exit %%~j
%powershell% "%lib%\test_uniqueProcess.ps1" %guid% %errorlevel% || call :echoWarning 101 || goto :farEnd
set runSecondTime=&
:assignletter
%powershell% "%lib%\set_driveLetter.ps1" %assigneeDiskIndex% %assigneePartitionIndex% %driveLetter% && call :echoSuccess 001 %driveLetter% && if defined runSecondTime ( goto :rollbackAssignment ) else goto :end
if defined runSecondTime ( call :echoError 206 %driveLetter% || set "assignorNextLetter=%driveLetter%" && goto :rollbackAssignment ) else set runSecondTime=true
call :getPartitionName %driveLetter% assignorDiskIndex assignorPartitionIndex assignorPartitionName && call :echoNeutralWarning 105 "!assignorPartitionName!" %driveLetter%
%powershell% "%lib%\free_driveLetter.ps1" %driveLetter% || call :echoError 205 %driveLetter% || goto :farEnd
goto :assignletter
:rollbackAssignment
if not defined assignorPartitionName goto :end
%powershell% "%lib%\add_driveLetter.ps1" %assignorDiskIndex% %assignorPartitionIndex% %assignorNextLetter% || ( if "%assignorNextLetter%"=="%driveLetter%" ( call :echoWarning 102 %driveLetter% ) else call :echoWarning 103 "%assignorPartitionName%" ) || goto :farEnd
call :getDriveLetter %assignorDiskIndex% %assignorPartitionIndex% assignorNextLetter && if "%assignorNextLetter%" neq "%driveLetter%" ( call :echoNeutralWarning 104 "%assignorPartitionName%" !assignorNextLetter! ) else cmd /c exit -999
:end
if %errorlevel% equ 0 call :echoSuccess 002
:farEnd
endlocal
exit /b

:dequoteArgument <%* = quoted argument>
set returnedArg=_%*
set returnedArg=%returnedArg:"=%
set returnedArg=%returnedArg:~1%
exit /b

:echo<EventType> <%1 = message index> <%2 = message arguments>
:echoSuccess <%1 = 0** index>
< nul set /p "=[92;1m"& goto :_getMessage
:echoWarning <%1 = 1** index>
< nul set /p "=[93;1m"& goto :_getMessage
:echoError <%1 = 2** index>
< nul set /p "=[31;1m"& goto :_getMessage
:_getMessage
setlocal & goto :_getMessage[%~1]
:_getMessage[001] <%2 = drive letter>
set message[001]=%~2 was assigned to the target partition...& goto :_echoMessage
:_getMessage[002]
set message[002]=The task completed successfully.& goto :_echoMessage
:_getMessage[101]
set message[101]=STOPPED: An instance of the script is already running.& goto :_echoMessage
:_getMessage[102] <%2 = drive letter>
set message[102]=ROLL BACK: %~2 was reassigned back to its original owner.& goto :_echoMessage
:_getMessage[103] <%2 = assignor disk partition name>
set message[103]=WARNING: Failure to assign a new letter to "%~2".& goto :_echoMessage
:_getMessage[104] <%2 = assignor disk partition name> <%3 = assignor drive letter>
set message[104]=WARNING: %~3 was assigned to "%~2" as replacement.& goto :_echoMessage
:_getMessage[105] <%2 = assignor disk partition name> <%3 = assignor drive letter>
set message[105]=WARNING: %~3 is currently assigned to "%~2"...& goto :_echoMessage
:_getMessage[106] <%2 = assignee disk partition name> <%3 = assignee drive letter>
set message[106]="%~2" is currently assigned %~3...& goto :_echoMessage
:_getMessage[201] <%2 = unexpected argument>
set message[201]=ERROR: %2 was unexpected at this time.& goto :_echoMessage
:_getMessage[202] <%2 = unexpected argument> <%3 = unexpected argument>
set message[202]=ERROR: {"%~2", "%~3"} is not a combination of a letter character and a decimal integer.& goto :_echoMessage
:_getMessage[203] <%2 = invalid disk partition index> <%3 = disk index>
set message[203]=ERROR: The partition index #%~2 is invalid for the disk #%~3.& goto :_echoMessage
:_getMessage[204]
set message[204]=ERROR: The disk device was not found.& goto :_echoMessage
:_getMessage[205] <%2 = drive letter>
set message[205]=ABORT: The %~2's owner did not release it.& goto :_echoMessage
:_getMessage[206] <%2 = drive letter>
set message[206]=ABORT: The letter %~2 was not assigned to the target partition.& goto :_echoMessage
:_getMessage[207]
set message[207]=ABORT: Modifying the C partition is not allowed.& goto :_echoMessage
:_getMessage[208] <%2 = assignee current letter> <%3 = assignee partition name>
set message[208]=ERROR: Failed to reassign %~2 to "%~3".& goto :_echoMessage
:_getMessage[209] <%2 = assignee current letter>
set message[209]=ERROR: The partition assigned %~2 was not found.& goto :_echoMessage
:_echoMessage
echo !message[%~1]![0m& echo.
echo %~1| findstr "202 201" > nul && call :help
call :log !message[%~1]!
endlocal
echo %~0| findstr /e "Warning" > nul && exit /b 999
echo %~0| findstr /e "Error" > nul && exit /b -999
exit /b 0

:echoNeutralWarning <%* = warning message text>
:: echo warning without changing the errorlevel value
setlocal
set errLvl=%errorlevel%
call :echoWarning %*
cmd /c exit %errLvl%
endlocal
exit /b

:echoTitle <%1 = drive letter> <%2 = assignee disk partition name>
echo.
for /f %%i in ('echo 97^& echo 30^& echo 97') do echo [%%i;107m Assigning %~1 to "%~2"... [0m
call :log "%~2" requests %~1
echo.
exit /b 0

:getDiskFilterClause <%1 = unquoted disk filter argument varialbe name> <%2 = [out] disk filter criteria>
:: the disk number (i) argument is converted to: Index=i
:: the disk model substring (s) argument is converted to: FriendlyName like %s%
:: the disk serial number (sn) argument is converted to: SerialNumber='sn'
echo !%~1!| findstr /ixrc:"/i:[0-9][0-9]*" | findstr /ixrvc:"/i:0[0-9][0-9]*" > nul && set %~2=!%~1:/i:=-Number !&& exit /b 0
echo !%~1!| findstr /ibrc:"/m:" > nul && set %~2=!%~1:/m:=-FriendlyName '*!*'&& exit /b 0
echo !%~1!| findstr /ibrc:"/s:" > nul && set %~2=!%~1:/s:=-SerialNumber '!'&& exit /b 0
exit /b -999

:getDriveLetter <%1 = disk number> <%2 = disk partition number> <%3 = [out] drive letter>
set %~3=&
for /f %%l in ('%powershell% "%lib%\get_driveLetter.ps1" %~1 %~2') do if "%%~l"=="999" ( exit /b 999 ) else set "%~3=%%~l"& exit /b 0
call :echoError 203 %~2 %~1
exit /b -999

:getPartitionName <%1 = drive letter> <%2 = [out] disk number> <%3 = [out] disk partition number> <%4 = [out] disk partition name>
set %~2=& set %~3=& set %~4=&
for /f "tokens=1,2" %%i in ('%powershell% "%lib%\get_partition.ps1" %~1') do set "%~2=%%~i" & set "%~3=%%~j" & set "%~4=Disk #%%~i, Partition #%%~j" & exit /b 0
exit /b 999

:help
call :log ABORT: The task stopped.
%powershell% "%lib%\get_help.ps1" %commandName%
exit /b 1

:isPartitionNot_C_Drive <%1 = partition drive letter>
echo %~1| find /i /v "C" > nul || call :echoError 207
exit /b

:isPartitionSpecifierLetter <%1 = partition specifier option>
echo %~1| findstr /ixrc:"/v:[A-Z]" > nul && exit /b 0
echo %~1| findstr /ibrc:"/v:" > nul && exit /b -999
exit /b 999

:log <%* = log message>
(echo [%date:~4% %time:~0,-3%]%processId% %*>> "%temp%\dp-assign-drive-letter.log") > nul
exit /b %errorlevel%

:setNonPositionedArgs <%1 = argument1> <%2 = argument2> <%3 = [out] drive letter> <%4 = [out] disk partition 0-based index>
call :_setNonPositionedArgs %* || call :_setNonPositionedArgs %2 %1 %3 %4 || exit /b -999
exit /b 0
:_setNonPositionedArgs <%1 = argument1> <%2 = argument2> <%3 = [out] drive letter> <%4 = [out] disk partition 0-based index>
echo _%~1_%~2| findstr /ixrc:"_[A-Z]_[0-9][0-9]*" | findstr /ixvrc:"_[A-Z]_0[0-9][0-9]*" > nul || exit /b 999
( if "%~4" neq "" set "%~4=%~2" ) & for /f %%L in ('%powershell% "%lib%\convertTo_upperDriveLetter.ps1" %~1') do set "%~3=%%~L"
exit /b 0