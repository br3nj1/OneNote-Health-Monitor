# OneNote Configuration and Backup Monitor

`Get-OneNoteConfiguration.ps1` is a read-only diagnostic script for Microsoft OneNote desktop on Windows. It inventories OneNote's backup, cache, notebook-path, registry, and process information and reports whether the newest local `.one` backup exceeds a configurable age threshold.

The script is designed for Windows PowerShell 5.1 and can be run manually or through Windows Task Scheduler.

> [!IMPORTANT]
> Backup freshness is not proof of successful cloud synchronization. A recent local backup can exist while the OneNote Online copy is stale, and a stale backup does not by itself prove cloud synchronization has failed.

## Features

- Reads the OneNote `Options\Save` and `Options\Paths` registry keys.
- Reports explicitly configured settings separately from calculated defaults.
- Detects the redirected Windows Documents folder.
- Detects OneDrive roots without assuming that OneDrive is installed on `C:`.
- Asks about additional OneDrive, notebook, or backup locations automatically during an interactive run.
- Accepts additional locations by parameter for unattended operation.
- Resolves the relative `UnfiledNotesSection`/Quick Notes setting.
- Identifies the effective local backup and cache paths.
- Counts local `.one` backup files.
- Finds the newest backup and calculates its age.
- Flags the backup as stale when it exceeds a configurable threshold.
- Produces an actionable summary of warnings and errors.
- Provides evidence, remediation steps, and official Microsoft guidance for each finding.
- Lists running `ONENOTE.EXE` and `ONENOTEM.EXE` processes.
- Writes a persistent text report.
- Optionally opens the report in Notepad for an interactive run.

## Safety

The script does not:

- Start a OneNote backup.
- Force OneNote synchronization.
- Open or modify `.one` files.
- Delete, rename, merge, or write to the OneNote cache.
- Change OneNote registry settings.
- Close or restart OneNote.

This is important during data recovery because an existing backup set may be the newest recoverable copy. Preserve that directory before starting a manual backup, resetting OneNote, clearing its cache, signing out, or closing a notebook containing unsynchronized work.

## Requirements

- Windows 10 or Windows 11
- Microsoft OneNote desktop/Microsoft 365 OneNote
- Windows PowerShell 5.1 or later
- Permission to read the current user's registry and OneNote directories
- Write permission to the selected report directory

The default report directory is under `C:\ProgramData`; an initial elevated run may be necessary if the directory does not already exist and the current account cannot create it.

## Installation

1. Download `Get-OneNoteConfiguration.ps1`.
2. Create a scripts directory if needed:

   ```powershell
   New-Item -ItemType Directory -Path 'C:\Scripts' -Force
   ```

3. Copy the script into `C:\Scripts`.
4. If Windows marked the downloaded script as originating from the Internet, review it and then unblock it:

   ```powershell
   Unblock-File -LiteralPath 'C:\Scripts\Get-OneNoteConfiguration.ps1'
   ```

## Usage

### Interactive inspection

Run the script and open the finished report in Notepad:

```powershell
& 'C:\Scripts\Get-OneNoteConfiguration.ps1' -Interactive
```

### Built-in storage-location question

No discovery parameter is required. In an interactive console, the script begins by showing the detected Windows Documents folder and OneDrive roots:

```powershell
& 'C:\Scripts\Get-OneNoteConfiguration.ps1' -Interactive
```

The script first displays the Windows Documents folder and OneDrive roots it detected. It then asks:

> Are your OneDrive folder, local OneNote notebooks, and OneNote backup folders all stored within the locations shown above? [Y/N]

If the answer is no, it asks:

> Enter additional OneDrive roots or OneNote data folders, separated by semicolons (example: `E:\OneDrive; D:\OneNote Backups`)

This wording distinguishes the OneNote application installation from the user's notebook, backup, and OneDrive data locations.

### Supply nondefault locations without prompting

For a remapped OneDrive folder:

```powershell
& 'C:\Scripts\Get-OneNoteConfiguration.ps1' `
    -AdditionalStoragePath 'E:\OneDrive' `
    -Interactive
```

For several locations:

```powershell
& 'C:\Scripts\Get-OneNoteConfiguration.ps1' `
    -AdditionalStoragePath 'E:\OneDrive','D:\OneNote Backups'
