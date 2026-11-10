import AppKit
import DOTLauncherCore
import Observation
import SwiftUI

/// The current theme, applied live to every DOT window that registered.
@Observable
final class ThemeController {
    private(set) var theme: ThemeSettings

    @ObservationIgnored private var windows: [(window: () -> NSWindow?, glass: () -> NSGlassEffectView?, content: () -> NSView?)] = []
    @ObservationIgnored private var appearanceObservation: NSKeyValueObservation?

    init(theme: ThemeSettings) {
        self.theme = theme
        // System mode resolves its tint for the current appearance, so a
        // switch between light and dark has to apply it again.
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor in self?.applyToAll() }
        }
    }

    /// The accent for selections and chips; the system accent by default.
    var accentColor: Color {
        theme.accent.map { Color(red: $0.red, green: $0.green, blue: $0.blue) } ?? .accentColor
    }

    var appearance: NSAppearance? {
        switch theme.appearance {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    /// Forced SwiftUI scheme; nil follows the system. Needed because Liquid
    /// Glass adapts its content to what is behind the window and ignores the
    /// NSView appearance.
    var colorScheme: ColorScheme? {
        switch theme.appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// The glass tint, resolved for the system's current appearance or the
    /// forced mode: the glass keeps the colour it was given, so a dynamic
    /// colour would stay as it was when first applied.
    private var tintColor: NSColor {
        switch theme.appearance {
        case .system:
            var resolved = NSColor.windowBackgroundColor.withAlphaComponent(theme.glassTint)
            NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
                resolved = NSColor.windowBackgroundColor.withAlphaComponent(theme.glassTint).usingColorSpace(.sRGB) ?? resolved
            }
            return resolved
        case .light:
            return NSColor(white: 0.96, alpha: theme.glassTint)
        case .dark:
            return NSColor(white: 0.11, alpha: theme.glassTint)
        }
    }

    func update(_ theme: ThemeSettings) {
        guard theme != self.theme else { return }
        self.theme = theme
        applyToAll()
    }

    private func applyToAll() {
        windows.removeAll { $0.window() == nil }
        for entry in windows {
            apply(to: entry.window(), glass: entry.glass(), content: entry.content())
        }
    }

    /// Applies the theme now and on every later change. Held weakly.
    /// `content` is the view inside the glass: Liquid Glass adapts its
    /// content to what is behind the window, so a forced light/dark mode has
    /// to be set on the content itself, not only on the window.
    func register(_ window: NSWindow, glass: NSGlassEffectView? = nil, content: NSView? = nil) {
        windows.append((window: { [weak window] in window }, glass: { [weak glass] in glass }, content: { [weak content] in content }))
        apply(to: window, glass: glass, content: content)
    }

    private func apply(to window: NSWindow?, glass: NSGlassEffectView?, content: NSView?) {
        window?.appearance = appearance
        glass?.appearance = appearance
        content?.appearance = appearance
        glass?.tintColor = tintColor
    }
}

extension RGB {
    /// sRGB components of a SwiftUI color (nil if it can't be converted).
    init?(_ color: Color) {
        guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return nil }
        self.init(red: srgb.redComponent, green: srgb.greenComponent, blue: srgb.blueComponent)
    }
}

/// Gives a window's SwiftUI content the theme, and keeps the accent tint
/// live (the theme is read in `body`, so changes are observed).
struct ThemedRoot<Content: View>: View {
    let theme: ThemeController
    let content: Content

    var body: some View {
        if let scheme = theme.colorScheme {
            themed.environment(\.colorScheme, scheme)
        } else {
            themed
        }
    }

    private var themed: some View {
        content
            .tint(theme.accentColor)
            .environment(theme)
    }
}
