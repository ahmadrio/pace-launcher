CONFIG ?= debug
APP_NAME := PACE Launcher.app
BUILT_APP := build/app.noindex/$(APP_NAME)
INSTALLED_APP := $(HOME)/Applications/$(APP_NAME)
BUNDLE_ID := io.github.ahmadrio.PACELauncher

.PHONY: test app run install release logs reset-tcc signing-identity clean

test:
	swift test

app:
	scripts/build-app.sh $(CONFIG)

# Always launch the installed bundle with `open`: running the raw binary
# makes the terminal the responsible process for TCC and breaks permissions.
install: app
	-pkill -x PACELauncher
	@# Wait for the old instance to exit, or `open` may target the dying process.
	@for i in $$(seq 50); do pgrep -x PACELauncher >/dev/null || break; sleep 0.1; done
	mkdir -p "$(HOME)/Applications"
	rm -rf "$(INSTALLED_APP)"
	ditto "$(BUILT_APP)" "$(INSTALLED_APP)"

run: install
	open "$(INSTALLED_APP)"

# A checked DMG and SHA-256 checksum in build/release (docs/RELEASING.md).
release:
	scripts/package-release.sh

logs:
	log stream --style compact --level debug --predicate 'subsystem == "$(BUNDLE_ID)"'

# One-time: create the self-signed identity every build is signed with.
signing-identity:
	scripts/make-signing-identity.sh

reset-tcc:
	tccutil reset Accessibility $(BUNDLE_ID)
	tccutil reset AppleEvents $(BUNDLE_ID)

clean:
	swift package clean
	rm -rf build
