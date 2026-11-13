# Validate a LOCAL Windows player's password before enabling automatic sign-in.
# The password is held as a SecureString and never placed in a process argument,
# log, temporary file, or plain-text registry value.
#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Initialize-VueOnLocalLogonType {
    if ('VueOn.LocalLogonVerifier' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace VueOn {
    public static class LocalLogonVerifier {
        [DllImport("advapi32.dll", EntryPoint="LogonUserW", CharSet=CharSet.Unicode, SetLastError=true)]
        private static extern bool LogonUser(
            [MarshalAs(UnmanagedType.LPWStr)] string username,
            [MarshalAs(UnmanagedType.LPWStr)] string domain,
            IntPtr password, int logonType, int logonProvider, out IntPtr token);
        [DllImport("kernel32.dll", SetLastError=true)]
        private static extern bool CloseHandle(IntPtr handle);

        public static bool Check(string username, IntPtr securePassword, out int win32Error) {
            win32Error = 0;
            if (string.IsNullOrWhiteSpace(username) || securePassword == IntPtr.Zero)
                throw new ArgumentException("A local username and password are required.");
            IntPtr token = IntPtr.Zero;
            try {
                // LOGON32_LOGON_INTERACTIVE (2), default provider (0).
                // The dot domain restricts lookup to this PC's local SAM.
                bool ok = LogonUser(username, ".", securePassword, 2, 0, out token);
                if (!ok) win32Error = Marshal.GetLastWin32Error();
                return ok;
            } finally {
                if (token != IntPtr.Zero) CloseHandle(token);
            }
        }
    }
}
'@ -ErrorAction Stop
}

function Test-VueOnLocalPassword {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$UserName,
        [Parameter(Mandatory)][System.Security.SecureString]$Password
    )
    $account = Get-LocalUser -Name $UserName -ErrorAction Stop
    if (-not $account.Enabled) {
        Write-Warning ('Local VueOn account is disabled: ' + $UserName)
        return $false
    }
    if ($Password.Length -lt 1) { return $false }
    Initialize-VueOnLocalLogonType

    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($Password)
    try {
        $code = 0
        $valid = [VueOn.LocalLogonVerifier]::Check($UserName, $pointer, [ref]$code)
        if (-not $valid) {
            Write-Warning ('Windows could not verify local account sign-in (error ' + $code +
                '). Automatic sign-in has NOT been enabled.')
        }
        return $valid
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeGlobalAllocUnicode($pointer)
    }
}

Export-ModuleMember -Function Test-VueOnLocalPassword
