import PACELauncherCore
import Observation
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general, appearance, shortcuts, snippets, quicklinks, scripts, sync

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .shortcuts: "Shortcuts"
        case .snippets: "Snippets"
        case .quicklinks: "Quicklinks"
        case .scripts: "Scripts"
        case .sync: "Sync"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintpalette"
        case .shortcuts: "keyboard"
        case .snippets: "text.quote"
        case .quicklinks: "link"
        case .scripts: "terminal"
        case .sync: "icloud"
        }
    }
}

/// Window state (no `@State`: its macro plugin is not in the CLT).
@Observable
final class SettingsWindowModel {
    var section = SettingsSection.general
}

struct SettingsView: View {
    let model: SettingsWindowModel
    let settings: SettingsStore
    let scripts: ScriptLibrary
    let autoExpand: AutoExpandController
    let sync: SyncController
    let shortcuts: ShortcutRecorder
    let clipboard: ClipboardMaintenance
    let quicklinks: QuicklinkEditor

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SettingsSection.allCases) { section in
                    Button {
                        model.section = section
                    } label: {
                        Label(section.title, systemImage: section.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(model.section == section ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 6))
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                if AppPaths.isUsingTestFolders {
                    Label("Test data folders in use", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
            }
            .padding(12)
            .frame(width: 180)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(model.section.title).font(.title2.bold())
                    detail
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 640, minHeight: 440)
    }

    @ViewBuilder private var detail: some View {
        switch model.section {
        case .general:
            GeneralSettings(settings: settings, clipboard: clipboard)
        case .appearance:
            AppearanceSettings(settings: settings)
        case .shortcuts:
            ShortcutsSettings(recorder: shortcuts, scripts: scripts)
        case .scripts:
            ScriptsSettings(scripts: scripts)
        case .snippets:
            SnippetSettings(settings: settings, autoExpand: autoExpand)
        case .quicklinks:
            QuicklinksSettings(settings: settings, editor: quicklinks)
        case .sync:
            SyncSettings(sync: sync, settings: settings)
        }
    }
}

private struct GeneralSettings: View {
    let settings: SettingsStore
    let clipboard: ClipboardMaintenance

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Show menu bar icon", isOn: $settings.data.showMenuBarIcon)
            Text("When hidden, use the launcher commands “Toggle Menu Bar Icon”, “Settings” and “Quit PACE Launcher”.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if LoginItem.isInstalled {
                Toggle("Launch at login", isOn: Binding(
                    get: { LoginItem.isEnabled },
                    set: { LoginItem.setEnabled($0) }
                ))
            }

            HStack {
                Text("Accessibility")
                Spacer()
                Text(AccessibilityPermission.isGranted ? "Granted" : "Not granted")
                    .foregroundStyle(AccessibilityPermission.isGranted ? .green : .orange)
                if !AccessibilityPermission.isGranted {
                    Button("Open Settings…") {
                        AccessibilityPermission.prompt()
                        AccessibilityPermission.openSettings()
                    }
                }
            }

            Divider()

            Text("Clipboard History").font(.headline)
            Picker("Keep history", selection: Binding(
                get: { settings.data.clipboardRetention },
                set: { clipboard.choose($0) }
            )) {
                ForEach(ClipboardRetention.allCases, id: \.self) { retention in
                    Text(retention.title).tag(retention)
                }
            }
            .frame(maxWidth: 260)
            Text("Older clips are removed every hour. Pinned clips are always kept.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .alert(
                    clipboard.pendingRetention.map { $0.count == 1 ? "Delete 1 clip?" : "Delete \($0.count) clips?" } ?? "",
                    isPresented: Binding(
                        get: { clipboard.pendingRetention != nil },
                        set: { if !$0 { clipboard.cancelRetention() } }
                    ),
                    presenting: clipboard.pendingRetention
                ) { pending in
                    Button("Delete", role: .destructive) { clipboard.confirmRetention(pending) }
                    Button("Cancel", role: .cancel) { clipboard.cancelRetention() }
                } message: { pending in
                    Text("Unpinned clips not used within \(pending.retention.title) are deleted now.")
                }
            HStack {
                Button("Clear History…") { clipboard.pressClear() }
                    .accessibilityIdentifier("clear-clipboard-history")
                if let status = clipboard.status {
                    Text(status)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Text("Emoji").font(.headline)
            Picker("Skin tone", selection: $settings.data.emojiSkinTone) {
                ForEach(EmojiSkinTone.allCases, id: \.self) { tone in
                    Text(tone.title + (tone.modifier.map { " \($0)" } ?? "")).tag(tone)
                }
            }
            .frame(maxWidth: 260)
            .accessibilityIdentifier("emoji-skin-tone")
            Text("Used for hand and person emoji. In the emoji picker, ⌘T switches it, and ⌘⇧T gives one emoji its own.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            let own = settings.data.ownSkinToneCount
            if own > 0 {
                HStack {
                    Text(own == 1 ? "1 emoji has its own skin tone" : "\(own) emoji have their own skin tone")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Button("Reset") { settings.data.emojiSkinTones = [:] }
                        .accessibilityIdentifier("reset-emoji-tones")
                }
            }
        }
    }
}

private struct AppearanceSettings: View {
    let settings: SettingsStore

