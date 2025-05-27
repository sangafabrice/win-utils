<#
.SYNOPSIS
    Gets the process ID of the current script runner process.
.DESCRIPTION
    This script retrieves the process ID of the current script runner process.
.OUTPUTS
    The script outputs the process IDs of the current script runner process and its parent. The parent process ID is retrieved first.
.EXAMPLE
    .\get_process.ps1
    2350 1234
    This command retrieves the process IDs of the current script runner process and its parent.
.NOTES
    This script should be executed as a for /f input command.
#>
#Requires -PSEdition Desktop

filter Get-CmdProcess {
    Get-CimInstance Win32_Process -Filter "ProcessId=$($_.ParentProcessId)" -Property ProcessId,ParentProcessId |
    Select-Object ProcessId,ParentProcessId
}

@{ ParentProcessId = $PID } | Get-CmdProcess | Get-CmdProcess | Get-CmdProcess |
ForEach-Object { Write-Host $_.ParentProcessId $_.ProcessId }