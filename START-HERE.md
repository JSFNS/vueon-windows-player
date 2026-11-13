# VueOn Windows Player: Installation Guide

**Windows 11 Home or Pro | v0.1.7 preview (test devices only)**

**You do not need ChatGPT or a GitHub account.** This installs VueOn on a spare Windows PC. It does not install Windows itself.

## 1. Prepare Windows

1. Complete Windows 11 setup and connect to the internet.
2. Install Windows updates.
3. Make sure you can sign into an existing Windows **administrator** account with its password.
4. Connect a keyboard, mouse, screen and power cable.

Do **not** create the VueOn accounts yourself. The installer creates them.

## 2. Download VueOn

**Download:** https://github.com/JSFNS/vueon-windows-player/archive/refs/heads/main.zip

1. Open **Downloads**.
2. Right-click the ZIP and choose **Extract All**.
3. Open the extracted folder.

## 3. Install VueOn

1. Right-click **Install-VueOn.cmd** and select **Run as administrator** (use **Show more options** if needed).
2. Approve the Windows administrator prompt.
3. The installer will set up two Windows accounts. Enter and securely save two **different passwords**, each at least 12 characters:
   - **VueOnAdmin:** maintenance administrator
   - **VueOnPlayer:** signage player account
4. Near the end, the installer asks whether to configure **automatic Windows sign-in**.
   - Choose **Y** to configure it now.
   - Choose **N** to leave normal manual sign-in in place. You can rerun the installer later.
5. If you choose **Y**, VueOn verifies the local Windows password **before changing automatic sign-in**. A Microsoft-signed **Autologon** window will appear. Enter:
   - **Username:** VueOnPlayer
   - **Domain:** The computer's **device name** (Settings → System → About)
   - **Password:** The same VueOnPlayer password you created or just entered.
   - Click **Enable** and close the Microsoft tool.
6. Wait for **Installation complete**, then review any notices.

**Note:** Automatic login is convenient but not a secure kiosk. Someone with physical access to the computer can use the signed-in player session. The password is stored as a protected Windows LSA secret, recoverable by local administrators. Keep machines physically secure and do not reuse passwords between PCs.

**If any command fails, stop. Do not reset Windows.** Save the error message for your technician.

## 4. VueOn backgrounds and sign-in images

The installer includes **official VueOn artwork** (not generic placeholder art) and copies these files into:

**C:\ProgramData\VueOnPlayer\Branding**

| Image | Filename | What happens |
|---|---|---|
| Desktop wallpaper | VueOn-Wallpaper.png | Set automatically on VueOnPlayer's first sign-in |
| Lock/login-screen background | VueOn-LockScreen.png | Applied automatically on supported Enterprise/Education editions; available for manual selection on Home/Pro |
| VueOn player account picture | VueOn-Account.png | Ready to select in Windows Settings |

**Windows 11 Home / Pro:** Windows does not support forcing the lock/login background with the normal local Group Policy method. To display the VueOn image, sign into VueOnPlayer, open **Settings → Personalization → Lock screen**, select **Picture → Browse photos** and choose the file above. For the account picture, open **Settings → Accounts → Your info → Choose a file** and select **VueOn-Account.png**. These are one-time visual settings.

Managed Windows 11 Pro devices can instead use the supported **Intune/Personalization CSP** approach; this preview does not configure MDM automatically.

### If Windows shows the wrong desktop background

The player automatically retries its VueOn wallpaper after Windows Explorer starts. To fix an **already installed** v0.1.6 player without changing automatic login or pairing:

1. Download and extract a **fresh ZIP** from the same public GitHub repository.
2. Sign into Windows as **VueOnPlayer** (the user that the player automatically signs into).
3. Close/minimise VueOn temporarily and double-click **Repair-VueOn-Branding.cmd** in the extracted folder. **Do not select Run as administrator.**
4. Confirm the command window reports **SUCCESS**. Press **Windows+D** to view the desktop. The browser normally covers the wallpaper.
5. The same command copies the two sign-in assets to your **Pictures\VueOn** folder for easy selection in Windows Settings.
6. For Windows 11 Pro/Home, open **Settings → Personalization → Lock screen → Picture → Browse photos** and select **Pictures\VueOn\VueOn-LockScreen.png**. Where available, turn on **Show the lock screen background picture on the sign-in screen**.
7. Select **Pictures\VueOn\VueOn-Account.png** from **Settings → Accounts → Your info** if you want the VueOn profile icon.

**Important:** The lock/sign-in picture is still a manual choice on unmanaged Windows 11 Pro/Home. An automatic-login computer normally bypasses the sign-in screen at boot, so press Windows+L to verify the selected lock-screen picture.

If the repair says FAILED, keep the error text and check the viewer log at `%LOCALAPPDATA%\VueOn\VueOn-Watchdog.log` while signed into VueOnPlayer. Do not reset Windows.

## 5. Restart and pair the screen

1. Restart Windows.
2. If you enabled Microsoft Autologon, Windows should sign into **VueOnPlayer** automatically.
3. If you skipped Autologon, sign in manually using **.\VueOnPlayer** and the player password. Some PCs show a separate **Other user** or **Switch user** option.
4. Edge should open VueOn full-screen at **https://portal.vueon.app/pair/**.
5. On another device, open the VueOn administration portal, pair the screen using the displayed code, and assign content.

## 6. Test before use

- [ ] Windows loads the VueOnPlayer desktop, automatically if requested.
- [ ] VueOn launches in Microsoft Edge without further clicks.
- [ ] Correct assigned content plays.
- [ ] The wallpaper shows VueOn branding.
- [ ] Pairing survives another restart.
- [ ] Closing the viewer with **Alt+F4** causes it to reopen automatically.
- [ ] VueOn reconnects after a temporary internet interruption.
- [ ] The device remains manageable using the retained administrator account.

For the final kiosk experience, also verify the physical monitor powers on after an outage. That is a separate, hardware-specific BIOS setting.

## If anything goes wrong

- Keep the original Windows administrator password and the VueOnAdmin password available.
- If automatic login fails, sign in manually as **.\VueOnPlayer** or use your administrator account; do **not** reset Windows.
- To configure automatic login again, run the installer as administrator and choose **Y**, or use the official [Microsoft Autologon utility](https://learn.microsoft.com/en-us/sysinternals/downloads/autologon).
- If the PC says **Install Dell Command Configure manually**, that refers to optional power-failure BIOS recovery. It does not prevent ordinary VueOn playback.
- Read the deployment report at **C:\ProgramData\VueOnPlayer\deployment-report.json**.
- Never share passwords in email, screenshots or GitHub issues.

**Status:** v0.1.7 is a hardware-testing preview. The complete startup, automatic login and pairing process must be tested on real hardware before production deployment.

Website: https://vueon.app

Public source: https://github.com/JSFNS/vueon-windows-player
