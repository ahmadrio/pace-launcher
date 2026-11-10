# Releasing PACE Launcher

## How signing works
- Every build, debug or release, is signed with one self-signed identity: **"PACE Launcher Signing"**, in the maintainer's login keychain.
- Its SHA-1 is `DEFAULT_IDENTITY` in `scripts/build-app.sh`.
- macOS remembers privacy permissions by the signing certificate. One identity across all versions therefore keeps users' Accessibility, Input Monitoring and Automation grants after an update.
- The app is not notarized. Users approve each new version once with **Open Anyway** (see `docs/INSTALL.md`).

## One-time setup
1. Create the identity:
   ```sh
   make signing-identity
   ```
   The private key is generated in a temporary folder and imported into the login keychain. The folder is then deleted. If an identity with that name already exists, the script refuses to run.
2. A new identity has a new SHA-1. Put it in `DEFAULT_IDENTITY` in `scripts/build-app.sh`; releases are only ever signed with that identity.
3. The first build may ask for permission for `codesign` to use the key. Enter your login password and choose **Always Allow**.

## Back up the key
If the key is lost, the next release has to use a new identity, and every user must grant permissions again once.
1. Back it up with Keychain Access › login › My Certificates › **PACE Launcher Signing** › File › Export Items…
2. Save it as a `.p12` with a strong password.
3. Keep that file out of this repository. `*.p12`, `*.pem` and `*.key` are git-ignored.

To restore it on another Mac:
```sh
security import PACE-Launcher-Signing.p12 -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign
```

## Making a release
1. Set the new version (`x.y.z`) in `CFBundleShortVersionString` in `Resources/Info.plist`. `CFBundleVersion` is set to a timestamp by the build.
2. Write the release notes in `docs/releases/v<version>.md` (copy the previous one). Keep `SHA256_PLACEHOLDER` in them: each build has its own checksum, and step 4 fills it in.
3. Commit everything, then run, on the commit you will tag:
   ```sh
   make test
   make release
   ```
   `make release` (`scripts/package-release.sh`) does the following, and stops on the first failure:
   1. It refuses to run outside the repository's git checkout, and refuses uncommitted changes. `PACE_ALLOW_DIRTY=1` makes a test package named `…-dirty.dmg`. Files from an earlier run are removed first.
   2. It refuses any identity other than `DEFAULT_IDENTITY`, because another certificate would reset every user's permissions. `PACE_SIGN_IDENTITY` may only name that same certificate. It then builds the release configuration, strips its debug symbols (they hold paths from the build Mac), and signs it.
   3. It checks the app:
      - the signature verifies
      - the designated requirement holds the identity's SHA-1
      - the binary is arm64
      - the version matches
      - the binary holds no path from this Mac (your home folder or the checkout)
   4. It creates the DMG under a hidden name in `build/release/`, holding the app and an Applications shortcut, and verifies it.
   5. It mounts the DMG read-only and hidden, and checks:
      - the contents
      - the app again
      - that no key material is inside

      Gatekeeper reports "rejected" here; that is expected without notarization.
   6. It writes the SHA-256, then names both files `PACE-Launcher-<version>.dmg` and `.dmg.sha256` and checks them with `shasum -a 256 -c`. A failure at any step leaves no file with these names.
4. Tag the commit `v<version>` and publish a GitHub Release with that tag. The app's update check depends on it:
   - PACE reads `releases/latest` of `ahmadrio/pace-launcher` (`UpdateCheck.repository` in `Sources/PACELauncherCore/Updates/UpdateCheck.swift`). If the repository is renamed, change that constant first.
   - The tag must be `v` plus the same `x.y.z` as `CFBundleShortVersionString`. A tag PACE can't read as a version is ignored.
   - Publish the release normally. Drafts and pre-releases are never offered to users.
   - Attach both files from `build/release/`. The notes link `docs/INSTALL.md`, mention Open Anyway, and get the SHA-256 filled in:
   ```sh
   git tag v<version>
   git push origin v<version>
   sed "s/SHA256_PLACEHOLDER/$(cut -d' ' -f1 build/release/PACE-Launcher-<version>.dmg.sha256)/" \
     docs/releases/v<version>.md > "${TMPDIR:-/tmp}/release-notes.md"
   gh release create v<version> --title "PACE Launcher <version>" --notes-file "${TMPDIR:-/tmp}/release-notes.md" \
     build/release/PACE-Launcher-<version>.dmg build/release/PACE-Launcher-<version>.dmg.sha256
   ```
