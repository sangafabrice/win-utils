<#
.SYNOPSIS
    Test if an assign script runner process is unique by its command line arguments.
.DESCRIPTION
    This script checks if a command prompt process running the assign.bat script is unique. It takes the command line GUID and the process ID as inputs.
.INPUTS
    The script takes two arguments:
    1. Command line GUID (string) - The GUID to check for uniqueness.
    2. Process ID (integer) - The process ID of the current script runner process.
.OUTPUTS
    The script does not produce any output. It will exit with a status code indicating success or failure.
    0 indicates success (process is unique), otherwise the process is not unique.
.EXAMPLE
    .\test_uniqueProcess.ps1 /guid:5d972861-1b53-49ea-8d6c-5debe634f8d2 1234
#>
#Requires -PSEdition Desktop

exit @(Get-CimInstance Win32_Process -Filter "Name='cmd.exe' and CommandLine like '%$($args[0])%' and ProcessId<>$($args[1])").Count