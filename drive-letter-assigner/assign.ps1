<#
.SYNOPSIS
    Assigns a drive letter to a partition.
.DESCRIPTION
    This script assigns a drive letter to a partition. It can be used to assign a drive letter to a partition based on its disk number, partition number, or serial number. The script can also be used to assign a drive letter to a partition based on its volume name. The script mitigates the risk of assigning a drive letter to the C partition, which is not allowed. The script also handles the case where the drive letter is already assigned to another partition. In this case, the script will attempt to remove the drive letter from the other partition and assign it to the target partition.
.INPUTS
    The arguments used to identify the partition to modify are:
    1. The disk option specifier to identify the disk where the partition resides, and the partition number — optional, if not provided, the first partition will be used — which can be input as follows:
        /i:<disk number> <partition number>
        /m:<disk name> <partition number>
        /s:<serial number> <partition number>
    2. The drive letter that the partition is currently using. the partition number is not needed since the volume name identifies the partitiona in whole.
        /v:<volume name>
    3. The drive letter to assign to the partition.
.OUTPUTS
    The steps taken to assign the drive letter to the partition are logged to a file in the TEMP directory and displayed on the console.
.EXAMPLE
    .\assign.ps1 /m:"Kingston Data" H
    .\assign.ps1 /m:"Kingston Data" H 1
    .\assign.ps1 /m:"Kingston Data" 1 H
    Assigns the drive letter H to the first partition on disk identified with the model name "Kingston Data".
.EXAMPLE
    .\assign.ps1 /v:D H
    Swaps the drive letters D and H between their associated partitions. It assigns to one partition the drive letter of the other if H is used. Otherwise, it assigns the drive letter to the partition using the drive letter D.
#>
#Requires -PSEdition Desktop
#Requires -RunAsAdministrator
#Requires -Modules Storage

