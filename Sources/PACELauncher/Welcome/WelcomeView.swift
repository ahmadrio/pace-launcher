import AppKit
import PACELauncherCore
import SwiftUI

/// First-launch window: where PACE lives, how to open it, which
/// permissions it uses and why, and the update setting.
struct WelcomeView: View {
    let status: PermissionStatus
    let settings: SettingsStore
    let hotKeys: HotKeyCenter
    let version: String
    let openPermission: (PermissionKind) -> Void
    let openLauncher: () -> Void
    let openShortcuts: () -> Void
    let done: () -> Void

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to PACE Launcher").font(.title2.bold())
                    Text("Version \(version)").foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("PACE lives in the menu bar. It has no Dock icon.", systemImage: "menubar.rectangle")
                launcherLine
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Permissions").font(.headline)
                Text("Each one is only needed for the features under its name. You can grant them later.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 6) {
                ForEach(status.rows) { row in
                    PermissionRowView(row: row) { openPermission(row.kind) }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Check for updates automatically", isOn: $settings.data.checkForUpdates)
                    .accessibilityIdentifier("welcome-check-updates")
                Text(UpdateChecker.explanation)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if LoginItem.isInstalled {
                Toggle("Launch at login", isOn: Binding(
                    get: { LoginItem.isEnabled },
                    set: { LoginItem.setEnabled($0) }
                ))
            }

            Spacer(minLength: 0)

            Text("Open this window again from the menu bar or with “Welcome & Permissions” in the launcher.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Open Launcher", action: openLauncher)
                    .accessibilityIdentifier("welcome-open-launcher")
                Button("Done", action: done)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("welcome-done")
            }
        }
        .padding(24)
        .frame(width: 560)
    }

    @ViewBuilder private var launcherLine: some View {
        let entry = hotKeys.entries.first { $0.name == ShortcutID.launcher.rawValue }
        let combo = entry?.combo.displayString ?? "the launcher shortcut"
        Label("Press \(combo) anywhere to open the launcher.", systemImage: "command")
        if case .unavailable? = entry?.status {
            HStack {
                Text("\(combo) is used by another app.").foregroundStyle(.orange)
                Button("Change Shortcut…", action: openShortcuts)
            }
            .padding(.leading, 28)
        }
    }
}

private struct PermissionRowView: View {
    let row: PermissionRow
    let open: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: row.kind.symbol)
                .font(.system(size: 16))
                .frame(width: 24)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.kind.title).fontWeight(.medium)
                Text(row.kind.purpose)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(row.state.label)
                    .font(.system(size: 12))
                    .foregroundStyle(color)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
                if row.state.needsAction {
                    Button("Open Settings…", action: open)
                        .controlSize(.small)
                }
            }
            .frame(width: 160, alignment: .trailing)
        }
        .padding(10)
        .background(.quaternary, in: .rect(cornerRadius: 8))
    }

    private var color: Color {
        switch row.state {
        case .granted: .green
        case .missing, .asksEachTime, .denied, .needsRelaunch: .orange
        case .notNeeded, .unavailable, .asksOnFirstUse: .secondary
        }
    }
}