```

### Noninteractive inspection

Suitable for Task Scheduler:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
    -File "C:\Scripts\Get-OneNoteConfiguration.ps1" `
    -NonInteractive
```

`-ExecutionPolicy Bypass` applies only to that PowerShell process. It does not change the computer's persistent execution policy.

### Change the stale-backup threshold

The default threshold is 36 hours:

```powershell
& 'C:\Scripts\Get-OneNoteConfiguration.ps1' `
    -MaximumBackupAgeHours 48 `
    -Interactive
```

Set the threshold according to the backup interval configured in OneNote. For example, a weekly backup schedule requires a substantially longer threshold than a daily schedule.

### Change the report directory

```powershell
& 'C:\Scripts\Get-OneNoteConfiguration.ps1' `
    -ReportDirectory 'D:\Monitoring\OneNote'
```

## Parameters

| Parameter | Default | Description |
|---|---:|---|
| `OneNoteVersion` | `16.0` | Office/OneNote registry and local-data version. |
| `MaximumBackupAgeHours` | `36` | Age at which the newest `.one` backup is classified as stale. |
| `ReportDirectory` | `C:\ProgramData\OneNote-Monitor` | Directory containing the text report. |
| `AdditionalStoragePath` | Empty | One or more nondefault OneDrive roots, local notebook directories, or backup directories. |
| `NonInteractive` | Disabled | Suppresses all location questions. Use for Task Scheduler, remote execution, or other automation. |
| `Interactive` | Disabled | Opens the completed report in Notepad when an interactive desktop session is available. |

## Report location

By default, each run overwrites:

```text
C:\ProgramData\OneNote-Monitor\OneNote-Configuration.txt
```

This provides a current-state report rather than historical records. If historical reporting is required, modify the filename to contain a timestamp or copy the report after each run.

## Understanding the output

### Registry configuration

The script examines:

```text
HKCU\Software\Microsoft\Office\16.0\OneNote\Options\Save
HKCU\Software\Microsoft\Office\16.0\OneNote\Options\Paths
```

A value reported as `<not explicitly configured>` does not necessarily mean the feature is disabled. OneNote may be using an internal or application default rather than a value explicitly stored in that registry location.

### Calculated defaults

For OneNote version `16.0`, the expected local paths normally include:

```text
%LOCALAPPDATA%\Microsoft\OneNote\16.0\Backup
%LOCALAPPDATA%\Microsoft\OneNote\16.0\cache
```

These are reported as calculated defaults. The script also tests whether they currently exist.

### OneDrive notebooks

Cloud-hosted OneNote notebooks commonly appear in the synchronized OneDrive folder as Internet shortcuts rather than ordinary `.one` section files. Therefore, finding `.url` files under a path such as the following is expected:

```text
OneDrive\Documents\OneNote Notebooks
```

The OneDrive desktop client's status does not independently prove that OneNote's internal notebook synchronization is healthy.

The script reads the standard OneDrive environment variables and does not contain a hard-coded drive letter. If OneDrive was redirected or remapped and Windows does not expose the correct root through those variables, answer the built-in question or use `-AdditionalStoragePath`.

### Quick Notes

OneNote may store Quick Notes as a relative registry value, for example:

```text
OneNote Notebooks\Quick Notes.one
```

The script resolves that value against the current Windows Documents location. If the notebook is cloud-hosted, the resulting local `.one` path may not exist even though the registry setting is valid.

### Backup states

| State | Meaning |
|---|---|
| `Current` | The newest `.one` backup is within the configured age threshold. |
| `Stale` | The newest `.one` backup is older than the configured threshold. |
| `NoFiles` | The backup directory exists but no `.one` files were found. |
| `DirectoryMissing` | The effective backup directory was not found. |
| `Unknown` | The script could not determine a more specific state. |

A large number of `.one` files can represent multiple retained versions of the same sections; it does not necessarily represent that many unique notebook sections.

## Actionable findings and remediation

The final summary reports the backup state and the number of detected problems. When a warning or error exists, the script prints:

- Severity
- Stable finding code
- Plain-language problem description
- Evidence gathered from the computer
- Recommended remediation
- An official Microsoft reference

Example:

