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
2. A new identity has a new SHA-1. Put it in `DEFAULT_IDENTITY` in `scripts/build-app.sh`.
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
2. Commit, then run:
   ```sh
   make test
   make release
   ```
3. `make release` (`scripts/package-release.sh`) does the following, and stops on the first failure:
   1. It refuses uncommitted changes. `PACE_ALLOW_DIRTY=1` makes a test package.
   2. It builds the release configuration and signs it. Without the identity, it stops.
   3. It checks the app:
      - the signature verifies
      - the designated requirement holds the identity's SHA-1
      - the binary is arm64
      - the version matches
   4. It creates `build/release/PACE-Launcher-<version>.dmg`, holding the app and an Applications shortcut, and verifies it.
   5. It mounts the DMG read-only and hidden, and checks:
      - the contents
      - the app again
      - that no key material is inside

      Gatekeeper reports "rejected" here; that is expected without notarization.
   6. It writes `PACE-Launcher-<version>.dmg.sha256` and checks it with `shasum -a 256 -c`.
4. Tag the commit `v<version>` and publish a GitHub Release with that tag.
   - Attach both files from `build/release/`.
   - In the notes, link `docs/INSTALL.md`, mention Open Anyway, and paste the SHA-256.
   ```sh
   git tag v<version>
   git push origin v<version>
   gh release create v<version> build/release/PACE-Launcher-<version>.dmg build/release/PACE-Launcher-<version>.dmg.sha256
   ```
