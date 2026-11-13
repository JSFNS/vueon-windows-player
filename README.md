# VueOn Windows Player

**Public preview v0.1.7 for spare Windows 11 Home / Pro test PCs only. Not approved for production rollout.**

Turn a Windows 11 PC into a VueOn signage player. The installer creates a dedicated standard user, installs the Edge viewer/watchdog, stages the **official VueOn artwork**, and **offers automatic Windows sign-in** using Microsoft's signed Sysinternals Autologon tool.

## Get started

1. **[Download the latest public ZIP](https://github.com/JSFNS/vueon-windows-player/archive/refs/heads/main.zip)**. GitHub sign-in is not required.
2. Extract the ZIP, then right-click **Install-VueOn.cmd → Run as administrator**.
3. Create distinct passwords for **VueOnAdmin** and **VueOnPlayer**.
4. When asked, choose **Y** to configure automatic login or **N** to skip. If Y, the installer verifies the Windows password, then opens the *Microsoft Autologon* dialog. Enter VueOnPlayer, this PC's name, and the verified password; click **Enable**.
5. Restart. VueOn should open in Edge full screen at **https://portal.vueon.app/pair/**. Pair and test another reboot.

**[Read the complete step-by-step installation guide](START-HERE.md)**, including Windows Home/Pro sign-in artwork limitations and troubleshooting.

**Repair branding on an existing PC without reinstalling:** download/extract the latest ZIP, sign into **VueOnPlayer**, then double-click **Repair-VueOn-Branding.cmd**. It fixes only the current user's wallpaper and places the lock/account PNGs in Pictures\\VueOn for selection in Settings. Do **not** run this repair as administrator.

## Branding included

The downloadable ZIP includes original VueOn imagery:

- **Branding/VueOn-Wallpaper.png** → desktop wallpaper (automatically applied and verified after the VueOnPlayer desktop loads; retried periodically if Windows changes it).
- **Branding/VueOn-LockScreen.png** → branded Windows lock/sign-in background (automatically configured with a supported Enterprise/Education local policy; choose the image manually under Windows 11 Home/Pro, or deploy through Intune/CSP).
- **Branding/VueOn-Account.png** → original VueOn icon for the player's Windows account photo (select in **Settings → Accounts → Your info**).

Files are copied to **C:\ProgramData\VueOnPlayer\Branding**. Existing custom artwork can be supplied in the package's `Branding/` folder and will be used instead of generated placeholder assets.

## Security and limitations

- User credentials are checked locally using Windows **LogonUser** before autologon can be enabled.
- The optional Microsoft tool is downloaded from the official Sysinternals site and its **Microsoft Authenticode signature is verified** before opening. The installer does **not** pass passwords in command-line arguments, write them into logs, or commit them to GitHub.
- Automatic login is **optional**; a manual sign-in remains available. Microsoft's LSA-protected password is still recoverable by a local administrator.
- Dedicated VueOnPlayer account is **not an administrator**. Keep a separate admin account for maintenance, use a unique password per device, and protect against physical access.
- Windows 11 Home/Pro cannot force a default lock-screen picture through the local **Enterprise/Education** Group Policy mechanism; unmanaged devices must choose the staged picture in Windows Settings. Intune/Personalization CSP is a separate supported option for managed Pro.
- Existing Windows 11 installation, working internet and Edge are prerequisites. BIOS power-on-after-outage changes are *not* performed by default. Windows Defender and Windows Update remain enabled.
- This is an unsigned preview, **not a hardened Windows kiosk**. A completed automatic login still requires a real-device reboot test.

**Dell notice:** "Install Dell Command Configure manually" is for optional AC-power recovery and is not a normal-installation failure.

## More documentation

- **[Installation guide](START-HERE.md)**
- **[Deployment checks and recovery](docs/DEPLOYMENT.md)**
- **[Microsoft Autologon documentation](https://learn.microsoft.com/en-us/sysinternals/downloads/autologon)**

The CI build checks PowerShell syntax, ACL recovery, original image assets, wallpaper runtime/repair wiring, local password verification, and the downloaded Microsoft Autologon signature. These tests cannot prove a particular physical PC will boot and pair correctly. Verify on spare hardware before any customer deployment.
