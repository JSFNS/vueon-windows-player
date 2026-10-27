# VueOn Windows Player filesystem permissions.
# Apply directory ACEs to DIRECTORIES only and file ACEs to FILES only.
# v0.1.0 mistakenly used directory inheritance flags recursively on files.
#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-VueOnLocalPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Root,
          [Parameter(Mandatory)][string]$Path)
    $r = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    $p = [IO.Path]::GetFullPath($Path)
    if (-not ($p.Equals($r,[StringComparison]::OrdinalIgnoreCase) -or
        $p.StartsWith($r + '\',[StringComparison]::OrdinalIgnoreCase))) {
        throw ('Refusing to change permissions outside the VueOn directory: ' + $Path)
    }
    if (Test-Path -LiteralPath $Path) {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw ('Refusing to change a symbolic link or junction: ' + $Path)
        }
    }
}

function Invoke-VueOnAclCommand {
    param([Parameter(Mandatory)][string]$Path,
          [Parameter(Mandatory)][string[]]$Arguments)
    $output = & icacls.exe $Path @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ('icacls failed for ' + $Path + ': ' + ($output | Out-String))
    }
}

function Set-VueOnFolderAcl {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Root,
          [Parameter(Mandatory)][string]$Path,
          [switch]$LockDown)
    Assert-VueOnLocalPath -Root $Root -Path $Path
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw ('VueOn directory missing: ' + $Path)
    }
    # OI/CI are appropriate on a directory, and NO /T is used here.
    Invoke-VueOnAclCommand -Path $Path -Arguments @(
        '/grant:r',
        '*S-1-5-18:(OI)(CI)F',
        '*S-1-5-32-544:(OI)(CI)F',
        '*S-1-5-32-545:(OI)(CI)RX'
    )
    if ($LockDown) {
        Invoke-VueOnAclCommand -Path $Path -Arguments @('/inheritance:r')
    }
}

function Test-VueOnFileWritable {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $true }
    $stream = $null
    try {
        $stream = [IO.File]::Open(
            $Path, [IO.FileMode]::Open,
            [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite
        )
        return $true
    } catch {
        return $false
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
    }
}

function Repair-VueOnFileAcl {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Root,
          [Parameter(Mandatory)][string]$Path)
    Assert-VueOnLocalPath -Root $Root -Path $Path
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw ('VueOn file missing during ACL repair: ' + $Path)
    }

    # Recover a file left with an empty ACL by v0.1.0. Only administrator
    # accounts can claim ownership; the installer requires elevation.
    $output = & takeown.exe '/F' $Path '/A' 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ('Unable to take ownership of VueOn file: ' + ($output | Out-String))
    }

    # File-specific flags are crucial. Do not use (OI)(CI) on files.
    Invoke-VueOnAclCommand -Path $Path -Arguments @(
        '/grant:r', '*S-1-5-18:F', '*S-1-5-32-544:F', '*S-1-5-32-545:RX'
    )
    Invoke-VueOnAclCommand -Path $Path -Arguments @('/inheritance:r')

    if (-not (Test-VueOnFileWritable -Path $Path)) {
        $permissions = & icacls.exe $Path 2>&1 | Out-String
        throw ('VueOn file is still not writable after explicit permissions: ' +
            $Path + [Environment]::NewLine + $permissions)
    }
}

function Initialize-VueOnInstallationAcl {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Root)
    $null = New-Item -Path $Root -ItemType Directory -Force
    Assert-VueOnLocalPath -Root $Root -Path $Root
    Set-VueOnFolderAcl -Root $Root -Path $Root

    foreach ($name in @('Runtime','Branding','Modules','Maintenance')) {
        $directory = Join-Path $Root $name
        $null = New-Item -Path $directory -ItemType Directory -Force
        Set-VueOnFolderAcl -Root $Root -Path $directory
    }

    $checkDirectories = @($Root)
    foreach ($name in @('Runtime','Branding','Modules','Maintenance')) {
        $checkDirectories += (Join-Path $Root $name)
    }
    foreach ($directory in $checkDirectories) {
        # Temporary write test is deleted immediately.
        $probe = Join-Path $directory ('acl-probe-' + [guid]::NewGuid().ToString('N') + '.tmp')
        try {
            [IO.File]::WriteAllText($probe, 'VueOn permission preflight')
        } catch {
            throw ('Cannot write to VueOn directory ' + $directory + ': ' + $_.Exception.Message)
        } finally {
            if (Test-Path -LiteralPath $probe) {
                Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Protect-VueOnInstallationAcl {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Root)
    Assert-VueOnLocalPath -Root $Root -Path $Root
    # Explicitly secure each DIRECTORY, without touching regular files via /T.
    $directories = @($Root) + @(
        Get-ChildItem -LiteralPath $Root -Recurse -Directory -Force -ErrorAction Stop |
            Select-Object -ExpandProperty FullName
    )
    foreach ($directory in $directories) {
        Set-VueOnFolderAcl -Root $Root -Path $directory -LockDown
    }

    # Explicitly secure each FILE without (OI)(CI) inheritance flags.
    $files = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force -ErrorAction Stop)
    foreach ($file in $files) {
        Assert-VueOnLocalPath -Root $Root -Path $file.FullName
        if (-not (Test-VueOnFileWritable -Path $file.FullName)) {
            Repair-VueOnFileAcl -Root $Root -Path $file.FullName
        } else {
            Invoke-VueOnAclCommand -Path $file.FullName -Arguments @(
                '/grant:r', '*S-1-5-18:F', '*S-1-5-32-544:F', '*S-1-5-32-545:RX'
            )
            Invoke-VueOnAclCommand -Path $file.FullName -Arguments @('/inheritance:r')
        }
        if (-not (Test-VueOnFileWritable -Path $file.FullName)) {
            throw ('VueOn script would be inaccessible after ACL lockdown: ' + $file.FullName)
        }
    }
}

Export-ModuleMember -Function Initialize-VueOnInstallationAcl,
    Repair-VueOnFileAcl, Protect-VueOnInstallationAcl, Test-VueOnFileWritable
