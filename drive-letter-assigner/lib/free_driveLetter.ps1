<#
.SYNOPSIS
    Frees a drive letter.
.DESCRIPTION
    This script frees a drive letter. It takes the drive letter as an argument and attempts to remove the access path from the partition owning it. 
.INPUTS
    The script takes one argument:
    1. Drive letter (string) - The drive letter to free.
.OUTPUTS
    The script does not produce any output. It will exit with a status code indicating success or failure.
    0 indicates success, while -999 indicates failure to free the drive letter.
.EXAMPLE
    .\free_driveLetter.ps1 Z
    This command removes the access path for the drive Z:.
#>

try {
    Remove-PartitionAccessPath -DriveLetter $args[0] -AccessPath "$($args[0]):" -ErrorAction Stop
}
catch [Microsoft.PowerShell.Cmdletization.Cim.CimJobException] { 
    if(-not $_.Exception.Message.StartsWith('No MSFT_Partition objects found')) {
        exit -999
    }
}
catch {
    Get-Partition -DriveLetter $args[0] -ErrorAction SilentlyContinue |
    ForEach-Object { exit -999 }
}
exit 0