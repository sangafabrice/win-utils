<#
.SYNOPSIS
    Assigns a drive letter to a partition on a specified disk.
.DESCRIPTION
    This script assigns a drive letter to a partition on a specified disk. It takes the disk number, partition number, and a drive letter as arguments.
.INPUTS
    The script takes three arguments:
    1. Disk number (integer) - The number of the disk where the partition is located.
    2. Partition number (integer) - The number of the partition to which the drive letter will be assigned.
    3. Drive letter (string) - The drive letter to assign to the partition.
.OUTPUTS
    The script does not produce any output. It will exit with a status code indicating success or failure.
    0 indicates success, while 999 and -999 indicate failure to assign a drive letter.
    999 also indicates that the requested drive letter is already assigned to another partition.
.EXAMPLE
    .\set_driveLetter.ps1 0 1 Z
    This command assigns the drive letter Z: to partition 1 on disk 0.
#>
#Requires -PSEdition Desktop

$partitionId = @{
    DiskNumber = $args[0]
    PartitionNumber = $args[1]
}
$driveLetter = $args[2]

try {
    Set-Partition @partitionId -NewDriveLetter $driveLetter -ErrorAction Stop
    exit 0
}
catch [Microsoft.Management.Infrastructure.CimException] {
    if (([int]($_.Exception.MessageId -split " ")[-1]) -eq 42002) {
        Get-Partition @partitionId -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty DriveLetter |
        ForEach-Object {
            if ($_ -eq $driveLetter) {
                exit 0
            }
        }
        exit 999
    }
}
catch { }
exit -999