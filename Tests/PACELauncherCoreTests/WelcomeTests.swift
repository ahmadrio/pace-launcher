import Testing
@testable import PACELauncherCore

private func facts(
    accessibility: Bool = true, inputMonitoring: Bool = true,
    autoExpandEnabled: Bool = true, autoExpandRunning: Bool = true,
    clipboard: ClipboardPermission? = .allowed
) -> PermissionFacts {
    PermissionFacts(
        accessibility: accessibility, inputMonitoring: inputMonitoring,
        autoExpandEnabled: autoExpandEnabled, autoExpandRunning: autoExpandRunning, clipboard: clipboard
    )
}

private func state(_ kind: PermissionKind, _ facts: PermissionFacts) -> PermissionState? {
    PermissionChecklist.rows(facts).first { $0.kind == kind }?.state
}

struct WelcomeTests {
    @Test func `rows come in a fixed order`() {
        #expect(PermissionChecklist.rows(facts()).map(\.kind) == [.accessibility, .inputMonitoring, .clipboard, .automation])
    }

    @Test func `maps each permission`() {
        #expect(state(.accessibility, facts(accessibility: true)) == .granted)
        #expect(state(.accessibility, facts(accessibility: false)) == .missing)

        #expect(state(.inputMonitoring, facts()) == .granted)
        #expect(state(.inputMonitoring, facts(inputMonitoring: false, autoExpandRunning: false)) == .missing)
        #expect(state(.inputMonitoring, facts(inputMonitoring: false, autoExpandEnabled: false, autoExpandRunning: false)) == .notNeeded)
        #expect(state(.inputMonitoring, facts(inputMonitoring: true, autoExpandEnabled: false, autoExpandRunning: false)) == .notNeeded)
        #expect(state(.inputMonitoring, facts(inputMonitoring: true, autoExpandRunning: false)) == .needsRelaunch)
        // The keyboard tap can run although the preflight says no (seen on
        // Pace's Mac): a running auto-expand is what counts.
        #expect(state(.inputMonitoring, facts(inputMonitoring: false, autoExpandRunning: true)) == .granted)

        #expect(state(.clipboard, facts(clipboard: .allowed)) == .granted)
        #expect(state(.clipboard, facts(clipboard: .asksEachTime)) == .asksEachTime)
        #expect(state(.clipboard, facts(clipboard: .denied)) == .denied)
        #expect(state(.clipboard, facts(clipboard: nil)) == .unavailable)

        #expect(state(.automation, facts()) == .asksOnFirstUse)
        #expect(state(.automation, facts(accessibility: false, inputMonitoring: false, clipboard: nil)) == .asksOnFirstUse)
    }

    @Test func `labels and actions`() {
        let labels: [PermissionState: String] = [
            .granted: "Granted",
            .missing: "Not granted",
            .notNeeded: "Not needed while auto-expand is off",
            .needsRelaunch: "Granted — quit and reopen PACE to start",
            .asksEachTime: "Asks each time",
            .denied: "Denied",
            .unavailable: "Unavailable",
            .asksOnFirstUse: "macOS asks the first time you use one",
        ]
        for (state, label) in labels {
            #expect(state.label == label)
            #expect(state.needsAction == [.missing, .asksEachTime, .denied].contains(state), "\(state)")
        }
    }

    @Test func `titles and purposes`() {
        #expect(PermissionKind.allCases.map(\.title) == ["Accessibility", "Input Monitoring", "Paste from Other Apps", "Automation"])
        #expect(PermissionKind.allCases.map(\.purpose) == [
            "Window snapping, pasting into other apps, Lock Screen and Log Out.",
            "Snippet keywords that expand as you type.",
            "Clipboard history.",
            "Restart, Shut Down, Empty Trash and Toggle Dark Mode.",
        ])
    }

    @Test func `retries auto-expand only when it waits for a granted permission`() {
        #expect(PermissionChecklist.shouldRetryAutoExpand(facts(inputMonitoring: true, autoExpandRunning: false)))
        #expect(!PermissionChecklist.shouldRetryAutoExpand(facts()))
        #expect(!PermissionChecklist.shouldRetryAutoExpand(facts(inputMonitoring: false, autoExpandRunning: false)))
        #expect(!PermissionChecklist.shouldRetryAutoExpand(facts(autoExpandEnabled: false, autoExpandRunning: false)))
    }

    @Test func `test folders get their own keys`() {
        #expect(MachineDefaults.key("welcomeShown", usingTestFolders: false) == "welcomeShown")
        #expect(MachineDefaults.key("welcomeShown", usingTestFolders: true) == "welcomeShown.testData")
    }
}
