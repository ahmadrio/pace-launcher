# Installing PACE Launcher

PACE Launcher is free and open source. It is not notarized by Apple, because that needs a paid Apple Developer membership. macOS therefore blocks the first launch, and you approve the app once in System Settings. The steps below walk through it.

## Requirements
- macOS 27 on a Mac with Apple silicon.

## 1. Download and check
1. From the **Releases** page of the PACE Launcher repository on GitHub, download both files:
   - `PACE-Launcher-<version>.dmg`
   - `PACE-Launcher-<version>.dmg.sha256`
2. Optional but recommended: check that the download is intact. In Terminal, from the folder holding both files:
   ```sh
   cd ~/Downloads
   shasum -a 256 -c PACE-Launcher-<version>.dmg.sha256
   ```
   The output should end with `PACE-Launcher-<version>.dmg: OK`.

## 2. Install
1. Open the DMG.
2. Drag **PACE Launcher** onto the **Applications** shortcut.
3. Eject the DMG.

## 3. Open it the first time
1. Open PACE Launcher from Applications. macOS says it could not verify the app. Click **Done**.
2. Open **System Settings › Privacy & Security** and scroll down to **Security**.
3. Next to the message about PACE Launcher, click **Open Anyway**, then confirm with your password or Touch ID.
4. PACE Launcher starts, and its **Welcome** window opens. It shows:
   - that PACE lives in the menu bar (there is no Dock icon), and that **⌥Space** opens the launcher
   - each permission, what it is for, and whether it is granted; the status updates while the window is open
   - the update setting (see "Updates" below)

   Reopen it any time with **Welcome & Permissions…** in the menu bar, or "Welcome & Permissions" in the launcher.

You approve each new version this way once.

**Prefer Terminal?** This removes the download flag from PACE Launcher only, and it then opens normally:
```sh
xattr -dr com.apple.quarantine "/Applications/PACE Launcher.app"
```

## 4. Permissions
PACE Launcher asks for these when a feature first needs them, and the Welcome window lists them with buttons to the right System Settings pane. You can change them any time in **System Settings › Privacy & Security**.

| Permission | Used for |
|---|---|
| Accessibility | Pasting into the app you were using, moving and resizing windows, Lock Screen and Log Out. |
| Input Monitoring | Expanding snippets as you type (some Macs only). |
| Paste from Other Apps | Clipboard history. If macOS is set to ask each time, PACE pauses the history instead of asking on every copy. |
| Automation | Restart, Shut Down, Empty Trash and Toggle Dark Mode. It controls System Events, Finder and the login window. macOS asks the first time you use one of these. |

Every release is signed with the same certificate, so these permissions stay in place when you update.

## Updates
Once a day, PACE Launcher asks GitHub for the latest release of this repository. The request carries no information about you or your data, and PACE never downloads or installs anything by itself.
- When a newer version exists, PACE shows a short message once, and the menu bar gets **Download PACE Launcher <version>…**, which opens the release page in your browser.
- **Check for Updates…** in the menu bar asks right away and tells you the result. "Check for Updates" in the launcher does the same; once a newer version is known, it is called "Download PACE Launcher <version>" and opens the release page.
- To stop the daily check, turn off **Check for updates automatically** in **Settings › General** or in the Welcome window. Check for Updates still works when you ask.

## Network access
PACE Launcher connects to the internet only for:
- **Exchange rates** (`open.er-api.com`), when a currency conversion is on screen and the saved rates are more than 12 hours old.
- **The update check** (`api.github.com`), as described above.

Opening a quicklink or a release page hands the address to your browser.

## Updating
1. Quit PACE Launcher from its menu bar icon.
2. Install the new DMG as above, replacing the old app.
3. Approve it once with **Open Anyway**.

Your data and settings are kept.

## Uninstalling
1. Quit PACE Launcher from its menu bar icon.
2. Delete **PACE Launcher** from Applications.
3. Optionally, remove its data:
   ```sh
   rm -rf ~/Library/Application\ Support/PACE\ Launcher
   defaults delete io.github.ahmadrio.PACELauncher
   ```
   If you turned on iCloud sync, also delete the **PACE Launcher** folder in iCloud Drive.
4. Remove PACE Launcher from these lists under **System Settings › Privacy & Security**:
   - Accessibility
   - Input Monitoring
   - Automation

   If you enabled Launch at Login, also remove it from **General › Login Items**.

## Building from source
1. Install the Command Line Tools (`xcode-select --install`). They must provide Swift 6.4 or later.
2. Run the tests and build:
   ```sh
   make test
   make run      # builds, installs into ~/Applications and opens it
   ```

Builds are signed with the maintainer's certificate when it is present. Without it, they are signed ad-hoc, and macOS asks for permissions again after every build. To avoid that, create your own certificate once and point the build at it:
```sh
make signing-identity
export PACE_SIGN_IDENTITY="PACE Launcher Signing"
```
