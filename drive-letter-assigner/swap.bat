@echo off

:main <%1 = partition specifier option> <%2 = drive letter> [<%3 = disk partition 0-based index [= 0]>]
:: Swap the volume or partition drive letter with another.
:: the script log file path: %temp%\dp-assign-drive-letter.log

:: Call script functions
if "%~1"=="call" ( for %%m in (%~2) do ( shift & shift & goto %%~m ) & exit /b )

setlocal EnableExtensions EnableDelayedExpansion
:: Script GUID to easily identify the script runner process
set guid=/guid:5d972861-1b53-49ea-8d6c-5debe634f8d2& set commandName=%~n0& set commandPath=%~f0&
:startParsing
call :dequoteArgument %*
call :log RUNNING: %commandPath% %returnedArg%
if "%returnedArg%" equ "%guid%" goto :afterCommand
call :getArgCount %* & set argCount=!errorlevel!&
if errorlevel 4 call :help || goto :farEnd
if not errorlevel 2 call :help || goto :farEnd
call :dequoteArgument %~2 & set driverLetterArg=!returnedArg!& set assigneeDiskIndex=& set assignorVolumeId=&
call :dequoteArgument %~1
call :isPartitionSpecifierLetter "%returnedArg%" || if not errorlevel 0 ( for /f "tokens=2 delims=:" %%l in ("%returnedArg%") do call :echoError 201 %%~l || goto :farEnd ) else goto :partitionParsing
if "%argCount%"=="3" call :echoError 201 %~3 || goto :farEnd
:volumeParsing
for /f "tokens=2 delims=:" %%l in ("%returnedArg%") do for /f %%L in ('"%commandPath%" call :toUpperDriveLetter %%~l') do (
	call :isPartitionNot_C_Drive %%~L || goto :farEnd
	call :getPartitionName %%~L: assigneeDiskIndex assigneePartitionIndex assigneePartitionName || call :echoError 209 %%~L || goto :farEnd
	set "assigneeCurrentLetter=%%~L"
)
call :setNonPositionedArgs %driverLetterArg% 0 driveLetter || call :echoError 201 %driverLetterArg% || goto :farEnd
goto :getComputedInfo
:partitionParsing
set diskFilterArg=%returnedArg%& set diskSearchFilter=&
call :getDiskFilterClause diskFilterArg diskSearchFilter || call :echoError 201 %1 || goto :farEnd
call :dequoteArgument %~3
set partitionIndexArg=%returnedArg%& set defaultPartitionIndexArg=0&
if not defined partitionIndexArg set "partitionIndexArg=%defaultPartitionIndexArg%"
call :setNonPositionedArgs %driverLetterArg% %partitionIndexArg% driveLetter assigneePartitionIndex || call :echoError 202 "%~2" "%partitionIndexArg%" || goto :farEnd
call :findDiskIndex "%diskSearchFilter%" %assigneePartitionIndex%
if errorlevel 0 ( set "assigneeDiskIndex=%errorlevel%" ) else goto :farEnd
set assigneePartitionName=Disk #%assigneeDiskIndex%, Partition #%assigneePartitionIndex%
call :getDriveLetter "%assigneePartitionName%" assigneeCurrentLetter || call :echoError 210 "%assigneePartitionName%" || goto :farEnd
call :isPartitionNot_C_Drive %assigneeCurrentLetter% || goto :farEnd
:getComputedInfo
call :isPartitionNot_C_Drive %driveLetter% || goto :farEnd
if "%driveLetter%"=="%assigneeCurrentLetter%" goto :end
set assignorNextLetter=& set dpScript=%temp%\dp-bat&
call :echoTitle %driveLetter% "%assigneePartitionName%"
call :echoNeutralWarning 106 "%assigneePartitionName%" %assigneeCurrentLetter%
set "assignorNextLetter=%assigneeCurrentLetter%"
call :getPartitionName %driveLetter%: assignorDiskIndex assignorPartitionIndex assignorPartitionName || goto :command
call :echoNeutralWarning 105 "%assignorPartitionName%" %driveLetter%
call :getVolumeId %driveLetter% assignorVolumeId
:command
echo %driveLetter%:_%assigneeCurrentLetter%:| find /i "%~d0" > nul && copy "%commandPath%" "%temp%" /y > nul 2>&1 && cd /d "%temp%" 2> nul && set "commandPath=%temp%\%~nx0"
:: Restart the runner process with the guid argument
cmd /d /c "%commandPath%" %guid%
goto :farEnd
:afterCommand
call :getProcessId
if errorlevel 1 set processId= [%errorlevel%]&
call :isScriptRunnerProcessUnique %errorlevel% || call :echoWarning 101 || goto :farEnd
:assignletter
call :resetErrorLevel
if defined assignorPartitionName call :removeVolumeDriveLetter %driveLetter% || call :echoError 205 %driveLetter% || goto :end
call :setVolumeDriveLetter "DriveLetter='%assigneeCurrentLetter%:'" %driveLetter% || (
	call :echoError 206 %driveLetter%
	set "assignorNextLetter=%driveLetter%"
)
if %errorlevel% equ 0 call :echoSuccess 001 %driveLetter%
if defined assignorPartitionName call :setVolumeDriveLetter "DeviceID='%assignorVolumeId%'" %assignorNextLetter% || if "%assignorNextLetter%"=="%driveLetter%" ( call :echoWarning 102 %driveLetter% ) else call :echoWarning 103 "%assignorPartitionName%"
if defined assignorPartitionName if %errorlevel% equ 0 (
	if not defined assignorNextLetter call :getDriveLetter "%assignorPartitionName%" assignorNextLetter
	if "%assignorNextLetter%" neq "%driveLetter%" call :echoNeutralWarning 104 "%assignorPartitionName%" !assignorNextLetter!
)
:end
if %errorlevel% equ 0 if "%assignorNextLetter%" neq "%driveLetter%" call :echoSuccess 002
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
set message[102]=ROLL BACK: Failure to reassign %~2 back to its original owner.& goto :_echoMessage
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
:_getMessage[210] <%2 = assignee partition name>
set message[210]=ERROR: The partition "%~2" has no drive letter assigned.& goto :_echoMessage
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
call :return errLvl
endlocal
exit /b

