#requires -Version 5.1

<#
.SYNOPSIS
    Produces a read-only inventory of Microsoft OneNote desktop backup,
    cache, notebook-path, registry, process, and backup-freshness information.

.DESCRIPTION
    Compatible with Windows PowerShell 5.1. The script does not modify OneNote,
    its cache, its backup files, or its registry settings.

    A text report is written to C:\ProgramData\OneNote-Monitor by default.
    Use -Interactive to open the completed report in Notepad. Do not use
    -Interactive from a Scheduled Task configured to run when the user is not
    logged on.

    In an interactive console, the script begins by showing the detected
    Documents and OneDrive locations and asks whether OneNote data exists
    anywhere else. Use -NonInteractive for Task Scheduler or automation. Pass
    known nondefault locations with -AdditionalStoragePath.

.EXAMPLE
    .\Get-OneNoteConfiguration.ps1 -Interactive

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\Get-OneNoteConfiguration.ps1"

.EXAMPLE
    .\Get-OneNoteConfiguration.ps1 -AdditionalStoragePath 'E:\OneDrive'

.EXAMPLE
    .\Get-OneNoteConfiguration.ps1 -NonInteractive -AdditionalStoragePath 'E:\OneDrive'
#>

[CmdletBinding()]
param(
    [ValidatePattern('^\d+\.\d+$')]
    [string]$OneNoteVersion = '16.0',

    [ValidateRange(1, 8760)]
    [int]$MaximumBackupAgeHours = 36,

    [string]$ReportDirectory = 'C:\ProgramData\OneNote-Monitor',

    [string[]]$AdditionalStoragePath = @(),

    [switch]$NonInteractive,

    [switch]$Interactive
)

$ErrorActionPreference = 'Continue'
$scriptStart = Get-Date
$transcriptStarted = $false
$script:findings = @()

$microsoftBackupGuidance =
    'https://support.microsoft.com/en-us/office/back-up-notes-f58b34b0-611d-435e-87fa-7942a1767af4'
$microsoftSyncGuidance =
    'https://support.microsoft.com/en-us/office/fix-issues-when-you-can-t-sync-onenote-299495ef-66d1-448f-90c1-b785a6968d45'

function Add-Finding {
    param(
        [ValidateSet('Warning', 'Error')]
        [string]$Severity,

        [Parameter(Mandatory = $true)]
        [string]$Code,

        [Parameter(Mandatory = $true)]
        [string]$Problem,

        [Parameter(Mandatory = $true)]
        [string]$Evidence,

        [Parameter(Mandatory = $true)]
        [string]$Remediation,

        [AllowNull()]
        [string]$Reference
    )

    $script:findings += [PSCustomObject]@{
        Severity    = $Severity
        Code        = $Code
        Problem     = $Problem
        Evidence    = $Evidence
        Remediation = $Remediation
        Reference   = $Reference
    }
}

function Expand-RegistryPath {
    param(
        [AllowNull()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    [Environment]::ExpandEnvironmentVariables($Path)
}

function New-PathResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Description,

        [AllowNull()]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    $expandedPath = Expand-RegistryPath -Path $Path
    $exists = $false

    if (-not [string]::IsNullOrWhiteSpace($expandedPath)) {
        $exists = Test-Path -LiteralPath $expandedPath
    }

    [PSCustomObject]@{
        Description = $Description
        Source      = $Source
        Exists      = $exists
        Path        = $expandedPath
    }
}

function Get-FirstSettingValue {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Settings,

        [Parameter(Mandatory = $true)]
        [string[]]$Names
    )

    foreach ($name in $Names) {
        if ($Settings.ContainsKey($name)) {
            $candidate = $Settings[$name]

            if ($null -ne $candidate -and
                -not [string]::IsNullOrWhiteSpace([string]$candidate)) {
                return $candidate
            }
        }
    }

    return $null
}