Start-Job {
    $script:PSScriptRoot = $using:PSScriptRoot
    $script:CommandPath = $using:MyInvocation.MyCommand.Path

    log RUNNING: $CommandPath ($args -join ' ')
    
    # Check the number of arguments
    if ($args.Count -notin 2,3) {
        if ($args.Count -gt 3) {
            echoError 201 $args[3]
        }
        elseif ($args.Count -eq 1 -and $args[0] -ne '/?') {
            echoError 214
        }
        help
    }
    
    # Parse the option specifier
    $optionSpecifier = $args[0]
    if ($optionSpecifier -notmatch '^/((i:(0|([1-9]\d*)))|([ms]:[\w\- ]+)|(v:[A-Z]))$') {
        switch -regex ($optionSpecifier) {
            ^/[imsv]:?$ { echoError 210 }
            ^/i:0\d+$ {
                echoError 211
                break
            }
            '^/i:(?<InvalidArgument>.+)$' { echoError 212 $Matches.InvalidArgument }
            '^/v:(?<InvalidArgument>.+)$' { echoError 213 $Matches.InvalidArgument }
            default { echoError 201 $optionSpecifier }
        }
        help
    }
    $optionSpecifierArg = $optionSpecifier.ToString().Substring(3)
    
    # Parse the drive letter and partition number
    $driveLetter, $partitionNumber = $args[1..2] | Sort-Object -Descending
    if ($driveLetter -notmatch '^[A-Z]$') {
        echoError 213 $driveLetter
        help
    }
    $driveLetter = $driveLetter.ToUpper()
    abortCDriveModification $driveLetter
    
    # Get the assignee partition object
    if ($optionSpecifier.StartsWith('/v:')) {
        # The volume option specifier does not take a partition number
        if ($args.Count -eq 3) {
            echoError 201 $args[2]
            help
        }
        try {
            $assigneePartition = Get-Partition -DriveLetter $optionSpecifierArg -ErrorAction Stop
        }
        catch {
            echoError 209 $optionSpecifierArg
            exit -999
        }
    }
    else {
        if ($null -eq $partitionNumber) {
            $defaultPartitionNumber = 1
            $partitionNumber = $defaultPartitionNumber
        }
        if ($partitionNumber -notmatch '^0|([1-9]\d*)$') {
            echoError 202 $partitionNumber
            help
        }
        $getDiskArgs = @{}
        switch ($optionSpecifier[1]) {
            'i' { $getDiskArgs.Add('Number', [int] $optionSpecifierArg) }
            'm' { $getDiskArgs.Add('FriendlyName', "*$optionSpecifierArg*") }
            's' { $getDiskArgs.Add('SerialNumber', $optionSpecifierArg) }
        }
        $assigneePartition =
            Get-Disk @getDiskArgs -OutVariable assigneeDisk -ErrorVariable diskError -ErrorAction SilentlyContinue |
            Sort-Object Number |
            Select-Object -First 1 |
            Get-Partition -Number $partitionNumber -ErrorVariable partitionError -ErrorAction SilentlyContinue
        if ($diskError) {
            echoError 204
            exit -999
        }
        if ($partitionError) {
            echoError 203 $partitionNumber $assigneeDisk.Number
            exit -999
        }
    }
    abortCDriveModification $assigneePartition.DriveLetter
    
    # Ensure that the script is executed sequentially
    $currentJobHoldsMutex = $false
    $mutex = New-Object System.Threading.Mutex($true, 'Global\5d972861-1b53-49ea-8d6c-5debe634f8d2', [ref] $currentJobHoldsMutex)
    if (-not $currentJobHoldsMutex) {
        echoWarning 101
        $mutex.Dispose()
        exit 999
    }

    # Assign the drive letter to the partition
    try {
        if ($driveLetter -ne $assigneePartition.DriveLetter) {
            echoTitle $driveLetter $assigneePartition
            echoWarning 106 $assigneePartition
            setPartition $assigneePartition $driveLetter
        }
        else {
            echoSuccess 003 $driveLetter
            exit 0
        }
    }
    catch {
        Remove-PartitionAccessPath -DriveLetter $driveLetter -AccessPath "${driveLetter}:" -PassThru -OutVariable assignorPartition -ErrorVariable removalError -ErrorAction SilentlyContinue |
        ForEach-Object {
            echoWarning 105 $assignorPartition $driveLetter

            # Set the next assignor drive letter
            if ('' -ne $assigneePartition.DriveLetter) {
                $addParams = @{ AccessPath = "$($assigneePartition.DriveLetter):" }
            }
            else {
                $addParams = @{ AssignDriveLetter = $true }
            }
    
            # Second attempt to assign the drive letter
            try {
                setPartition $assigneePartition $driveLetter
            }
            catch {
                echoError 206 $driveLetter
                # Rollback the assignor drive letter
                $addParams = @{ AccessPath = "${driveLetter}:" }
            }
    
            # Set the assignor drive letter
            try {
                $assignorPartition =
                    $assignorPartition | Add-PartitionAccessPath @addParams -PassThru -ErrorAction Stop |
                    Get-Partition
                if ($driveLetter -eq $assignorPartition.DriveLetter) {
                    echoWarning 102 $driveLetter
                    exit -999
                }
                else {
                    echoWarning 104 $assignorPartition
                }
            }
            catch {
                if ("${driveLetter}:" -eq $addParams.AccessPath) {
                    echoError 208 $driveLetter
                    exit -999
                }
                else {
                    echoWarning 103 $assignorPartition
                    exit -999
                }
            }
        }
        if ($removalError) {
            echoError 205 $driveLetter
            exit -999
        }
    }
    finally {
        $mutex.ReleaseMutex()
        $mutex.Dispose()
    }
    echoSuccess 002
    exit 0
} -InitializationScript {    
    function abortCDriveModification {
        if ($args[0] -eq 'C') {
            echoError 207
            exit -999
        }
    }
    
    function echoError {
        log (getMessage $args)
        Write-Host (getMessage $args) -ForegroundColor Red; Write-Host
    }
    
    function echoSuccess {
        log (getMessage $args)
        Write-Host (getMessage $args) -ForegroundColor Green; Write-Host
    }
    
    function echoWarning {
        log (getMessage $args)
        Write-Host (getMessage $args) -ForegroundColor Yellow; Write-Host
    }
    
    function echoTitle {
        $partitionName = getPartitionName $args[1]
        foreach ($color in 'White','Black','White') {
            Write-Host " Assigning $($args[0]) to $partitionName... " -BackgroundColor White -ForegroundColor $color
        }
        Write-Host
    }
    
    function getMessage {
        $messageIndex = $args[0][0]
        $messageArguments = $args[0][1..($args[0].Count - 1)]
        switch ($messageIndex) {
            001 {
                $driveLetter = $messageArguments[0]
                "The drive letter $driveLetter was assigned to the target partition..."
            }
            002 { "The task completed successfully." }
            003 {
                $driveLetter = $messageArguments[0]
                "The drive letter $driveLetter is already assigned to the target partition."
            }
            101 { "STOPPED: An instance of the script is already running." }
            102 {
                $driveLetter = $messageArguments[0]
                "ROLL BACK: The drive letter $driveLetter was reassigned back to the source partition."
            }
            103 {
                $assignorPartitionName = getPartitionName $messageArguments[0]
                "WARNING: Failure to assign a new drive letter to $assignorPartitionName."
            }
            104 {
                $assignorDriveLetter = $messageArguments[0].DriveLetter
                "WARNING: The drive letter $assignorDriveLetter was assigned to the source partition."
            }
            105 {
                $assignorPartitionName = getPartitionName $messageArguments[0]
                $driveLetter = $messageArguments[1]
                "WARNING: $assignorPartitionName released the drive letter $driveLetter..."
            }
            106 {
                $assigneePartitionName = getPartitionName $messageArguments[0]
                $driveLetter = $messageArguments[0].DriveLetter
                "$assigneePartitionName is currently assigned the drive letter $driveLetter..."
            }
            201 {
                $commandLineTypo = $messageArguments[0]
                "ERROR: $commandLineTypo was unexpected at this time."
            }
            203 {
                $partitionNumber = $messageArguments[0]
                $diskNumber = $messageArguments[1]
                "ERROR: The partition number #$partitionNumber is invalid for the disk #$diskNumber."
            }
            204 { "ERROR: The disk device was not found." }
            205 {
                $driveLetter = $messageArguments[0]
                "ABORT: The source partition did not release the drive letter $driveLetter."
            }
            206 {
                $driveLetter = $messageArguments[0]
                "ABORT: The drive letter $driveLetter was not assigned to the target partition."
            }
            207 { "ABORT: Modifying the C partition is not allowed." }
            208 {
                $driveLetter = $messageArguments[0]
                "ERROR: Failed to reassign the drive letter $driveLetter to the source partition."
            }
            209 {
                $driveLetter = $messageArguments[0]
                "ERROR: The partition using the drive letter $driveLetter was not found."
            }
            210 { "ERROR: The option specifier argument is missing." }
            211 { "ERROR: The disk number argument must have no leading 0." }
            212 {
                $invalidDiskNumber = $messageArguments[0]
                "ERROR: `"$invalidDiskNumber`" is not a valid disk number."
            }
            213 {
                $invalidDriveLetter = $messageArguments[0]
                "ERROR: `"$invalidDriveLetter`" is not a valid drive letter."
            }
            214 { "ERROR: Too few arguments." }
        }
    }
    
    function getPartitionName {
        return ('"Disk #{0}, Partition #{1}"' -f $args[0].DiskNumber,$args[0].PartitionNumber)
    }
    
    function help {
        (Get-Content $script:PSScriptRoot\lib\help.txt -Raw) -replace '%commandName%',[IO.Path]::GetFileNameWithoutExtension($CommandPath)
        exit 1
    }

    function log {
        @(
            Get-Date -Format '[MM/dd/yyyy HH:mm:ss]'
            "[$PID]"
            $args -join ' '
        ) -join ' ' |
        Out-File $Env:TEMP\dp-assign-drive-letter.log -Encoding utf8 -Append
    }

    function setPartition {
        $assigneePartition = $args[0]
        $driveLetter = $args[1]
        $assigneePartition | Set-Partition -NewDriveLetter $driveLetter -ErrorAction Stop
        echoSuccess 001 $driveLetter
    }
} -ArgumentList $args |
Receive-Job -Wait -AutoRemoveJob