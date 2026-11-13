# VueOn Windows Player - validated official Microsoft Autologon GUI setup.
# This module NEVER passes a password on the command line or to GitHub.
#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-VueOnMicrosoftAutologon {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Destination)

    $null = New-Item -Path $Destination -ItemType Directory -Force
    $zip = Join-Path $Destination 'Autologon.zip'
    Invoke-WebRequest -UseBasicParsing -Uri 'https://download.sysinternals.com/files/AutoLogon.zip' -OutFile $zip -ErrorAction Stop
    Expand-Archive -LiteralPath $zip -DestinationPath $Destination -Force -ErrorAction Stop
    $exe = Join-Path $Destination 'Autologon64.exe'
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        throw 'Microsoft Autologon64.exe was not found in the downloaded archive.'
    }
    $sig = Get-AuthenticodeSignature -LiteralPath $exe -ErrorAction Stop
    if ($sig.Status -ne [System.Management.Automation.SignatureStatus]::Valid -or
        $null -eq $sig.SignerCertificate -or
        $sig.SignerCertificate.Subject -notmatch '(?i)O=Microsoft Corporation') {
        throw 'The Autologon executable failed its Microsoft Authenticode signature check.'
    }
    return $exe
}

function Get-VueOnWinlogonState {
    [CmdletBinding()]
    param([string]$RegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon')
    $key = Get-ItemProperty -LiteralPath $RegistryPath -ErrorAction Stop
    $usernameProperty = $key.PSObject.Properties['DefaultUserName']
    $domainProperty = $key.PSObject.Properties['DefaultDomainName']
    $enabledProperty = $key.PSObject.Properties['AutoAdminLogon']
    [pscustomobject]@{
        UserName = if ($null -ne $usernameProperty) { [string]$usernameProperty.Value } else { '' }
        Domain = if ($null -ne $domainProperty) { [string]$domainProperty.Value } else { '' }
        Enabled = ($null -ne $enabledProperty -and [string]$enabledProperty.Value -eq '1')
    }
}

function Invoke-VueOnAutoLogonWizard {
    [CmdletBinding()]
    param([string]$UserName = 'VueOnPlayer',
          [string]$ComputerName = $env:COMPUTERNAME,
          [Parameter(Mandatory)][System.Security.SecureString]$Password)

    $credentialsModule = Join-Path $PSScriptRoot 'VueOn.Credentials.psm1'
    Import-Module $credentialsModule -Force -ErrorAction Stop
    if (-not (Test-VueOnLocalPassword -UserName $UserName -Password $Password)) {
        return 'PasswordVerificationFailed'
    }

    Write-Host '[VueOn] Local Windows password verified.' -ForegroundColor Green
    Write-Host '[VueOn] Microsoft Autologon will open. Enter these details exactly:' -ForegroundColor Cyan
    Write-Host ('  Username: ' + $UserName)
    Write-Host ('  Domain: ' + $ComputerName)
    Write-Host '  Password: the SAME password just verified. It will NOT appear in the console.'
    Write-Host '  Select Enable, then close the Microsoft Autologon application.'
    Write-Host '[VueOn] The Windows login password is stored as an LSA secret recoverable by administrators.'
    $destination = Join-Path $env:TEMP ('VueOnAutologon-' + [Guid]::NewGuid().ToString('N'))
    try {
        $exe = Get-VueOnMicrosoftAutologon -Destination $destination
        $process = Start-Process -FilePath $exe -Wait -PassThru -ErrorAction Stop
        $state = Get-VueOnWinlogonState
        if ($state.Enabled -and
            $state.UserName -ieq $UserName -and
            $state.Domain -ieq $ComputerName) {
            return 'ConfiguredPendingReboot'
        }
        Write-Warning 'Microsoft Autologon did not enable VueOnPlayer for this PC. Sign-in remains manual.'
        return 'NotConfigured'
    } finally {
        if (Test-Path -LiteralPath $destination) {
            Remove-Item -LiteralPath $destination -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Export-ModuleMember -Function Get-VueOnMicrosoftAutologon, Get-VueOnWinlogonState, Invoke-VueOnAutoLogonWizard
