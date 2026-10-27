# VueOn Windows Player

**Public preview v0.1.4 for TEST PCs only. Not approved for customer production deployment.**

Turn a spare Windows 11 Home or Pro computer into a VueOn signage player. The viewer starts Microsoft Edge full-screen at `https://portal.vueon.app/pair/`, remembers its pairing in a persistent browser profile, applies a VueOn loading wallpaper and checks every five seconds whether the viewer needs relaunching.

**The first-stage installer does not enable automatic Windows login.** This is deliberate: a previous preview failed at the Windows sign-in screen. Prove that the `VueOnPlayer` account signs in manually before configuring unattended startup.

## Download and test without a GitHub account

1. Select the green **Code** button on this page, then **Download ZIP**.
2. Extract the ZIP on a spare Windows 11 PC that has finished its initial setup and is connected to the internet.
3. Open the extracted folder. Right-click **Install-VueOn.cmd** and choose **Run as administrator**.
4. Enter and securely save **two distinct passwords** when prompted: `VueOnAdmin` and `VueOnPlayer`.
5. If the installer reports success, restart Windows. Select **Other user**, sign into `.\VueOnPlayer` and verify VueOn opens.
6. Pair the screen through the VueOn portal, sign out and back in and verify it is still paired.
7. **Only after manual login works**, configure Microsoft's official [Sysinternals Autologon](https://learn.microsoft.com/en-us/sysinternals/downloads/autologon): username `VueOnPlayer`, domain = computer name, password = verified player password. Reboot and verify unattended playback.
8. Press **Alt+F4**; the player should relaunch after the watchdog checks. Test normal reboot and network reconnection.

See **[START-HERE.md](START-HERE.md)** for the printable technician checklist, and **[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)** for diagnostics and limitations.

## What this build does and does not do

- Provisions local Windows accounts, VueOn branding, power settings, Edge viewer and a scheduled watchdog.
- Uses a persistent Edge profile. It does **not** run in InPrivate mode.
- Includes manufacturer-specific firmware-setting diagnostics, but **does not change BIOS or flash firmware by default**.
- Does **not** change Windows Defender, disable security updates or configure unattended sign-in automatically.
- Is **not a secure locked-down kiosk** on Windows Home; physically protect test devices.

Windows itself must first be installed and connected to a network. For real deployments, also verify Windows activation, monitor auto-power, power-outage recovery and support arrangements.

## Development status

This is an **unsigned, hardware-testing preview**. GitHub Actions parsing and isolated permission-recovery tests are useful checks, but are not substitutes for a successful fresh-PC reboot, logon, pairing and watchdog test. Report failures with the exact error, **without sharing passwords**.

**Download source:** [Code → Download ZIP](https://github.com/JSFNS/vueon-windows-player/archive/refs/heads/main.zip).

No commercial production release has been approved.