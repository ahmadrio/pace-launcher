import DOTLauncherCore
import Observation
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general, appearance, snippets, scripts, sync

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .snippets: "Snippets"
        case .scripts: "Scripts"
        case .sync: "Sync"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintpalette"
        case .snippets: "text.quote"
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
            GeneralSettings(settings: settings)
        case .appearance:
            AppearanceSettings(settings: settings)
        case .scripts:
            ScriptsSettings(scripts: scripts)
        default:
            Text("Coming in a later step.").foregroundStyle(.secondary)
        }
    }
}

private struct GeneralSettings: View {
    let settings: SettingsStore

    var body: some View {
        @Bindable var settings = settings
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Show menu bar icon", isOn: $settings.data.showMenuBarIcon)
            Text("When hidden, use the launcher commands “Toggle Menu Bar Icon”, “Settings” and “Quit DOT Launcher”.")
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
            Text("DOT runs any script whose header has a title (`# @dot.title` or `# @raycast.title`). Found \(scripts.scripts.count) script command(s).")
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