    private var theme: ThemeSettings { settings.data.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Theme", selection: Binding(
                get: { theme.preset },
                set: { settings.data.theme.apply($0) }
            )) {
                ForEach(ThemePreset.allCases.filter { $0 != .custom }, id: \.self) { preset in
                    Text(preset.title).tag(preset)
                }
                if theme.preset == .custom {
                    Text(ThemePreset.custom.title).tag(ThemePreset.custom)
                }
            }

            HStack {
                ColorPicker("Accent color", selection: Binding(
                    get: { theme.accent.map { Color(red: $0.red, green: $0.green, blue: $0.blue) } ?? .accentColor },
                    set: { settings.data.theme.setAccent(RGB($0)) }
                ), supportsOpacity: false)
                if theme.accent != nil {
                    Button("Use system accent") { settings.data.theme.setAccent(nil) }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Glass density: \(Int(theme.glassTint * 100))%")
                Slider(value: Binding(
                    get: { theme.glassTint },
                    set: { settings.data.theme.setGlassTint($0) }
                ), in: 0...0.9)
                Text("Lower lets more of the desktop show through the launcher.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Picker("Mode", selection: Binding(
                get: { theme.appearance },
                set: { settings.data.theme.setAppearance($0) }
            )) {
                Text("System").tag(AppearanceMode.system)
                Text("Light").tag(AppearanceMode.light)
                Text("Dark").tag(AppearanceMode.dark)
            }
            .pickerStyle(.segmented)
        }
    }
}

private struct ScriptsSettings: View {
    let scripts: ScriptLibrary

    var body: some View {
        // Reading foldersVersion makes the list refresh after Add/Remove.
        let _ = scripts.foldersVersion
        VStack(alignment: .leading, spacing: 12) {
            Text("PACE runs any script whose header has a title (`# @pace.title` or `# @raycast.title`). Found \(scripts.scripts.count) script command(s).")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                folderRow(AppPaths.scriptsDirectory, note: "Main folder (follows iCloud sync)", removable: false)
                ForEach(scripts.extraFolders, id: \.path) { folder in
                    folderRow(folder, note: "This Mac only", removable: true)
                }
            }

            HStack {
                Button("Add Folder…", action: addFolder)
                Button("Reload") { scripts.reload() }
                Button("Open Main Folder") { scripts.openFolder() }
            }
        }
    }

    private func folderRow(_ folder: URL, note: String, removable: Bool) -> some View {
        HStack {
            Image(systemName: "folder")
            VStack(alignment: .leading, spacing: 1) {
                Text((folder.path as NSString).abbreviatingWithTildeInPath).lineLimit(1).truncationMode(.middle)
                Text(note).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Show") { NSWorkspace.shared.open(folder) }
            if removable {
                Button("Remove") {
                    scripts.setExtraFolders(scripts.extraFolders.filter { $0 != folder })
                }
            }
        }
        .padding(8)
        .background(.quaternary, in: .rect(cornerRadius: 6))
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Add Folder"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        scripts.setExtraFolders(scripts.extraFolders + [url])
    }
}

private struct SnippetSettings: View {
    let settings: SettingsStore
    let autoExpand: AutoExpandController

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Expand snippet keywords as I type, in any app", isOn: $settings.data.autoExpandEnabled)
            Text("Type a snippet’s keyword (like ;addr) and it is replaced right away. Never in password fields or in PACE itself.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            HStack {
                Text("Input Monitoring")
                Spacer()
                if KeystrokeMonitor.hasPermission {
                    Text("Granted").foregroundStyle(.green)
                } else {
                    Text("Needed").foregroundStyle(.orange)
                    Button("Grant…") {
                        KeystrokeMonitor.requestPermission()
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Don’t expand in these apps")
                ForEach(settings.data.autoExpandExcludedBundleIDs, id: \.self) { bundleID in
                    HStack {
                        Text(Self.name(of: bundleID))
                        Spacer()
                        Button("Remove") {
                            settings.data.autoExpandExcludedBundleIDs.removeAll { $0 == bundleID }
                        }
                    }
                    .padding(6)
                    .background(.quaternary, in: .rect(cornerRadius: 6))
                }
                Menu("Add App") {
                    ForEach(Self.runningApps(excluding: settings.data.autoExpandExcludedBundleIDs), id: \.bundleID) { app in
                        Button(app.name) { settings.data.autoExpandExcludedBundleIDs.append(app.bundleID) }
                    }
                }
                .fixedSize()
            }
        }
    }

