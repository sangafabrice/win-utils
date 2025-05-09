<#
.SYNOPSIS
    Gets the drive letter of a specified disk and partition number.
.DESCRIPTION
    This script retrieves the drive letter of a specified disk and partition number.
.INPUTS
    The script takes two arguments:
    1. Disk number (integer) - The number of the disk where the partition is located.
    2. Partition number (integer) - The number of the partition for which to retrieve the drive letter.
.OUTPUTS
    The script outputs the drive letter of the specified disk and partition number.
    If the drive letter is not assigned, it returns 999.
.EXAMPLE
    .\get_driveLetter.ps1 0 1
    C
    This command retrieves the drive letter of partition 1 on disk 0.
.NOTES
    This script should be executed as a for /f input command.
#>
#Requires -PSEdition Desktop

Get-Partition -DiskNumber $args[0] -Number $args[1] -ErrorAction SilentlyContinue |
Select-Object -ExpandProperty DriveLetter |
ForEach-Object {
    if ($_.ToString().Trim() -eq "") {
        return 999
    }
    return $_
}