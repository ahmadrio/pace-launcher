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
4. PACE Launcher starts. Its icon appears in the menu bar, and **⌥Space** opens the launcher.

You approve each new version this way once.

**Prefer Terminal?** This removes the download flag from PACE Launcher only, and it then opens normally:
```sh
xattr -dr com.apple.quarantine "/Applications/PACE Launcher.app"
```

## 4. Permissions
PACE Launcher asks for these when a feature first needs them. You can change them any time in **System Settings › Privacy & Security**.

| Permission | Used for |
|---|---|
| Accessibility | Pasting into the app you were using, and moving and resizing windows. |
| Input Monitoring | Expanding snippets as you type (some Macs only). |
| Automation | Restart, Shut Down, Empty Trash and Toggle Dark Mode. It controls System Events, Finder and the login window. macOS asks the first time you use one of these. |

Every release is signed with the same certificate, so these permissions stay in place when you update.

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
