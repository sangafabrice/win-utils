<#
.SYNOPSIS
    Gets the number of a specified disk.
.DESCRIPTION
    This script retrieves the number of a specified disk. A disk can be identified by its friendly name, its serial number, and its number.
.INPUTS
    The script takes two arguments:
    1. Disk specifier (string) - The specifier used to identified the disk and its argument.
    2. Partition number (integer) - The number of the partition to retrieve.
.OUTPUTS
    The script outputs the disk number of the specified disk.
    If the disk is not found, it returns -999.
    If the partition is not found, it returns -999 + disk number (-999#).
.EXAMPLE
    .\get_diskIndex.ps1 '-FriendlyName Kingston' 1
    4
    This command retrieves the disk number of partition 1 on the first Kingston disk.
.NOTES
    This script should be executed as a for /f input command.
#>
#Requires -PSEdition Desktop

$disk =
    Invoke-Expression ('Get-Disk {0} -ErrorAction SilentlyContinue' -f $args[0]) |
    Sort-Object -Property Number |
    Select-Object -First 1
if ($disk) {
    $disk | Get-Partition -Number $args[1] -ErrorVariable partitionError -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty DiskNumber -PipelineVariable diskNumber |
    ForEach-Object { exit $_ }
    if ($partitionError) {
        exit ([int]('-999' + $disk.Number))
    }
}
exit -999