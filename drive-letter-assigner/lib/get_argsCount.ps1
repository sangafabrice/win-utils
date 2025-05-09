<#
.SYNOPSIS
    Gets the arguments count of the script.
.DESCRIPTION
    This script retrieves the number of arguments passed to the script.
.INPUTS
    The script arguments.
.OUTPUTS
    The script outputs the count of arguments passed to the script.
.EXAMPLE
    .\get_argsCount.ps1 arg1 arg2 arg3
    3
    This command retrieves the count of arguments passed to the script.
.NOTES
    This script should be executed as a for /f input command.
    It is a helper script for the main script and is not intended to be run directly.
#>
#Requires -PSEdition Desktop

$args.Count