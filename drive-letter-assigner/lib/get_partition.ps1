<#
.SYNOPSIS
    Gets the disk number and partition number of a specified drive letter.
.DESCRIPTION
    This script retrieves the disk number and partition number of a specified drive letter. It takes the drive letter as an argument.
.INPUTS
    The script takes one argument:
    1. Drive letter (string) - The drive letter for which to retrieve the disk and partition numbers.
.OUTPUTS
    The script outputs the disk number and partition number of the specified drive letter.
.EXAMPLE
    .\get_partition.ps1 Z
    4 1
    This command retrieves the disk number and partition number of drive letter Z:.
.NOTES
    This script should be executed as a for /f input command.
#>
#Requires -PSEdition Desktop

Get-Partition -DriveLetter $args[0] -ErrorAction SilentlyContinue |
ForEach-Object { Write-Host $_.DiskNumber $_.PartitionNumber }