    private static func name(of bundleID: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.deletingPathExtension().lastPathComponent ?? bundleID
    }

    private static func runningApps(excluding: [String]) -> [(name: String, bundleID: String)] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let id = app.bundleIdentifier, !excluding.contains(id), id != Bundle.main.bundleIdentifier else { return nil }
                return (app.localizedName ?? id, id)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

private struct SyncSettings: View {
    let sync: SyncController
    let settings: SettingsStore

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Store data in iCloud Drive", isOn: Binding(
                get: { sync.isEnabled },
                set: { on in Task { try? await sync.setEnabled(on) } }
            ))
            .disabled(sync.isBusy)
            Text(sync.isEnabled
                ? "Snippets, notes, script commands and settings live in iCloud Drive › PACE Launcher, so they survive a reset and open in the Files app. The clipboard and usage databases always stay on this Mac."
                : "Everything stays on this Mac. While this is off, PACE doesn’t read or write iCloud Drive.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if sync.isBusy {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Working…").foregroundStyle(.secondary)
                }
            }
            if let status = sync.status {
                Text(status)
                    .font(.system(size: 12))
                    .foregroundStyle(sync.statusIsError ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                    .textSelection(.enabled)
            }

            Divider()

            Text("Clipboard history backup").font(.headline)
            Toggle("Include clipboard history in backup", isOn: $settings.data.includeClipboardInBackup)
                .disabled(!sync.isEnabled)
            Text("Clipboard history can contain sensitive data. Files in iCloud Drive are encrypted by Apple, but end-to-end only when Advanced Data Protection is on.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if sync.isEnabled {
                if let choice = sync.pendingRestoreChoice {
                    restoreChoice(choice)
                }
                Text(sync.lastBackup.map { "Last backup: \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "No backup yet.")
                HStack {
                    Button("Back Up Now") { Task { await sync.backupNow() } }
                        .disabled(!settings.data.includeClipboardInBackup || sync.pendingRestoreChoice != nil || sync.isBusy)
                }
                if !sync.backups.isEmpty {
                    Text("Restore clipboard history").font(.system(size: 12, weight: .semibold))
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(sync.backups) { backup in
                            backupRow(backup)
                        }
                    }
                }
            } else {
                Text("Clipboard backups already in iCloud Drive are kept while sync is off.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Button(sync.armedAction == "delete" ? "Press Again to Delete All iCloud Backups" : "Delete iCloud Backups…") {
                if sync.confirm("delete") { sync.deleteBackups() }
            }
            .disabled(sync.isBusy)
        }
    }

    private func restoreChoice(_ choice: SyncController.RestoreChoice) -> some View {
        let date = choice.backup.date.formatted(date: .abbreviated, time: .shortened)
        let clips = choice.clips.map { "\($0) clips" } ?? "downloading…"
        let restoreKey = "choice-restore"
        return VStack(alignment: .leading, spacing: 8) {
            Label("Found a clipboard backup from an earlier install: \(date), \(clips). Automatic backups are paused until you choose.", systemImage: "clock.arrow.circlepath")
            HStack {
                Button(sync.armedAction == restoreKey ? "Press Again to Restore" : "Restore from Backup") {
                    if sync.confirm(restoreKey) { Task { await sync.restore(choice.backup) } }
                }
                Button("Keep Current History") { Task { await sync.keepCurrentHistory() } }
            }
            .disabled(sync.isBusy)
        }
        .padding(10)
        .background(.quaternary, in: .rect(cornerRadius: 8))
    }

    private func backupRow(_ backup: SyncController.Backup) -> some View {
        let key = "restore-" + backup.url.lastPathComponent
        return HStack {
            Image(systemName: backup.isDownloaded ? "doc" : "icloud")
            Text(backup.date.formatted(date: .abbreviated, time: .shortened))
            if !backup.isDownloaded {
                Text("in iCloud").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button(sync.armedAction == key ? "Press Again to Restore" : "Restore…") {
                if sync.confirm(key) { Task { await sync.restore(backup) } }
            }
            .disabled(sync.isBusy)
        }
        .padding(6)
        .background(.quaternary, in: .rect(cornerRadius: 6))
    }
}
