# VueOn Windows Player Provisioner v0.1.6 (integrated autologon and branding)
# Intended for 64-bit Windows 11 Home/Pro using Windows PowerShell 5.1.
# Must be reviewed and tested on a spare PC before customer deployment.
#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$AuditOnly,
    [switch]$SkipAutoLogon,
    [switch]$ConfigureBios,
    [switch]$MigrateLegacyStartup
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:version = '0.1.6-preview'
$script:playerName = 'VueOnPlayer'
$script:newPlayerPassword = $null
$script:adminName = 'VueOnAdmin'
$script:installDir = Join-Path $env:ProgramData 'VueOnPlayer'
$script:report = [ordered]@{
    Version = $script:version
    TimestampUtc = (Get-Date).ToUniversalTime().ToString('o')
    Machine = $env:COMPUTERNAME
    Windows = $null
    Edge = $null
    AdminAccount = 'Unverified'
    PlayerAccount = 'Unverified'
    AutoLogon = 'Unverified'
    DesktopBranding = 'Unverified'
    LockScreenBranding = 'Unverified'
    AccountPicture = 'Unverified'
    StartupTask = 'Unverified'
    Pairing = 'Not checked (requires signed-in viewer and playback)'
    Power = 'Unverified'
    BIOS = $null
    PendingRestart = $false
    Notes = @('No Windows/firmware flashing and no modification of Microsoft Defender or Windows Update policies.')
}