```text
========== Summary ==========
Backup state:   Stale
Problems found: 1

Detected warnings and errors:

Severity Code         Problem
-------- ----         -------
Warning  BACKUP_STALE The newest local OneNote backup is older than the configured threshold.

========== Recommended Actions ==========

[WARNING] BACKUP_STALE
Problem:     The newest local OneNote backup is older than the configured threshold.
Evidence:    Newest backup: ...; age: 192.2 hours; threshold: 36 hours.
Remediation: Preserve the existing backup directory, verify OneNote's configured
             backup interval, test a manual backup only after preserving the
             recovery copy, and separately validate cloud synchronization.
Microsoft:   https://support.microsoft.com/...
```

Current finding codes include:

| Code | Severity | Condition |
|---|---|---|
| `BACKUP_STALE` | Warning | The newest `.one` backup exceeds the configured age threshold. |
| `BACKUP_FILES_NOT_FOUND` | Error | The backup directory exists but contains no `.one` files. |
| `BACKUP_DIRECTORY_NOT_FOUND` | Error | The effective backup directory does not exist. |
| `CONFIGURED_BACKUP_PATH_NOT_FOUND` | Warning | An explicit registry-configured backup location is unavailable. |
| `CONFIGURED_CACHE_PATH_NOT_FOUND` | Warning | An explicit registry-configured cache location is unavailable. |
| `SUPPLIED_PATH_NOT_FOUND` | Warning | A location supplied interactively or by parameter is unavailable. |
| `REGISTRY_KEYS_NOT_FOUND` | Warning | Expected OneNote option keys were not found for the selected user/version. |

`BACKUP_STALE` does not mean cloud synchronization definitely failed. It means the local backup is older than the policy selected with `MaximumBackupAgeHours`. The remediation therefore checks local backup health and cloud synchronization separately.

Official Microsoft references used by the script:

