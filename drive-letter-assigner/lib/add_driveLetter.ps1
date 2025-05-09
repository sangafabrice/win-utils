<#
.SYNOPSIS
    Assigns a drive letter to a partition on a specified disk.
.DESCRIPTION
    This script assigns a drive letter to a partition on a specified disk. It takes the disk number, partition number, and optionally a drive letter as arguments. If the drive letter is not provided, it will assign the next available drive letter.
.INPUTS
    The script takes three arguments:
    1. Disk number (integer) - The number of the disk where the partition is located.
    2. Partition number (integer) - The number of the partition to which the drive letter will be assigned.
    3. Drive letter (string, optional) - The drive letter to assign to the partition. If not provided, the script will assign the next available drive letter.
.OUTPUTS
    The script does not produce any output. It will exit with a status code indicating success or failure.
    0 indicates success, while -999 indicates failure to assign a drive letter.
.NOTES
    It is required to run this script on a partition without a drive letter.
.EXAMPLE
    .\add_driveLetter.ps1 0 1
    This command assigns the next available drive letter to partition 1 on disk 0.
.EXAMPLE
    .\add_driveLetter.ps1 0 1 Z
    This command assigns the drive letter Z: to partition 1 on disk 0.
#>
#Requires -PSEdition Desktop

$partitionId = @{
    DiskNumber = $args[0]
    PartitionNumber = $args[1]
}
$driveLetter = $args[2]

try {
    $partitionId + $(
        if ($args.Count -eq 3) {
            @{
                AccessPath = '{0}:' -f $driveLetter
            }
        }
        else {
            @{
                AssignDriveLetter = $true
            }
        }
    ) |
    ForEach-Object {
        Add-PartitionAccessPath @_ -ErrorAction Stop
    }
    exit 0
}
catch [Microsoft.Management.Infrastructure.CimException] {
    if (([int]($_.Exception.MessageId -split " ")[-1]) -in 42002,42012) {
        if ($args.Count -eq 3) {
            Get-Partition @partitionId -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty DriveLetter |
            ForEach-Object {
                if ($_ -eq $driveLetter) {
                    exit 0
                }
            }
        }
        else {
            exit 0
        }
    }
}
catch { }
exit -999