:echoTitle <%1 = drive letter> <%2 = assignee disk partition name>
echo.
for /f %%i in ('echo 97^& echo 30^& echo 97') do echo [%%i;107m Assigning %~1 to "%~2"... [0m
call :log "%~2" requests %~1
echo.
exit /b 0

:findDiskIndex <%1 = disk WQL filter> <%2 = disk partition 0-based index>
for /f "eol=- tokens=1,2 skip=2" %%i in ('powershell -NoProfile Get-CimInstance Win32_DiskDrive -Filter """%~1""" -Property Index^,Partitions ^^^| Select-Object Index^,Partitions ^^^| Sort-Object ^^^| Format-Table') do (
	rem The partition index cannot be greater or equal to the disk's partition count (Partitions),
	if %%~j leq %~2 call :echoError 203 %~2 %%~i || exit /b -999
	exit /b %%~i
)
call :echoError 204
exit /b

:forceErrorCode
exit /b -999

:getArgCount <%* = arguments>
setlocal
set count=0
:_whileArgNotNull
set var=%1
shift
if defined var if %count% lss 5 set /a count+=1 & goto :_whileArgNotNull
call :return count
endlocal
exit /b

:getDiskFilterClause <%1 = unquoted disk filter argument varialbe name> <%2 = [out] disk WQL filter>
:: the disk 0-based index (i) argument is converted to: Index=i
:: the disk model substring (s) argument is converted to: Model like %s%
:: the disk serial number (sn) argument is converted to: SerialNumber='sn'
echo !%~1!| findstr /ixrc:"/i:[0-9][0-9]*" | findstr /ixrvc:"/i:0[0-9][0-9]*" > nul && set %~2=!%~1:/i:=Index=!&& exit /b 0
echo !%~1!| findstr /ibrc:"/m:" > nul && set %~2=!%~1:/m:=Model like '%%%%!%%%%'&& exit /b 0
echo !%~1!| findstr /ibrc:"/s:" > nul && set %~2=!%~1:/s:=SerialNumber='!'&& exit /b 0
exit /b -999

:getDriveLetter <%1 = disk partition name> <%2 = [out] drive letter>
set %~2=&
for /f "tokens=1 delims=:" %%l in ('powershell -NoProfile ^(Get-CimInstance -Query """Associators of {Win32_DiskPartition='%~1'} Where ResultClass=Win32_LogicalDisk"""^).Name 2^> nul') do set "%~2=%%~l"& exit /b 0
exit /b -999

:getPartitionName <%1 = drive letter> <%2 = [out] disk 0-based index> <%3 = [out] disk partition 0-based index> <%4 = [out] disk partition name>
set %~2=& set %~3=& set %~4=&
for /f "tokens=2,4 delims=#," %%i in ('powershell -NoProfile ^(Get-CimInstance -Query """Associators of {Win32_LogicalDisk='%~1'} Where ResultClass=Win32_DiskPartition"""^).Name 2^> nul') do (
	set "%~2=%%~i"
	set "%~3=%%~j"
	set "%~4=Disk #%%~i, Partition #%%~j"
	exit /b 0
)
exit /b 999

:getProcessId
:: Get the process id of the script runner for logging purposes
setLocal
set pid=0&
set gps=Get-CimInstance Win32_Process -Filter """ProcessId=$PID""" -Property ProcessId^^,ParentProcessId&
for /f "eol=- tokens=1,2 skip=2" %%i in ('powershell -NoProfile ^(%gps%^).ParentProcessId ^^^| ForEach-Object { ^(%gps:PID=_%^).ParentProcessId } ^^^| ForEach-Object { ^(%gps:PID=_%^) ^^^| Format-Table ParentProcessId^,ProcessId }') do call :log [PROCESS ID: %%~j] [PARENT PROCESS ID: %%~i]& set "pid=%%~j"
call :return pid
endlocal
exit /b

:getVolumeId <%1 = drive letter> <%2 = volume Id>
for /f "eol=- tokens=1,2 skip=2" %%i in ('powershell -NoProfile Get-CimInstance Win32_Volume -Filter """DriveLetter='%~1:'""" -Property DeviceID ^^^| Format-Table DeviceID') do (
	set "%~2=%%~i" & set "%~2=!%~2:\=\\!"
	exit /b 0
)
exit /b -999

:help
call :log ABORT: The task stopped.
echo [1mSwap the volume or partition drive letter with another.[0m& echo.
echo %commandName% [4mdisk filter option[24m [4mdrive letter[24m [[4mdisk partition 0-based index[24m]& echo.
echo %commandName% [4mvolume letter specifier[24m [4mdrive letter[24m& echo.
echo The [4mdisk filter option[24m must be the first argument and can be:
echo /i:[4minteger[24m	The selected disk 0-based index.
echo 	 	It must be a decimal integer.
echo /m:[4mstring[24m	The selected disk model substring.
echo /s:[4mstring[24m	The selected disk serial number string.& echo.
echo The [4mvolume letter specifier[24m must be the first argument and is:
echo /v:[4mchar[24m	The selected volume drive letter.& echo.
echo When the user input a [4mdisk filter option[24m, the resulting partition must have a drive letter assigned.
echo The positions of the [4mdrive letter[24m and the [4mdisk partition 0-based index[24m can be swapped.
echo They must be a letter character and a decimal integer, respectively.
exit /b 1

:isPartitionNot_C_Drive <%1 = partition drive letter>
echo %~1| find /i /v "C" > nul || call :echoError 207
exit /b

:isPartitionSpecifierLetter <%1 = partition specifier option>
echo %~1| findstr /ixrc:"/v:[A-Z]" > nul && exit /b 0
echo %~1| findstr /ibrc:"/v:" > nul && exit /b -999
exit /b 999

:isScriptRunnerProcessUnique <%1 = current process id>
:: Reinforce that the script runners execute sequentially
powershell -NoProfile (Get-CimInstance Win32_Process -Filter """Name='cmd.exe' and CommandLine like '%%!guid!%%' and ProcessId<>%~1""" -Property CommandLine).CommandLine | find /c "%guid%" | find "0" > nul
exit /b

:log <%* = log message>
(echo [%date:~4% %time:~0,-3%]%processId% %*>> "%temp%\dp-assign-drive-letter.log") > nul
exit /b %errorlevel%

:removeVolumeDriveLetter <%1 = drive letter>
powershell -NoProfile (Get-CimInstance Win32_Volume -Filter """DriveLetter='%~1:'""" -Property DriveLetter ^| Set-CimInstance -Arguments @{ DriveLetter=$NULL } -PassThru).DriveLetter | findstr /ixl "%~1:" > nul || exit /b 0
exit /b -999

:resetErrorLevel
exit /b 0

:return <%1 = error code variable name>
exit /b !%~1!

:setNonPositionedArgs <%1 = argument1> <%2 = argument2> <%3 = [out] drive letter> <%4 = [out] disk partition 0-based index>
call :_setNonPositionedArgs %* || call :_setNonPositionedArgs %2 %1 %3 %4 || exit /b -999
exit /b 0
:_setNonPositionedArgs <%1 = argument1> <%2 = argument2> <%3 = [out] drive letter> <%4 = [out] disk partition 0-based index>
echo _%~1_%~2| findstr /ixrc:"_[A-Z]_[0-9][0-9]*" | findstr /ixvrc:"_[A-Z]_0[0-9][0-9]*" > nul || exit /b 999
( if "%~4" neq "" set "%~4=%~2" ) & for /f %%L in ('"%commandPath%" call :toUpperDriveLetter %~1') do set %~3=%%~L
exit /b 0

:setVolumeDriveLetter <%1 = volume specifier> <%2 = new drive letter>
powershell -NoProfile (Get-CimInstance Win32_Volume -Filter """%~1""" -Property DriveLetter ^| Set-CimInstance -Arguments @{ DriveLetter="""%~2:""" } -PassThru).DriveLetter | findstr /ixl "%~2:" > nul && exit /b 0
exit /b -999

:toUpperDriveLetter <%1 = char argument>
powershell -NoProfile '%~1'.ToUpper() | findstr /xrc:"[A-Z]"
exit /b