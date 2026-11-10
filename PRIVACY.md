# Privacy

PACE Launcher works on your Mac. It has no account, no analytics and no tracking, and it never sends what you type, copy or store to anyone.

## What it stores, and where
Everything lives on your Mac unless you turn on iCloud sync.

| Data | Where |
|---|---|
| Launcher usage (which apps and commands you open, to rank results) | `~/Library/Application Support/PACE Launcher/launcher.sqlite` |
| Clipboard history (text, rich text, files, images) | `clipboard.sqlite` and `Clipboard Images/` in the same folder |
| AI chats | `chat.sqlite` in the same folder |
| Cached exchange rates | `exchange-rates.json` in the same folder |
| Snippets, notes, script commands, settings | `Snippets/`, `Notes/`, `Scripts/` and `settings.json` in the same folder, or in iCloud Drive › PACE Launcher when sync is on |
| Things that belong to this Mac (sync on or off, extra script folders, window positions, first launch, last update check) | macOS preferences for `io.github.ahmadrio.PACELauncher` |

### Clipboard history
- Copies that password managers mark as concealed or temporary are skipped, so passwords copied from them are not saved.
- Everything else you copy is saved until you delete it, or until it is older than the period you set in **Settings › General › Clipboard History**. That can include sensitive text. Pinned clips are never deleted automatically.
- If macOS asks before each paste from other apps, PACE pauses the history instead of asking on every copy.
- Deleting a clip or a chat overwrites it in the database file. Image clips are files, and they are deleted. With iCloud sync on, a deleted clip stays in the clipboard backups until newer backups replace them (the 5 newest are kept).

### iCloud sync (off by default)
When you turn on **Settings › Sync › Store data in iCloud Drive**:
- snippets, notes, script commands and `settings.json` move to iCloud Drive › PACE Launcher;
- a backup of the clipboard history is written there every 6 hours and when PACE quits, and the 5 newest backups are kept. You can leave the clipboard out of backups.

The clipboard, usage and chat databases themselves never go to iCloud. Files in iCloud Drive are encrypted by Apple, and end-to-end encrypted only when Advanced Data Protection is on. While sync is off, PACE does not read or write iCloud Drive, except when you press **Delete iCloud Backups**.

## Internet connections
PACE connects to the internet for two things only:

1. **Exchange rates:** `GET https://open.er-api.com/v6/latest/USD`, only when a currency conversion is on screen and the saved rates are missing or older than 12 hours, or when you choose Retry. The request names no currency or amount.
2. **Update check:** `GET https://api.github.com/repos/ahmadrio/pace-launcher/releases/latest`, about once a day (a day after GitHub last answered; a check that fails is tried again an hour later), and never while **Check for updates automatically** is off. **Check for Updates** asks right away when you choose it.

Both requests carry no cookies, no information about you, no app version and no system language; they say `PACELauncher` as the client. As with any web request, the server sees your IP address. PACE never downloads or installs updates by itself.

Opening a quicklink or a release page hands the address to your browser.

## On-device features
- **AI chat** uses Apple's on-device language model.
- **Translation** uses Apple's on-device translation. macOS may download language files for it; PACE does not.

## Permissions
PACE asks for these in **System Settings › Privacy & Security**. Each one is used only for the features listed.

| Permission | Used for |
|---|---|
| Accessibility | Pasting into the app you were using, moving and resizing windows, Lock Screen and Log Out. |
| Input Monitoring | Expanding snippet keywords as you type. PACE keeps only the last few typed characters in memory to spot your keywords; it never saves, logs or sends them. |
| Paste from Other Apps | Clipboard history. |
| Automation | Restart, Shut Down, Empty Trash and Toggle Dark Mode (System Events, Finder and the login window). |

## Script commands
Script commands are programs you add yourself. PACE runs them with your user's rights when you choose them; what they do is up to them.

## Logs
Diagnostic messages go to the macOS system log on your Mac. They are not sent anywhere.

## Deleting your data
See **Uninstalling** in [docs/INSTALL.md](docs/INSTALL.md). In short: quit PACE, delete `~/Library/Application Support/PACE Launcher`, run `defaults delete io.github.ahmadrio.PACELauncher`, and if you used sync, delete the PACE Launcher folder in iCloud Drive.

## Questions
Open an issue in the [GitHub repository](https://github.com/ahmadrio/pace-launcher/issues).