function Say([string]$message) { Write-Host ('[VueOn] ' + $message) -ForegroundColor Cyan }
function Require-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run Install-VueOn.cmd as administrator.'
    }
}
function Read-NewPassword([string]$accountName) {
    Say ('Create a unique strong password for ' + $accountName + '. It will not be written to disk.')
    $first = Read-Host ('Enter password for ' + $accountName) -AsSecureString
    if (-not $first -or $first.Length -lt 12) {
        throw 'Passwords must contain at least 12 characters.'
    }
    return $first
}
function Account-InGroup([string]$accountName,[string]$groupSid) {
    $user = Get-LocalUser -Name $accountName -ErrorAction Stop
    $group = Get-LocalGroup -SID ([Security.Principal.SecurityIdentifier]::new($groupSid))
    $members = @(Get-LocalGroupMember -Group $group.Name -ErrorAction Stop)
    return (@($members | Where-Object { $_.SID -and $_.SID.Value -eq $user.SID.Value }).Count -gt 0)
}
function Ensure-LocalAccounts {
    $existingAdmin = Get-LocalUser -Name $script:adminName -ErrorAction SilentlyContinue
    if (-not $existingAdmin) {
        $pwd = Read-NewPassword $script:adminName
        New-LocalUser -Name $script:adminName -Password $pwd -Description 'VueOn device maintenance administrator' -PasswordNeverExpires | Out-Null
        $adminGroup = Get-LocalGroup -SID ([Security.Principal.SecurityIdentifier]::new('S-1-5-32-544'))
        Add-LocalGroupMember -Group $adminGroup.Name -Member $script:adminName
        $script:report.AdminAccount = 'Created (administrator)'
    } else {
        if (-not (Account-InGroup $script:adminName 'S-1-5-32-544')) {
            throw 'VueOnAdmin exists but is not an administrator. Correct the account manually.'
        }
        $script:report.AdminAccount = 'Existing (administrator)'
    }

    $existingPlayer = Get-LocalUser -Name $script:playerName -ErrorAction SilentlyContinue
    if (-not $existingPlayer) {
        $script:newPlayerPassword = Read-NewPassword $script:playerName
        New-LocalUser -Name $script:playerName -Password $script:newPlayerPassword -Description 'Restricted VueOn signage account' -PasswordNeverExpires | Out-Null
        $script:report.PlayerAccount = 'Created (standard user)'
    } else {
        $script:report.PlayerAccount = 'Existing (standard user)'
    }
    if (Account-InGroup $script:playerName 'S-1-5-32-544') {
        throw 'VueOnPlayer is an administrator. Make it a standard user before continuing.'
    }
}
function Test-Edge {
    foreach ($edge in @(
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe")) {
        if ($edge -and (Test-Path -LiteralPath $edge)) { return $edge }
    }
    return $null
}
function Copy-PlayerFiles {
    # v0.1.3: The v0.1.0 recursive icacls change left multiple regular
    # files with no usable ACEs. Recover them using explicit file permissions.
    $permissionsModule = Join-Path $PSScriptRoot 'Modules\VueOn.Permissions.psm1'
    if (-not (Test-Path -LiteralPath $permissionsModule -PathType Leaf)) {
        throw 'Required VueOn.Permissions.psm1 module was not found in installer package.'
    }
    Import-Module -Name $permissionsModule -Force -ErrorAction Stop
    Initialize-VueOnInstallationAcl -Root $script:installDir

    foreach ($item in @(
        'Runtime\Start-VueOn.ps1',
        'Modules\VueOn.Branding.psm1',
        'Modules\VueOn.Autologon.psm1',
        'Modules\VueOn.Bios.psm1',
        'Modules\VueOn.Permissions.psm1',
        'Modules\VueOn.Credentials.psm1',
        'Modules\VueOn.AutoSetup.psm1',
        'Maintenance\Enter-Maintenance.ps1',
        'Maintenance\Exit-Maintenance.ps1',
        'Maintenance\Get-Status.ps1',
        'Maintenance\Uninstall-VueOn.ps1'
    )) {
        $src = Join-Path $PSScriptRoot $item
        $dest = Join-Path $script:installDir $item
        if (-not (Test-Path -LiteralPath $src -PathType Leaf)) {
            throw ('Required deployment file missing: ' + $item)
        }
        try {
            if ((Test-Path -LiteralPath $dest -PathType Leaf) -and
                -not (Test-VueOnFileWritable -Path $dest)) {
                Say ('Repairing damaged VueOn ACL: ' + $item)
                Repair-VueOnFileAcl -Root $script:installDir -Path $dest
            }
            Copy-Item -LiteralPath $src -Destination $dest -Force -ErrorAction Stop
        } catch {
            $firstError = $_.Exception.Message
            # Try once more if an existing VueOn file is specifically blocked.
            if (($firstError -match '(?i)denied|unauthori[sz]ed|permission') -and
                (Test-Path -LiteralPath $dest -PathType Leaf)) {
                Repair-VueOnFileAcl -Root $script:installDir -Path $dest
                try {
                    Copy-Item -LiteralPath $src -Destination $dest -Force -ErrorAction Stop
                    continue
                } catch {
                    $firstError = 'Retry failed after explicit file ACL repair: ' + $_.Exception.Message
                }
            }
            $parentAcl = (& icacls.exe (Split-Path -Parent $dest) 2>&1 | Out-String)
            $targetAcl = if (Test-Path -LiteralPath $dest) {
                (& icacls.exe $dest 2>&1 | Out-String)
            } else { 'Target does not exist' }
            throw ('Could not copy ' + $item + ': ' + $firstError +
                [Environment]::NewLine + 'Parent ACL: ' + $parentAcl +
                [Environment]::NewLine + 'File ACL: ' + $targetAcl)
        }
    }

    # Create reusable VueOn-branded PNGs. Existing custom branded files are kept.
    # Windows Pro/Home can set the lock screen from Settings but cannot be forced
    # using the Enterprise-only local GPO setting.
    Import-Module (Join-Path $script:installDir 'Modules\VueOn.Branding.psm1') -Force -ErrorAction Stop
    foreach ($asset in @(
        @{ File = 'VueOn-Wallpaper.png'; Kind = 'Wallpaper' },
        @{ File = 'VueOn-LockScreen.png'; Kind = 'LockScreen' },
        @{ File = 'VueOn-Account.png'; Kind = 'Account' }
    )) {
        $targetImage = Join-Path (Join-Path $script:installDir 'Branding') $asset.File
        $customImage = Join-Path (Join-Path $PSScriptRoot 'Branding') $asset.File
        if ((Test-Path -LiteralPath $targetImage -PathType Leaf) -and
            -not (Test-VueOnFileWritable -Path $targetImage)) {
            Repair-VueOnFileAcl -Root $script:installDir -Path $targetImage
        }
        if (Test-Path -LiteralPath $customImage -PathType Leaf) {
            Copy-Item -LiteralPath $customImage -Destination $targetImage -Force -ErrorAction Stop
        } elseif (-not (Test-Path -LiteralPath $targetImage -PathType Leaf)) {
            New-VueOnBrandImage -Path $targetImage -Kind $asset.Kind
        }
    }
    $script:report.DesktopBranding = 'VueOn wallpaper staged. Applied when VueOnPlayer first signs in.'
    $script:report.AccountPicture = Join-Path $script:installDir 'Branding\VueOn-Account.png'
    try {
        $lockImage = Join-Path $script:installDir 'Branding\VueOn-LockScreen.png'
        $script:report.LockScreenBranding = Set-VueOnSupportedLockScreen -ImagePath $lockImage
    } catch {
        # Login background is optional. A policy restriction must not prevent
        # the player and Windows account from working.
        $script:report.LockScreenBranding = 'Image generated; Windows policy could not be set: ' + $_.Exception.Message
    }

    # Finish by protecting directories and files using the correct ACEs.
    Protect-VueOnInstallationAcl -Root $script:installDir
}
function Set-VueOnStartupTask {
    $exe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $runtime = Join-Path $script:installDir 'Runtime\Start-VueOn.ps1'
    $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f $runtime
    $account = '{0}\{1}' -f $env:COMPUTERNAME,$script:playerName
    $action = New-ScheduledTaskAction -Execute $exe -Argument $arguments
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $account
    $principal = New-ScheduledTaskPrincipal -UserId $account -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName 'VueOnPlayer-Start' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'VueOn branded signage viewer and five-second browser watchdog' -Force | Out-Null
    $script:report.StartupTask = 'Registered: VueOnPlayer-Start (interactive user, limited privileges)'
}
function Move-LegacyStartup {
    $user = Get-LocalUser -Name $script:playerName
    $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\{0}' -f $user.SID.Value
    $profileEntry = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
    if (-not $profileEntry) { return }
    $profile = [string]$profileEntry.ProfileImagePath
    if (-not $profile) { return }
    $path = Join-Path ([Environment]::ExpandEnvironmentVariables($profile)) 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup'
    if (-not (Test-Path -LiteralPath $path)) { return }
    $backup = Join-Path $script:installDir 'LegacyStartupBackup'
    $names = @('VueOn-Start*.lnk', 'VueOn Watchdog.lnk')
    foreach ($pattern in $names) {
        $items = @(Get-ChildItem -LiteralPath $path -Filter $pattern -File -ErrorAction SilentlyContinue)
        foreach ($item in $items) {
            New-Item -Path $backup -ItemType Directory -Force | Out-Null
            Move-Item -LiteralPath $item.FullName -Destination (Join-Path $backup $item.Name) -Force
            Say ('Backed up legacy startup shortcut: ' + $item.Name)
        }
    }
    if (Test-Path -LiteralPath $backup) { Protect-VueOnInstallationAcl -Root $script:installDir }
}
function Set-UnattendedPower {
    foreach ($setting in @('monitor-timeout-ac','standby-timeout-ac','hibernate-timeout-ac')) {
        & powercfg.exe /change $setting 0 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "powercfg failed to set $setting" }
    }
    $script:report.Power = 'AC screen/sleep/hibernate idle timeouts disabled (active power plan)'
}
function Enable-UnattendedLogin {
    # The user must explicitly choose auto login. Never silently store a secret
    # or use the unverified custom LSA setter from the early previews.
    if ($SkipAutoLogon) {
        $script:report.AutoLogon = 'Skipped by operator (-SkipAutoLogon)'
        return
    }

    $choice = Read-Host 'Set up automatic Windows sign-in now using the official Microsoft Autologon tool? (Y/N)'
    if ($choice -notmatch '^(?i:y|yes)$') {
        $script:report.AutoLogon = 'Deferred by operator'
        Say 'Auto-login deferred. You can sign in to .\VueOnPlayer manually.'
        return
    }

    Say 'Verify the VueOnPlayer Windows password before activating unattended sign-in.'
    $password = $script:newPlayerPassword
    if (-not $password) {
        $password = Read-Host 'Enter the EXISTING VueOnPlayer Windows password' -AsSecureString
    }
    try {
        Import-Module (Join-Path $script:installDir 'Modules\VueOn.AutoSetup.psm1') -Force -ErrorAction Stop
        $result = Invoke-VueOnAutoLogonWizard -UserName $script:playerName -ComputerName $env:COMPUTERNAME -Password $password
        $script:report.AutoLogon = $result
        if ($result -eq 'ConfiguredPendingReboot') {
            $script:report.PendingRestart = $true
            Say 'Microsoft Autologon enabled for VueOnPlayer. Validate the next reboot before deploying.'
        } else {
            Say ('Automatic login not enabled: ' + $result + '. Windows remains usable for manual sign-in.')
        }
    } catch {
        $script:report.AutoLogon = 'Not configured: ' + $_.Exception.Message
        Say 'Automatic login setup could not complete. VueOn installation remains available.'
        Say ('Detail: ' + $_.Exception.Message)
        $script:report.Notes += 'Use the Microsoft Autologon utility separately after confirming manual login.'
    }
}
function Write-Report {
    $script:report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $script:installDir 'deployment-report.json') -Encoding UTF8
}

