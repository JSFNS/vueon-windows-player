# VueOn Windows Player - protected Windows autologon
# LSA secrets remain recoverable by local administrators: physical security matters.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Initialize-VueOnLsaType {
    if ('VueOn.LsaSecret' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
namespace VueOn {
    public static class LsaSecret {
        [StructLayout(LayoutKind.Sequential)]
        private struct LSA_OBJECT_ATTRIBUTES {
            public uint Length;
            public IntPtr RootDirectory;
            public IntPtr ObjectName;
            public uint Attributes;
            public IntPtr SecurityDescriptor;
            public IntPtr SecurityQualityOfService;
        }
        [StructLayout(LayoutKind.Sequential)]
        private struct LSA_UNICODE_STRING {
            public ushort Length;
            public ushort MaximumLength;
            public IntPtr Buffer;
        }
        [DllImport("advapi32.dll")]
        private static extern uint LsaOpenPolicy(IntPtr systemName,
            ref LSA_OBJECT_ATTRIBUTES attrs, uint desiredAccess, out IntPtr policy);
        [DllImport("advapi32.dll", EntryPoint="LsaStorePrivateData")]
        private static extern uint StoreData(IntPtr policy,
            ref LSA_UNICODE_STRING key, ref LSA_UNICODE_STRING value);
        [DllImport("advapi32.dll", EntryPoint="LsaStorePrivateData")]
        private static extern uint ClearData(IntPtr policy,
            ref LSA_UNICODE_STRING key, IntPtr nullValue);
        [DllImport("advapi32.dll")]
        private static extern uint LsaClose(IntPtr handle);
        [DllImport("advapi32.dll")]
        private static extern uint LsaNtStatusToWinError(uint status);

        private static LSA_UNICODE_STRING MakeString(IntPtr ptr, int chars) {
            if (chars < 0 || chars > 32766) throw new ArgumentOutOfRangeException("chars");
            return new LSA_UNICODE_STRING {
                Length = checked((ushort)(chars * 2)),
                MaximumLength = checked((ushort)((chars + 1) * 2)),
                Buffer = ptr
            };
        }
        private static void Check(uint status) {
            if (status != 0) throw new Win32Exception(unchecked((int)LsaNtStatusToWinError(status)));
        }
        public static void SetPassword(IntPtr password, int characters) {
            if (password == IntPtr.Zero || characters < 1) throw new ArgumentException("Password cannot be empty");
            Modify(password, characters, false);
        }
        public static void DeletePassword() { Modify(IntPtr.Zero, 0, true); }
        private static void Modify(IntPtr password, int characters, bool remove) {
            IntPtr keyBuffer = Marshal.StringToHGlobalUni("DefaultPassword");
            IntPtr policy = IntPtr.Zero;
            try {
                var attrs = new LSA_OBJECT_ATTRIBUTES();
                attrs.Length = (uint)Marshal.SizeOf(typeof(LSA_OBJECT_ATTRIBUTES));
                Check(LsaOpenPolicy(IntPtr.Zero, ref attrs, 0x00000020, out policy));
                var key = MakeString(keyBuffer, "DefaultPassword".Length);
                if (remove) Check(ClearData(policy, ref key, IntPtr.Zero));
                else {
                    var value = MakeString(password, characters);
                    Check(StoreData(policy, ref key, ref value));
                }
            } finally {
                if (policy != IntPtr.Zero) LsaClose(policy);
                Marshal.FreeHGlobal(keyBuffer);
            }
        }
    }
}
'@
}

function Enable-VueOnAutoLogon {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$UserName,
          [Parameter(Mandatory)][System.Security.SecureString]$Password)

    if ($Password.Length -lt 1) { throw 'Autologon password cannot be empty.' }
    Initialize-VueOnLsaType
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($Password)
    try { [VueOn.LsaSecret]::SetPassword($ptr, $Password.Length) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeGlobalAllocUnicode($ptr) }

    $key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    New-ItemProperty -Path $key -Name 'DefaultUserName' -PropertyType String -Value $UserName -Force | Out-Null
    New-ItemProperty -Path $key -Name 'DefaultDomainName' -PropertyType String -Value $env:COMPUTERNAME -Force | Out-Null
    Remove-ItemProperty -Path $key -Name 'DefaultPassword' -ErrorAction SilentlyContinue
    New-ItemProperty -Path $key -Name 'AutoAdminLogon' -PropertyType String -Value '1' -Force | Out-Null
}

function Disable-VueOnAutoLogon {
    [CmdletBinding()]
    param([string]$UserName = 'VueOnPlayer')
    $key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    $current = Get-ItemProperty -Path $key
    if ($current.DefaultUserName -ine $UserName) { return $false }
    New-ItemProperty -Path $key -Name 'AutoAdminLogon' -PropertyType String -Value '0' -Force | Out-Null
    Initialize-VueOnLsaType
    [VueOn.LsaSecret]::DeletePassword()
    return $true
}
Export-ModuleMember -Function Enable-VueOnAutoLogon, Disable-VueOnAutoLogon
