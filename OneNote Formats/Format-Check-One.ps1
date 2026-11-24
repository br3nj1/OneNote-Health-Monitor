# ============================================================
# OneNote List .One Format
# Windows PowerShell 5.1
# 
# Example Formats: OneNote 2007, OneNote 2010+, Unknown/Legacy
# ============================================================

# ============================================================
# CONFIGURATION

$RootPath = "V:\_OneNote Backup\Final Copy - Copy\Azure\"

Get-ChildItem -Path $RootPath -Filter "*.one" -Recurse -File |
ForEach-Object {

    $File = $_

    try {
        $Stream = [System.IO.File]::OpenRead($File.FullName)
        $Reader = New-Object System.IO.BinaryReader($Stream)

        try {
            $FileType = New-Object System.Guid (,$Reader.ReadBytes(16))

            $Stream.Seek(0x40, 'Begin') | Out-Null
            $Version = $Reader.ReadUInt32()

            $Format = if (
                $FileType -eq [guid]"7B5C52E4-D88C-4DA7-AEB1-5378D02996D3" -and
                $Version -eq 42
            ) {
                "OneNote 2010+"
            }
            else {
                "Unknown / Legacy"
            }

            [PSCustomObject]@{
                FileName      = $File.Name
                FormatVersion = $Version
                Format        = $Format
                SizeMB        = [math]::Round($File.Length / 1MB, 2)
                FullPath      = $File.FullName
            }
        }
        finally {
            $Reader.Close()
        }
    }
    catch {
        Write-Warning "Unable to read $($File.FullName): $_"
    }
} | Format-Table -AutoSize
