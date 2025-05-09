<#
.SYNOPSIS
    Displays help information for the specified command.
.DESCRIPTION
    This script displays help information for the specified command. It takes the command name as an argument and retrieves the corresponding help text from a file.
.INPUTS
    The script takes one argument:
    1. Command name (string) - The name of the command for which to display help information.
.OUTPUTS
    The script outputs the help information for the specified command.
.EXAMPLE
    .\get_help.ps1 assign
    This command displays help information for the assign command.
#>
#Requires -PSEdition Desktop

(Get-Content $PSScriptRoot\help.txt -Raw) -replace '%commandName%',$args[0]