# VueOn Windows Player - vendor-specific AC power loss recovery.
# Never flashes firmware, changes BIOS passwords, or bypasses supervisor locks.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-VueOnBiosInventory {
    $pc = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    [pscustomobject]@{
        Manufacturer = [string]$pc.Manufacturer
        Model = [string]$pc.Model
        BIOSVersion = [string]$bios.SMBIOSBIOSVersion
        PowerRecovery = 'Unknown'
        Tool = 'None'
        Supported = $false
        Message = 'Manual BIOS setup required unless a supported OEM interface is found.'
    }
}
function Get-VueOnDellCctk {
    $paths = @(
        "${env:ProgramFiles(x86)}\Dell\Command Configure\X86_64\cctk.exe",
        "$env:ProgramFiles\Dell\Command Configure\X86_64\cctk.exe",
        "${env:ProgramFiles(x86)}\Dell\Command Configure\X86\cctk.exe"
    )
    foreach ($path in $paths) {
        if ($path -and (Test-Path -LiteralPath $path)) { return $path }
    }
    $cmd = Get-Command cctk.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Invoke-VueOnPowerRecovery {
    [CmdletBinding()]
    param([switch]$Apply)
    $result = Get-VueOnBiosInventory
    try {
        switch -Regex ($result.Manufacturer) {
            'Dell' {
                $tool = Get-VueOnDellCctk
                if (-not $tool) {
                    $result.Message = 'Install Dell Command Configure manually, then rerun BIOS configuration.'
                    break
                }
                foreach ($setting in @('AcPwrRcvry', 'acpower')) {
                    $output = (& $tool "--$setting" 2>&1 | Out-String)
                    if ($LASTEXITCODE -ne 0 -or $output -notmatch '(?im)^\s*(AcPwrRcvry|acpower)\s*=\s*(off|last|on)') { continue }
                    $result.Tool = 'Dell Command Configure'
                    $result.Supported = $true
                    $result.PowerRecovery = $Matches[2].ToLowerInvariant()
                    if ($Apply -and $result.PowerRecovery -ne 'on') {
                        $setOut = (& $tool "--$setting=on" 2>&1 | Out-String)
                        if ($LASTEXITCODE -ne 0) { throw "Dell BIOS set failed: $setOut" }
                        $verify = (& $tool "--$setting" 2>&1 | Out-String)
                        if ($LASTEXITCODE -ne 0 -or $verify -notmatch '(?im)^\s*(AcPwrRcvry|acpower)\s*=\s*on') {
                            throw "Dell setting could not be verified: $verify"
                        }
                        $result.PowerRecovery = 'on'
                    }
                    $result.Message = if ($result.PowerRecovery -eq 'on') {
                        'Configured: Power On after AC restoration.'
                    } else { 'Setting available; add -ConfigureBios to apply.' }
                    break
                }
                if (-not $result.Supported) {
                    $result.Message = 'Dell BIOS AC setting not exposed by this model/tool version.'
                }
                break
            }
            'Lenovo' {
                $settings = @(Get-WmiObject -Namespace root\wmi -Class Lenovo_BiosSetting -ErrorAction Stop)
                $entry = $settings | Where-Object { $_.CurrentSetting -match '^AfterPowerLoss,' } | Select-Object -First 1
                if (-not $entry) { $result.Message = 'AfterPowerLoss not exposed on this Lenovo model.'; break }
                $result.Tool = 'Lenovo BIOS WMI'
                $result.Supported = $true
                $result.PowerRecovery = ($entry.CurrentSetting -split ',',2)[1]
                if ($Apply -and $result.PowerRecovery -ne 'Power On') {
                    $setter = Get-WmiObject -Namespace root\wmi -Class Lenovo_SetBiosSetting
                    $save = Get-WmiObject -Namespace root\wmi -Class Lenovo_SaveBiosSettings
                    $setResult = $setter.SetBiosSetting('AfterPowerLoss,Power On')
                    if ($setResult.Return -ne 'Success' -and $setResult.Return -ne 0) {
                        throw "Lenovo BIOS rejected the setting: $($setResult.Return). Supervisor password or unsupported model?"
                    }
                    $saveResult = $save.SaveBiosSettings()
                    if ($saveResult.Return -ne 'Success' -and $saveResult.Return -ne 0) {
                        throw "Lenovo BIOS could not save changes: $($saveResult.Return)."
                    }
                    $result.PowerRecovery = 'Power On (pending reboot)'
                }
                $result.Message = if ($result.PowerRecovery -match '^Power On') {
                    'Configured or pending reboot; verify after restart.'
                } else { 'Setting available; add -ConfigureBios to apply.' }
                break
            }
            '(HP|Hewlett-Packard)' {
                # CMSL is installed separately. Setting labels vary by model.
                Import-Module HP.ClientManagement -ErrorAction SilentlyContinue
                $getter = Get-Command Get-HPBIOSSettingsList -ErrorAction SilentlyContinue
                $setter = Get-Command Set-HPBIOSSettingValue -ErrorAction SilentlyContinue
                if (-not $getter -or -not $setter) {
                    $result.Message = 'HP CMSL not installed. Install official HP CMSL and rerun.'
                    break
                }
                $settings = @(Get-HPBIOSSettingsList)
                $setting = $settings | Where-Object { $_.Name -eq 'After Power Loss' } | Select-Object -First 1
                if (-not $setting) { $result.Message = 'HP BIOS exposes no exact After Power Loss setting. Set manually.'; break }
                $result.Tool = 'HP Client Management Script Library'
                $result.Supported = $true
                $result.PowerRecovery = [string](Get-HPBIOSSettingValue -Name 'After Power Loss')
                if ($Apply -and $result.PowerRecovery -ne 'Power On') {
                    if (Get-Command Get-HPBIOSSetupPasswordIsSet -ErrorAction SilentlyContinue) {
                        if (Get-HPBIOSSetupPasswordIsSet) {
                            throw 'HP BIOS setup password is present. Use approved credential workflow or set manually.'
                        }
                    }
                    Set-HPBIOSSettingValue -Name 'After Power Loss' -Value 'Power On' -ErrorAction Stop
                    $result.PowerRecovery = [string](Get-HPBIOSSettingValue -Name 'After Power Loss')
                    if ($result.PowerRecovery -ne 'Power On') { throw 'HP BIOS setting did not verify as Power On.' }
                }
                $result.Message = if ($result.PowerRecovery -eq 'Power On') {
                    'Configured: Power On after AC restoration.'
                } else { 'Setting available; add -ConfigureBios to apply.' }
                break
            }
            default { break }
        }
    } catch {
        $result.Message = 'BIOS configuration failed or requires manual access: ' + $_.Exception.Message
    }
    return $result
}
Export-ModuleMember -Function Get-VueOnBiosInventory, Invoke-VueOnPowerRecovery