try {
    if (-not (Test-Path -LiteralPath $ReportDirectory)) {
        New-Item -ItemType Directory -Path $ReportDirectory -Force |
            Out-Null
    }

    $reportPath = Join-Path $ReportDirectory 'OneNote-Configuration.txt'
    Start-Transcript -LiteralPath $reportPath -Force | Out-Null
    $transcriptStarted = $true

    $oneNoteRoot = Join-Path $env:LOCALAPPDATA "Microsoft\OneNote\$OneNoteVersion"
    $registryPaths = @(
        "HKCU:\Software\Microsoft\Office\$OneNoteVersion\OneNote\Options\Save",
        "HKCU:\Software\Microsoft\Office\$OneNoteVersion\OneNote\Options\Paths"
    )

    $userShellFoldersKey =
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'

    $documentsPath = $null

    if (Test-Path -LiteralPath $userShellFoldersKey) {
        $documentsRaw = Get-ItemPropertyValue `
            -LiteralPath $userShellFoldersKey `
            -Name Personal `
            -ErrorAction SilentlyContinue

        $documentsPath = Expand-RegistryPath -Path $documentsRaw
    }

    if ([string]::IsNullOrWhiteSpace($documentsPath)) {
        $documentsPath = [Environment]::GetFolderPath('MyDocuments')
    }

    $defaultDocumentsNotebookPath =
        Join-Path $documentsPath 'OneNote Notebooks'

    # Detect OneDrive roots without assuming that OneDrive is on C:.
    $oneDriveRoots = @(
        $env:OneDrive,
        $env:OneDriveConsumer,
        $env:OneDriveCommercial
    ) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique

    $additionalPaths = @(
        $AdditionalStoragePath |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )

    # The location confirmation is the first interactive question. Scheduled
    # or automated runs must use -NonInteractive to guarantee no prompt.
    if (-not $NonInteractive -and [Environment]::UserInteractive) {
        Write-Host ''
        Write-Host '========== Storage Location Check ==========' -ForegroundColor Cyan
        Write-Host "Detected Windows Documents folder: $documentsPath"

        if ($oneDriveRoots.Count -gt 0) {
            Write-Host 'Detected OneDrive root(s):'
            $oneDriveRoots | ForEach-Object { Write-Host "  $_" }
        }
        else {
            Write-Host 'Detected OneDrive root(s): none'
        }

        if ($additionalPaths.Count -gt 0) {
            Write-Host 'Additional location(s) supplied on the command line:'
            $additionalPaths | ForEach-Object { Write-Host "  $_" }
        }

        $locationAnswer = Read-Host 'Are your OneDrive folder, local OneNote notebooks, and OneNote backup folders all stored within the locations shown above? [Y/N]'

        if ($locationAnswer -notmatch '^(?i:y|yes)$') {
            $enteredPaths = Read-Host 'Enter additional OneDrive roots or OneNote data folders, separated by semicolons (example: E:\OneDrive; D:\OneNote Backups)'

            if (-not [string]::IsNullOrWhiteSpace($enteredPaths)) {
                $additionalPaths += @(
                    $enteredPaths -split ';' |
                        ForEach-Object { $_.Trim().Trim('"') } |
                        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                )
            }
        }
    }

    $additionalPaths = @($additionalPaths | Select-Object -Unique)

    Write-Host ''
    Write-Host '========== OneNote Configuration ==========' -ForegroundColor Cyan
    Write-Host "Computer:        $env:COMPUTERNAME"
    Write-Host "Windows account: $env:USERDOMAIN\$env:USERNAME"
    Write-Host "OneNote version: $OneNoteVersion"
    Write-Host "Check time:      $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"

    $settings = @{}
    $registryInventory = @()
    $registryKeysFound = 0

    foreach ($registryPath in $registryPaths) {
        Write-Host ''
        Write-Host "Registry key: $registryPath" -ForegroundColor Yellow

        if (Test-Path -LiteralPath $registryPath) {
            $registryKeysFound++
            $key = Get-Item -LiteralPath $registryPath -ErrorAction Stop
            $valueNames = @($key.GetValueNames() | Sort-Object)

            if ($valueNames.Count -eq 0) {
                Write-Host 'The key exists but contains no values.' `
                    -ForegroundColor DarkYellow
            }

            foreach ($valueName in $valueNames) {
                $value = $key.GetValue(
                    $valueName,
                    $null,
                    [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames
                )

                $settings[$valueName] = $value

                $displayValue = if ($value -is [array]) {
                    $value -join '; '
                }
                else {
                    $value
                }

                $registryInventory += [PSCustomObject]@{
                    RegistryKey = $registryPath
                    Name        = $valueName
                    Data        = $displayValue
                }
            }

            $registryInventory |
                Where-Object RegistryKey -eq $registryPath |
                Select-Object Name, Data |
                Format-Table -AutoSize -Wrap
        }
        else {
            Write-Host 'Key not present; OneNote may be using defaults.' `
                -ForegroundColor DarkYellow
        }
    }

    if ($registryKeysFound -eq 0) {
        Add-Finding `
            -Severity 'Warning' `
            -Code 'REGISTRY_KEYS_NOT_FOUND' `
            -Problem 'No OneNote configuration registry keys were found for the selected version.' `
            -Evidence "Neither expected HKCU OneNote $OneNoteVersion options key exists for $env:USERDOMAIN\$env:USERNAME." `
            -Remediation 'Confirm that Microsoft OneNote desktop is installed, that the correct OneNoteVersion was selected, and that the script is running as the same Windows user who uses OneNote.' `
            -Reference $microsoftBackupGuidance
    }

    $defaultBackupPath = Join-Path $oneNoteRoot 'Backup'
    $defaultCachePath = Join-Path $oneNoteRoot 'cache'

    $configuredBackupPath = Get-FirstSettingValue `
        -Settings $settings `
        -Names @('BackupFolderPath', 'BackupPath')

    $configuredCachePath = Get-FirstSettingValue `
        -Settings $settings `
        -Names @('CachePath', 'CacheFolderPath')

    $configuredNotebookPath = Get-FirstSettingValue `
        -Settings $settings `
        -Names @('DefaultNotebookPath', 'NotebookPath')

    $quickNotesSetting = Get-FirstSettingValue `
        -Settings $settings `
        -Names @(
            'UnfiledNotesSection',
            'UnfiledNotesSectionPath',
            'UnfiledNotesPath'
        )

    $configuredQuickNotesPath = $null

    if ($quickNotesSetting) {
        $expandedQuickNotes = Expand-RegistryPath -Path $quickNotesSetting

        if ([System.IO.Path]::IsPathRooted($expandedQuickNotes)) {
            $configuredQuickNotesPath = $expandedQuickNotes
        }
        else {
            $configuredQuickNotesPath =
                Join-Path -Path $documentsPath -ChildPath $expandedQuickNotes
        }
    }

    $pathResults = @(
        New-PathResult `
            -Description 'Configured backup location' `
            -Path $configuredBackupPath `
            -Source 'OneNote registry'

        New-PathResult `
            -Description 'Expected default backup location' `
            -Path $defaultBackupPath `
            -Source 'Calculated default'

        New-PathResult `
            -Description 'Configured cache location' `
            -Path $configuredCachePath `
            -Source 'OneNote registry'

        New-PathResult `
            -Description 'Expected default cache location' `
            -Path $defaultCachePath `
            -Source 'Calculated default'

        New-PathResult `
            -Description 'Configured notebook location' `
            -Path $configuredNotebookPath `
            -Source 'OneNote registry'

        New-PathResult `
            -Description 'Windows Documents notebook location' `
            -Path $defaultDocumentsNotebookPath `
            -Source 'Calculated from Documents'

        New-PathResult `
            -Description 'Configured Quick Notes section' `
            -Path $configuredQuickNotesPath `
            -Source 'OneNote registry'
    )

    foreach ($oneDriveRoot in $oneDriveRoots) {
        $oneDriveNotebookPath =
            Join-Path $oneDriveRoot 'Documents\OneNote Notebooks'

        $pathResults += New-PathResult `
            -Description 'Detected OneDrive notebook location' `
            -Path $oneDriveNotebookPath `
            -Source 'Environment/known configuration'
    }

    foreach ($additionalPath in $additionalPaths) {
        $pathResults += New-PathResult `
            -Description 'User-supplied storage location' `
            -Path $additionalPath `
            -Source 'Parameter or interactive response'

        # If the supplied location is a OneDrive root such as E:\OneDrive,
        # also test the conventional notebook subdirectory beneath it.
        if ((Split-Path -Path $additionalPath -Leaf) -match '(?i)^OneDrive(?:\s|$|-)') {
            $derivedNotebookPath =
                Join-Path $additionalPath 'Documents\OneNote Notebooks'

            $pathResults += New-PathResult `
                -Description 'Notebook location derived from supplied OneDrive root' `
                -Path $derivedNotebookPath `
                -Source 'Calculated from user input'
        }

        if (-not (Test-Path -LiteralPath $additionalPath)) {
            Add-Finding `
                -Severity 'Warning' `
                -Code 'SUPPLIED_PATH_NOT_FOUND' `
                -Problem 'A user-supplied OneNote or OneDrive storage location was not found.' `
                -Evidence "Path not found: $additionalPath" `
                -Remediation 'Confirm the drive is connected and unlocked, then correct the path. If this is removable or network storage, make sure it is available when the scheduled task runs.' `
                -Reference $microsoftBackupGuidance
        }
    }

    if ($configuredBackupPath -and
        -not (Test-Path -LiteralPath (Expand-RegistryPath -Path $configuredBackupPath))) {
        Add-Finding `
            -Severity 'Warning' `
            -Code 'CONFIGURED_BACKUP_PATH_NOT_FOUND' `
            -Problem 'OneNote has an explicit backup path that does not currently exist.' `
            -Evidence "Configured backup path: $(Expand-RegistryPath -Path $configuredBackupPath)" `
            -Remediation 'In OneNote, open File > Options > Save & Backup and correct the backup folder. If the folder is on another drive, reconnect that drive before testing a backup.' `
            -Reference $microsoftBackupGuidance
    }

    if ($configuredCachePath -and
        -not (Test-Path -LiteralPath (Expand-RegistryPath -Path $configuredCachePath))) {
        Add-Finding `
            -Severity 'Warning' `
            -Code 'CONFIGURED_CACHE_PATH_NOT_FOUND' `
            -Problem 'OneNote has an explicit cache path that does not currently exist.' `
            -Evidence "Configured cache path: $(Expand-RegistryPath -Path $configuredCachePath)" `
            -Remediation 'Do not create, copy, or merge cache files manually. Preserve existing backups, then verify the OneNote installation and configured cache location before making changes.' `
            -Reference $microsoftSyncGuidance
    }

    Write-Host ''
    Write-Host '========== OneNote Paths ==========' -ForegroundColor Cyan
    $pathResults |
        Format-Table Description, Source, Exists, Path -AutoSize -Wrap

    Write-Host ''
    Write-Host '========== Backup Settings ==========' -ForegroundColor Cyan

    $backupSettingNames = @(
        'BackupInterval',
        'BackupCount',
        'BackupFolderPath',
        'BackupPath',
        'BackupSharePointNotebooks'
    )

    $backupSettingsOutput = foreach ($settingName in $backupSettingNames) {
        $value = if ($settings.ContainsKey($settingName)) {
            $settings[$settingName]
        }
        else {
            '<not explicitly configured>'
        }

        [PSCustomObject]@{
            Setting = $settingName
            Value   = $value
        }
    }

    $backupSettingsOutput | Format-Table -AutoSize

    $effectiveBackupPath = Expand-RegistryPath -Path $configuredBackupPath

    if ([string]::IsNullOrWhiteSpace($effectiveBackupPath)) {
        $effectiveBackupPath = $defaultBackupPath
    }

    Write-Host ''
    Write-Host '========== Backup Status ==========' -ForegroundColor Cyan
    Write-Host "Path examined: $effectiveBackupPath"
    Write-Host "Alert threshold: $MaximumBackupAgeHours hours"

    $backupState = 'Unknown'
    $newestBackup = $null
    $backupAgeHours = $null

    if (Test-Path -LiteralPath $effectiveBackupPath) {
        $backupFiles = @(
            Get-ChildItem -LiteralPath $effectiveBackupPath `
                -Filter '*.one' `
                -File `
                -Recurse `
                -ErrorAction SilentlyContinue
        )

        $newestBackup = $backupFiles |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        Write-Host "Section files: $($backupFiles.Count)"

        if ($newestBackup) {
            $backupAgeHours =
                [math]::Round(((Get-Date) - $newestBackup.LastWriteTime).TotalHours, 1)

            Write-Host "Newest file:   $($newestBackup.FullName)"
            Write-Host "Modified:      $($newestBackup.LastWriteTime)"
            Write-Host "Age:           $backupAgeHours hours"

            if ($backupAgeHours -gt $MaximumBackupAgeHours) {
                $backupState = 'Stale'
                Write-Warning "OneNote backup exceeds the configured $MaximumBackupAgeHours-hour threshold."

                Add-Finding `
                    -Severity 'Warning' `
                    -Code 'BACKUP_STALE' `
                    -Problem 'The newest local OneNote backup is older than the configured threshold.' `
                    -Evidence "Newest backup: $($newestBackup.FullName); modified: $($newestBackup.LastWriteTime); age: $backupAgeHours hours; threshold: $MaximumBackupAgeHours hours." `
                    -Remediation 'First copy the entire existing Backup directory to a separate safe location. Then verify the configured backup interval under File > Options > Save & Backup. After preserving the recovery copy, test Back Up All Notebooks Now and confirm that new .one files are produced. Separately check View Sync Status and compare important pages with OneNote for the web.' `
                    -Reference $microsoftBackupGuidance
            }
            else {
                $backupState = 'Current'
                Write-Host 'Backup freshness is within the configured threshold.' `
                    -ForegroundColor Green
            }
        }
        else {
            $backupState = 'NoFiles'
            Write-Warning 'The backup directory contains no .one files.'

            Add-Finding `
                -Severity 'Error' `
                -Code 'BACKUP_FILES_NOT_FOUND' `
                -Problem 'The effective OneNote backup directory contains no .one section files.' `
                -Evidence "No .one files were found under: $effectiveBackupPath" `
                -Remediation 'Verify OneNote backup settings and whether cloud-notebook backups are enabled. Preserve any other recovery sources before testing Back Up All Notebooks Now.' `
                -Reference $microsoftBackupGuidance
        }
    }
    else {
        $backupState = 'DirectoryMissing'
        Write-Warning "The backup directory does not exist: $effectiveBackupPath"

        Add-Finding `
            -Severity 'Error' `
            -Code 'BACKUP_DIRECTORY_NOT_FOUND' `
            -Problem 'The effective OneNote backup directory does not exist.' `
            -Evidence "Directory not found: $effectiveBackupPath" `
            -Remediation 'Open File > Options > Save & Backup and verify the backup-folder setting. If it points to another disk, reconnect the disk. Do not clear the OneNote cache while unsynchronized content may exist.' `
            -Reference $microsoftBackupGuidance
    }

    Write-Host ''
    Write-Host '========== Running Processes ==========' -ForegroundColor Cyan

    $oneNoteProcesses = @(
        Get-CimInstance Win32_Process `
            -Filter "Name='ONENOTE.EXE' OR Name='ONENOTEM.EXE'" `
            -ErrorAction SilentlyContinue
    )

    if ($oneNoteProcesses.Count -gt 0) {
        $oneNoteProcesses |
            Select-Object ProcessId, Name, ExecutablePath, CreationDate |
            Format-Table -AutoSize -Wrap
    }
    else {
        Write-Host 'No ONENOTE.EXE or ONENOTEM.EXE processes were detected.'
    }

    Write-Host ''
    Write-Host '========== Summary ==========' -ForegroundColor Cyan
    Write-Host "Backup state:   $backupState"
    Write-Host "Problems found: $($script:findings.Count)"
    Write-Host "Report path:    $reportPath"
    Write-Host "Elapsed time:   $([math]::Round(((Get-Date) - $scriptStart).TotalSeconds, 1)) seconds"

    if ($script:findings.Count -eq 0) {
        Write-Host ''
        Write-Host 'No monitored problems were detected.' -ForegroundColor Green
        Write-Host 'This does not prove that cloud synchronization succeeded. Periodically compare recent pages with OneNote for the web.'
    }
    else {
        Write-Host ''
        Write-Host 'Detected warnings and errors:' -ForegroundColor Yellow

        $script:findings |
            Select-Object Severity, Code, Problem |
            Format-Table -AutoSize -Wrap

        Write-Host '========== Recommended Actions ==========' -ForegroundColor Cyan

        foreach ($finding in $script:findings) {
            $findingColor = if ($finding.Severity -eq 'Error') {
                'Red'
            }
            else {
                'Yellow'
            }

            Write-Host ''
            Write-Host "[$($finding.Severity.ToUpper())] $($finding.Code)" `
                -ForegroundColor $findingColor
            Write-Host "Problem:     $($finding.Problem)"
            Write-Host "Evidence:    $($finding.Evidence)"
            Write-Host "Remediation: $($finding.Remediation)"

            if (-not [string]::IsNullOrWhiteSpace($finding.Reference)) {
                Write-Host "Microsoft:   $($finding.Reference)"
            }
        }
    }

    Write-Host ''
    Write-Host 'This inventory was read-only. No OneNote files, cache data, or registry settings were changed.'
}
catch {
    Write-Error "OneNote inventory failed: $($_.Exception.Message)"
}
finally {
    if ($transcriptStarted) {
        Stop-Transcript | Out-Null
    }
}

if ($Interactive -and [Environment]::UserInteractive -and $reportPath) {
    Start-Process -FilePath 'notepad.exe' `
        -ArgumentList ('"{0}"' -f $reportPath)
}