- [Back up notes in OneNote for Windows](https://support.microsoft.com/en-us/office/back-up-notes-f58b34b0-611d-435e-87fa-7942a1767af4)
- [Fix issues when you cannot sync OneNote](https://support.microsoft.com/en-us/office/fix-issues-when-you-can-t-sync-onenote-299495ef-66d1-448f-90c1-b785a6968d45)

These OneNote end-user procedures are maintained on Microsoft Support. Microsoft Learn does not currently provide an equivalent OneNote desktop backup-and-recovery procedure, so the script links to the directly applicable official support articles.

## Common problems reference

Use this table to interpret script results and common operational failures. Preserve local backups and unsynchronized notebook content before performing repairs, signing out, resetting OneNote, or clearing its cache.

| Symptom or message | What it usually means | Recommended response | Official Microsoft reference |
|---|---|---|---|
| `BACKUP_STALE` | The newest local `.one` backup exceeds `MaximumBackupAgeHours`. This does not by itself prove cloud sync failure. | Copy the entire existing backup directory to a separate safe location. Check **File > Options > Save & Backup**, confirm the intended interval, and test a manual backup only after preserving the current recovery set. | [Back up notes in OneNote](https://support.microsoft.com/en-us/office/back-up-notes-f58b34b0-611d-435e-87fa-7942a1767af4) |
| `BACKUP_FILES_NOT_FOUND` | The selected backup directory exists but contains no `.one` section backups. | Confirm the correct Windows user and backup directory, and check whether notebook backups are enabled. Preserve the OneNote cache and any other computer's backups before attempting repair. | [Back up notes in OneNote](https://support.microsoft.com/en-us/office/back-up-notes-f58b34b0-611d-435e-87fa-7942a1767af4) |
| `BACKUP_DIRECTORY_NOT_FOUND` | The effective backup path is missing, disconnected, or no longer valid. | Check for a remapped, removable, encrypted, or unavailable drive. Correct the path through OneNote rather than manually redirecting cache files. | [Back up notes in OneNote](https://support.microsoft.com/en-us/office/back-up-notes-f58b34b0-611d-435e-87fa-7942a1767af4) |
| OneNote reports **Sync stopped**, **read-only**, or a broken notebook | OneNote has stopped normal synchronization to protect a notebook it considers damaged. | Do not force synchronization or clear the cache. Preserve backups, create a new notebook, and copy content incrementally while confirming it appears in OneNote for the web. | [Fix OneNote sync problems](https://support.microsoft.com/en-us/office/fix-issues-when-you-can-t-sync-onenote-299495ef-66d1-448f-90c1-b785a6968d45) |
| OneNote for the web is older than the desktop copy | Recent work may exist only in the desktop cache or local backups. | Keep the notebook open, preserve the backup directory, inspect another device while offline, and compare page contents before replacing anything. | [Fix OneNote sync problems](https://support.microsoft.com/en-us/office/fix-issues-when-you-can-t-sync-onenote-299495ef-66d1-448f-90c1-b785a6968d45) |
| `CONFIGURED_BACKUP_PATH_NOT_FOUND` | An explicit OneNote registry setting points to an unavailable location. | Reconnect the referenced drive or correct the path under **File > Options > Save & Backup**. Test only after preserving existing recovery copies. | [Back up notes in OneNote](https://support.microsoft.com/en-us/office/back-up-notes-f58b34b0-611d-435e-87fa-7942a1767af4) |
| `CONFIGURED_CACHE_PATH_NOT_FOUND` | A configured cache location is unavailable or the configuration is stale. | Do not fabricate, merge, or copy files into the cache. Preserve backups and troubleshoot OneNote before changing the cache configuration. | [Fix OneNote sync problems](https://support.microsoft.com/en-us/office/fix-issues-when-you-can-t-sync-onenote-299495ef-66d1-448f-90c1-b785a6968d45) |
| `SUPPLIED_PATH_NOT_FOUND` | A path entered by the user or supplied to `AdditionalStoragePath` cannot be accessed. | Check the spelling, drive letter, BitLocker state, network mapping, and whether the task account can access that location. | [Microsoft Learn: PowerShell FileSystem provider](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_filesystem_provider) |
| `REGISTRY_KEYS_NOT_FOUND` | The selected OneNote version is wrong, OneNote desktop has not initialized its settings, or the script is running as a different user. | Run the script as the OneNote user, confirm the installed Office generation, and inspect the expected `HKCU` keys without changing them. | [Microsoft Learn: PowerShell Registry provider](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_registry_provider) |
| Script execution is blocked | PowerShell execution policy or a downloaded-file security mark may prevent execution. | Review the script first. Query the effective policies, and unblock only the reviewed file. Avoid weakening the computer-wide policy unnecessarily. | [Microsoft Learn: about Execution Policies](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies), [Unblock-File](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/unblock-file) |
| A Scheduled Task waits indefinitely | The task was allowed to reach `Read-Host` in a noninteractive execution mode. | Add `-NonInteractive` to the task action. Use `AdditionalStoragePath` to supply known locations without prompting. | [Microsoft Learn: ScheduledTasks module](https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/) |
| `-Interactive` does not open Notepad from Task Scheduler | Tasks configured to run whether or not the user is logged on do not run in the interactive desktop session. | Treat the report file as the scheduled output. Use **Run only when user is logged on** only when a visible window is intentionally required. | [Microsoft Learn: Task Scheduler schema](https://learn.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-schema) |
| Event Viewer contains Restart Manager Event ID 10010 for OneNote | Windows Restart Manager could not restart the OneNote process under the initiating security context. It is not, by itself, a OneNote sync-failure event. | Correlate the timestamp with Office Click-to-Run, MSI, Windows Update, and application events. Do not classify it as proof of notebook corruption or failed cloud synchronization. | [Microsoft Learn: Restart Manager](https://learn.microsoft.com/en-us/windows/win32/rstmgr/restart-manager-portal), [Get-WinEvent](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-winevent) |
| OneDrive contains `.url` shortcuts instead of `.one` files | Cloud-hosted OneNote notebooks are represented locally as links; OneDrive does not expose the notebook as an ordinary folder of synchronized `.one` sections. | Use OneNote's backup directory and OneNote for the web when validating recoverability and cloud freshness. Do not infer notebook health from the shortcut timestamp. | [Fix OneNote sync problems](https://support.microsoft.com/en-us/office/fix-issues-when-you-can-t-sync-onenote-299495ef-66d1-448f-90c1-b785a6968d45) |

### Microsoft Learn troubleshooting resources

These Microsoft Learn references cover the Windows and PowerShell mechanisms used by this project:

- [PowerShell FileSystem provider](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_filesystem_provider) — path discovery and filesystem access.
- [PowerShell Registry provider](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_registry_provider) — reading the current user's OneNote settings.
- [PowerShell execution policies](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies) — diagnosing blocked script execution.
- [`Unblock-File`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/unblock-file) — removing the downloaded-file security mark after review.
- [`Get-WinEvent`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.diagnostics/get-winevent) — querying Windows event logs during correlation.
- [Restart Manager](https://learn.microsoft.com/en-us/windows/win32/rstmgr/restart-manager-portal) — understanding Restart Manager behavior and why its events are not OneNote sync telemetry.
- [ScheduledTasks PowerShell module](https://learn.microsoft.com/en-us/powershell/module/scheduledtasks/) — creating and inspecting scheduled monitoring tasks.
- [Task Scheduler schema](https://learn.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-schema) — technical Task Scheduler definitions and behavior.

For notebook-level troubleshooting, use the OneNote-specific Microsoft Support procedures linked in the table. Microsoft Learn's Windows and PowerShell documentation supplements those procedures; it does not replace them.

## Task Scheduler configuration

Suggested settings:

### General

- Use the same Windows account that normally runs OneNote. OneNote settings are stored under `HKCU`, so another account—including `SYSTEM`—will inspect a different user profile.
- Use **Run only when user is logged on** if you intend to use `-Interactive`.
- Use **Run whether user is logged on or not** for silent monitoring, and omit `-Interactive`.
- Add `-NonInteractive` to every unattended task so it can never wait for console input.
- Supply known nondefault paths with `-AdditionalStoragePath`.

### Trigger

Run once or twice daily, preferably after the expected OneNote backup window.

### Action

Program/script:

```text
powershell.exe
```

Arguments:

```text
-NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\Get-OneNoteConfiguration.ps1" -NonInteractive -MaximumBackupAgeHours 36 -AdditionalStoragePath "E:\OneDrive"
```

Start in:

```text
C:\Scripts
```

### Conditions and settings

- Enable **Start the task only if the computer is on AC power** only if missing laptop checks while on battery is acceptable.
- Enable **Run task as soon as possible after a scheduled start is missed**.
- Set a reasonable execution limit, such as five minutes.
- Do not run multiple instances concurrently.

## Important monitoring limitations

This script monitors local evidence. It cannot reliably determine whether every page has successfully synchronized to OneNote Online because OneNote desktop does not expose a documented, dependable Windows Event Log event for successful notebook synchronization.

The following conditions do not prove successful cloud synchronization:

- `ONENOTE.EXE` is running.
- OneDrive reports that files are synchronized.
- The notebook's `.url` shortcut has a recent timestamp.
- A recent local OneNote backup exists.
- No OneNote error appears in the Windows Application log.

For high-confidence validation, compare recently modified pages with OneNote for the web. During recovery, copy content into a new notebook incrementally and confirm each recovered section appears online before retiring the damaged notebook.

## Troubleshooting

### The report does not open in Notepad

Confirm that the script was run with `-Interactive` and that it is running in the logged-on user's interactive session. Windows does not display applications launched from a Scheduled Task running in a noninteractive session.

### Registry settings are absent

This commonly means OneNote is using defaults. Verify the effective settings inside OneNote:

```text
File > Options > Save & Backup
```

### Backup is reported as stale

Check the backup interval in OneNote before treating the result as an incident. A 36-hour threshold is appropriate for an expected daily backup but inappropriate for an intentionally weekly schedule.

During an active recovery, copy the entire existing backup directory to a separate protected location before selecting **Back Up All Notebooks Now**. A new backup may update or rotate files in the existing backup set.

### Quick Notes reports `Exists = False`

This can be normal for a cloud-hosted notebook represented locally by an Internet shortcut. It can also indicate that the relative Quick Notes setting resolves to an outdated location. Inspect the configured notebook through OneNote rather than creating or moving `.one` files manually.

## Security considerations

- Run the task with the least privilege necessary.
- Use the normal OneNote user's account so `HKCU` resolves correctly.
- Restrict modification rights on the script and report directory if alerts or automation will trust their contents.
- Do not store notification API tokens directly in a broadly readable script.
- Do not configure the monitor to repair, delete, or rewrite OneNote cache files automatically.
- Treat notebook names and paths in the report as potentially sensitive information.

## Exit behavior

The current script reports status in its text output but does not assign distinct process exit codes for `Current`, `Stale`, `NoFiles`, or `DirectoryMissing`. Notification or remediation logic should therefore consume the reported state or be added explicitly in a future monitoring version.

## Scope

This utility is intended as a diagnostic and monitoring aid. It is not a replacement for OneNote's supported backup/recovery workflow, an independent cloud backup, or verification in OneNote for the web.
