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