try {
    if (-not [Environment]::Is64BitProcess) { throw 'Use 64-bit Windows PowerShell 5.1.' }
    $os = Get-CimInstance Win32_OperatingSystem
    if ([int]$os.BuildNumber -lt 22000 -or [int]$os.ProductType -ne 1) { throw 'Windows 11 client is required.' }
    $script:report.Windows = [string]$os.Caption
    $edge = Test-Edge
    if (-not $edge) { throw 'Microsoft Edge is required and was not found. Install Edge before provisioning.' }
    $script:report.Edge = $edge
    Import-Module (Join-Path $PSScriptRoot 'Modules\VueOn.Bios.psm1') -Force
    if ($AuditOnly) {
        $inventory = Invoke-VueOnPowerRecovery
        Write-Host ($script:report | ConvertTo-Json -Depth 4)
        Write-Host ($inventory | Format-List | Out-String)
        exit 0
    }
    Require-Admin
    Say ('Provisioner ' + $script:version + ' | ' + $os.Caption)
    Ensure-LocalAccounts
    Copy-PlayerFiles
    Set-UnattendedPower
    Set-VueOnStartupTask
    if ($MigrateLegacyStartup) { Move-LegacyStartup }
    if ($ConfigureBios) { Say 'Attempting supported AC power recovery configuration.' }
    $script:report.BIOS = Invoke-VueOnPowerRecovery -Apply:$ConfigureBios
    Say ('BIOS: ' + $script:report.BIOS.Message)
    Enable-UnattendedLogin
    $script:report.Notes += 'PC naming deliberately unchanged to avoid invalidating local-account scheduled tasks. Planned for installer v1.0.'
    Write-Report
    Say 'Installation complete. Review deployment-report.json under C:\ProgramData\VueOnPlayer.'
    if ($script:report.AutoLogon -eq 'ConfiguredPendingReboot') {
        Say 'Restart to test automatic VueOnPlayer login, then pair the screen.'
    } else {
        Say 'Restart, select Other user, then sign into .\VueOnPlayer manually with its password.'
        Say 'Automatic login can be configured later using the official Microsoft utility.'
    }
    Say 'VueOn brand artwork is in C:\ProgramData\VueOnPlayer\Branding.'
    Say 'Windows Pro/Home: choose the staged image in Settings > Personalization > Lock screen.'
    Say 'The account photo can be selected in Settings > Accounts > Your info.'
    if (-not $MigrateLegacyStartup) {
        Say 'If this is an upgrade of the manual prototype, use -MigrateLegacyStartup to avoid duplicate launch shortcuts.'
    }
    Say 'IMPORTANT: this is an unsigned preview; do not roll out to customers before on-device validation.'
    exit 0
} catch {
    Write-Host ('VueOn provisioning stopped: ' + $_.Exception.Message) -ForegroundColor Red
    if (Test-Path -LiteralPath $script:installDir) {
        try { $script:report.Notes += ('FAILED: ' + $_.Exception.Message); Write-Report } catch { }
    }
    exit 1
}