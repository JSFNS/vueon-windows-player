# VueOn Windows Player: Installation Guide

**For Windows 11 Home or Pro**

**Current version:** v0.1.4 (testing release)

## Step 1: Prepare the computer

1. Complete the normal Windows 11 setup.
2. Connect the computer to the internet.
3. Install any available Windows updates.
4. Make sure you have access to a Windows administrator account.

Do not create any VueOn Windows accounts yourself. The installer will do this.

## Step 2: Download VueOn

Open this link on the Windows computer:

**https://github.com/JSFNS/vueon-windows-player/archive/refs/heads/main.zip**

This downloads the latest VueOn Windows Player source package directly from our public GitHub repository.

1. Open your Downloads folder.
2. Right-click the downloaded ZIP.
3. Choose **Extract All**.
4. Open the extracted folder.

## Step 3: Run the installer

1. Find `Install-VueOn.cmd`.
2. Right-click it.
3. Choose **Run as administrator**.
4. Accept the Windows permission prompt.

The installer will automatically configure the VueOn Player.

It will ask you to create passwords for two accounts:

- **VueOnAdmin:** Administrator account used for maintenance.
- **VueOnPlayer:** Account used to display VueOn.

Use two different passwords, each at least 12 characters long. Save them securely.

Wait until the installer confirms it has completed successfully.

**If an error appears, stop and send the error to the VueOn support team. Do not reset the PC.**

## Step 4: Restart and sign in

1. Restart the computer.
2. On the Windows login screen, select **Other user** or **Switch user**.
3. Enter these details:

   **Username:** `.\VueOnPlayer`

   **Password:** The VueOnPlayer password you created.

4. Sign in.

VueOn should launch automatically in Microsoft Edge, full-screen, and display the pairing page.

## Step 5: Pair the screen

1. On another device, open your VueOn administration portal.
2. Open the Screens section.
3. Follow the screen-pairing process using the code displayed on the Windows computer.
4. Assign your chosen content.

Confirm the correct content appears on the screen.

Sign out of Windows and sign back into VueOnPlayer. Confirm that the screen is still paired.

## Step 6: Enable automatic Windows login

**Only complete this step once manual VueOnPlayer login has worked successfully.**

1. Open Microsoft's official Autologon download page:

   https://learn.microsoft.com/en-us/sysinternals/downloads/autologon

2. Download and extract the utility.
3. Sign into Windows with an administrator account.
4. Run `Autologon64.exe` as administrator.
5. Enter:

   **Username:** `VueOnPlayer`

   **Domain:** Your computer's device name, found under Windows Settings → System → About.

   **Password:** Your verified VueOnPlayer password.

6. Click **Enable**.

## Step 7: Test the finished player

Restart the PC.

Check that:

- [ ] Windows signs into VueOnPlayer automatically.
- [ ] VueOn opens without needing anyone to click anything.
- [ ] The screen displays the correct content.
- [ ] The screen remembers its pairing after another restart.
- [ ] Pressing Alt+F4 closes VueOn, but the viewer automatically reopens shortly afterwards.
- [ ] VueOn recovers after temporarily losing and regaining internet access.

## Installation complete

The computer is ready for VueOn testing once all checks have passed.

**Important:** This is currently a test release and is not yet approved for customer production deployment. Automatic power-on following a power cut may require a separate BIOS setting, depending on the PC.

**Support:** Keep a record of the computer's device name and report any errors. Never send account passwords in an email or support ticket.

**Project website:** https://vueon.app

**Public installer:** https://github.com/JSFNS/vueon-windows-player
