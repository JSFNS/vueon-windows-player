# VueOn Windows Player - Deployment and acceptance

## Preflight

- [ ] Confirm the computer will be dedicated to signage and data is backed up.
- [ ] Windows 11 is activated; Windows Update and Microsoft Defender remain enabled.
- [ ] Ethernet or Wi-Fi connects to the internet; Edge loads `https://portal.vueon.app/pair/`.
- [ ] Existing administrator credentials are recorded in an approved FNS secrets manager.
- [ ] No ordinary end-user data remains accessible to the `VueOnPlayer` account.
- [ ] Screen and PC are physically secure, with adequate ventilation.
- [ ] Approved VueOn wallpaper is available (optional; fallback graphic otherwise).

## Install

1. Right-click `Install-VueOn.cmd`, select **Run as administrator**.
2. On an existing VueOn prototype the script migrates VueOn Startup-folder shortcuts into `C:\ProgramData\VueOnPlayer\LegacyStartupBackup` (rather than deleting them).
3. Use unique passwords per device. If it creates `VueOnPlayer`, remember that password is also used for LSA-based autologon.
4. Review BIOS report. A missing OEM tool, unsupported setting or supervisor password requires manual firmware configuration.
5. Restart. Watch the branded desktop appear, followed by Edge app mode and the VueOn pairing screen.
6. Pair via VueOn; leave scheduled content running.
7. Restart again and validate retained pairing.

## Acceptance tests

| Test | Pass criteria |
| --- | --- |
| Cold boot | No operator password; loads VueOn under standard account |
| Full-screen | VueOn displays without Edge tabs or address bar |
| Pairing persistence | Same paired screen and content after restart |
| Crash recovery | Alt+F4; browser reopens during the next five-second watchdog cycle, once the initial 15-second grace has passed |
| Offline/reconnect | Reconnect network; existing paired content resumes without re-pairing |
| AC power failure | BIOS and PC restart after AC is restored; TV returns to the right HDMI input |
| Overnight | 24h uninterrupted run, no dialogs or blank displays |
| Windows Update | Security updates remain enabled; active hours agreed with client; post-update restart recovers signage |
| Access control | `VueOnPlayer` cannot elevate; admin access remains available and passwords are unique |
| Report | `deployment-report.json` exists without passwords; unsupported BIOS reported honestly |

**Watchdog note:** It checks whether the VueOn Edge browser process is running, not whether the VueOn web page is frozen or its content has stalled. Cloud heartbeats/health checks are future work.

## BIOS integration

**Dell:** Requires Dell Command Configure `cctk.exe` installed and exposing either `--AcPwrRcvry` or `--acpower`; writes `on` and queries the result. Dell options vary by generation.

**HP:** Requires official HP Client Management Script Library already installed and an exact supported `After Power Loss` setting. Passworded firmware and unrecognised settings require manual setup.

**Lenovo:** Uses available `root\wmi` classes, requires `AfterPowerLoss`, sets `Power On` and saves. Supervisor-password-protected devices must use an approved manufacturer workflow or manual BIOS setup.

**Other hardware:** Detect and report. Never attempt generic UEFI writes, firmware flashing or BIOS password bypass.

## Maintenance and rollback

Run elevated, on the console:

```powershell
& 'C:\ProgramData\VueOnPlayer\Maintenance\Enter-Maintenance.ps1'
# Finish work; use Alt+F4 to close Edge if necessary.
& 'C:\ProgramData\VueOnPlayer\Maintenance\Exit-Maintenance.ps1'
```

To disable the deployed player without deleting pairing:

```powershell
& 'C:\ProgramData\VueOnPlayer\Maintenance\Uninstall-VueOn.ps1'
```

Uninstall intentionally keeps accounts, branding files, logs and Edge profile. Sign out/reboot to end a running session. If reinstalling, the profile is reused. Manual recovery: hold **Shift** during autologon to use a different Windows account (depending on Windows logon behaviour), or use the existing local admin account from the sign-in screen.

## Not yet production-ready

- Windows-native hardware validation and long-run reliability testing.
- Signed installer / verified release supply chain.
- Chrome/Edge multi-process false-positive handling and actual VueOn playback heartbeat.
- Full OEM model/password matrix, including BIOS AC power restore testing.
- First-run Windows deployment, device naming and unattended Wi-Fi provisioning.
- Supportability, secure remote diagnostics and maintenance windows.
- Customer security review and physical-access controls for Windows Home.