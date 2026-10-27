# VueOn Windows Player: Quick setup for testers

**Version:** v0.1.4 preview. **For spare/test PCs only. Not yet approved for customer deployments.**

## Before you start

You need a Windows 11 Home/Pro computer, display, keyboard, mouse, internet, and a Windows administrator login. Finish normal Windows setup first. Save any files you need. You do **not** need to create VueOn accounts manually.

## Install

1. Download and **extract** the official VueOn Windows Player test ZIP from the approved VueOn GitHub source. Do not run scripts directly inside the ZIP.
2. Open the extracted **windows-player** folder.
3. Right-click **Install-VueOn.cmd** → **Run as administrator**. If necessary, choose **Show more options** first. Approve the Windows administrator prompt.
4. When asked, create and securely save **two different passwords** (minimum 12 characters):
   - **VueOnAdmin**: maintenance administrator
   - **VueOnPlayer**: restricted signage account
5. At the end, check that the installer reports success. If it reports an error, **stop** and share the error with your VueOn technician. Do not repeatedly reinstall or reset the PC.
6. Restart Windows. **v0.1.4 does NOT log in automatically.** Choose **Other user** and enter **.\VueOnPlayer** with its password.
7. VueOn should open full screen at **https://portal.vueon.app/pair/**. Use the VueOn portal on your phone or another computer to pair the screen.
8. Sign out, sign back into **.\VueOnPlayer**, and check that the screen remains paired.

## Finish automatic startup (only after Step 8 passes)

9. Sign into your known Windows administrator account. Download the official **Microsoft Sysinternals Autologon** program: https://learn.microsoft.com/en-us/sysinternals/downloads/autologon
10. Run **Autologon64.exe** as administrator. Enter:
   - **Username:** VueOnPlayer
   - **Domain:** this computer's device name (Windows Settings → System → About)
   - **Password:** the *verified* VueOnPlayer password
   - Click **Enable**.
11. Restart. Windows should sign in, display VueOn branding, launch Edge, and show your existing paired content without touching the keyboard.
12. While content is playing, press **Alt+F4**. The viewer should reopen automatically (watchdog checks every five seconds after initial startup).
13. Disconnect and reconnect the network briefly; confirm VueOn resumes. Test an ordinary reboot again.

**Pass condition:** Windows powers on → logs into VueOnPlayer → opens VueOn full screen → remembers pairing → relaunches if Edge is closed. Power-failure BIOS recovery is hardware-dependent and not configured automatically by this preview.

## If anything fails

Do not delete or reset the Windows accounts. Use the Windows administrator account to troubleshoot and preserve the exact error. The deployment report is located at:

`C:\ProgramData\VueOnPlayer\deployment-report.json`

On Windows 11 Home this is a *signage viewer*, not a fully locked-down public kiosk. A user with physical keyboard access can reach Windows. Keep the PC physically secured.

**Security:** Keep Microsoft Defender and Windows Update enabled. Never share the passwords publicly, save them in GitHub, or use the same player password on multiple machines.
