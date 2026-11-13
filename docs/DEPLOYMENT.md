# VueOn Windows Player - deployment and acceptance (v0.1.6 preview)

## Preconditions

- [ ] Spare Windows 11 Home or Pro PC, activated and updated
- [ ] Microsoft Defender and Windows Update enabled
- [ ] Working internet; Edge loads https://portal.vueon.app/pair/
- [ ] Known original maintenance administrator password, kept securely
- [ ] Keyboard, mouse, display and physical security
- [ ] Two unique strong account passwords for each device

## Installer steps

1. Download a fresh public GitHub ZIP, extract it, and run **Install-VueOn.cmd as administrator**.
2. Installer creates local VueOnAdmin (administrator) and VueOnPlayer (standard user) if absent. Existing accounts and pairing are preserved.
3. It stages desktop, lock/login-screen and account-picture images from `Branding/`, then configures Edge, watchdog and no-sleep settings.
4. If you choose Y for automatic login, Windows verifies the VueOnPlayer password using LogonUser. The Microsoft-signed Autologon utility opens. Enter VueOnPlayer, domain = PC name and the same verified password; click Enable.
5. Installer checks Winlogon username/domain/flag afterwards. It **cannot verify the password retyped inside Microsoft's GUI**, so reboot remains essential.
6. If auto login is skipped, sign in manually with `.\VueOnPlayer`.
7. Pair and assign content via VueOn. Test another reboot.

## Original VueOn artwork

| Path under C:\ProgramData\VueOnPlayer\Branding | Effect |
|---|---|
| VueOn-Wallpaper.png | Auto-applied desktop background on first VueOnPlayer login |
| VueOn-LockScreen.png | Enterprise/Education local lock screen policy if no conflicting policy. Home/Pro: choose in Settings manually or use supported Intune/CSP |
| VueOn-Account.png | Account picture: select in Settings > Accounts > Your info |

Never use an unsupported Pro local Group Policy registry hack to force the lock/login image.

## Acceptance tests

| Test | Pass criteria |
|---|---|
| Account | VueOnPlayer exists and is a standard user |
| Autologon | Cold boot logs into VueOnPlayer without human input (if selected) |
| Manual recovery | Separate administrator password works |
| Branding | Desktop displays VueOn; lock/login artwork staged and visually checked |
| Browser | Edge opens VueOn full screen |
| Pairing persistence | Correct assigned content survives restart |
| Watchdog | Alt+F4 causes viewer to relaunch |
| Offline recovery | Reconnect internet without re-pairing |
| Overnight | 24 hours without dialogs or blank screen |
| Security | Defender, updates, account isolation retained |
| Report | `deployment-report.json` accurate and never contains passwords |

Watchdog checks Edge process activity, not the web page's actual rendering.

## BIOS support

Dell requires Dell Command Configure for optional AC-power recovery; HP and Lenovo likewise need supported official tooling. Normal installation does **not** change BIOS or flash firmware. Manufacturer warnings are advisory.

## Troubleshooting / rollback

If automatic login fails, do **not reset Windows**. Use the known administrator account; test manual login using `.\VueOnPlayer` and its actual password, then rerun the installer and choose Y or use the official Microsoft Autologon utility. Device sign-in policies, ActiveSync restrictions or legal notices may prevent automatic login even when Winlogon reports configured.

A fresh Windows install may lack DefaultUserName/AutoAdminLogon registry values; this is not an installation error.

From elevated PowerShell:

~~~powershell
& 'C:\ProgramData\VueOnPlayer\Maintenance\Enter-Maintenance.ps1'
& 'C:\ProgramData\VueOnPlayer\Maintenance\Exit-Maintenance.ps1'
& 'C:\ProgramData\VueOnPlayer\Maintenance\Get-Status.ps1'
& 'C:\ProgramData\VueOnPlayer\Maintenance\Uninstall-VueOn.ps1'
~~~

Uninstall disables the VueOn startup task and VueOn-owned automatic login where possible. It preserves Windows local accounts, branding assets, browser pairing and logs.

## Preview limitations

Needs full on-device boot/autologon/branding/TV pairing testing, signed distribution, robust browser heartbeat, hardware power recovery checks, and business security review before production.
