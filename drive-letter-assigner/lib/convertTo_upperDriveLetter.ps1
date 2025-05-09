<#
.SYNOPSIS
    Converts a drive letter to uppercase.
.DESCRIPTION
    This script converts a drive letter to uppercase. It takes the drive letter as an argument.
.INPUTS
    The script takes one argument:
    1. Drive letter (string) - The drive letter to convert to uppercase.
.OUTPUTS
    The script outputs the uppercase drive letter.
.EXAMPLE
    .\convertTo_upperDriveLetter.ps1 z
    Z
    This command converts the drive letter z: to uppercase.
.NOTES
    This script should be executed as a for /f input command.
#>
#Requires -PSEdition Desktop

$args[0].ToUpper()