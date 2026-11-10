import Foundation

public enum ThemePreset: String, Codable, Sendable, CaseIterable {
    case standard, midnight, paper, sunset, graphite, custom

    public var title: String {
        switch self {
        case .standard: "Default"
        case .midnight: "Midnight"
        case .paper: "Paper"
        case .sunset: "Sunset"
        case .graphite: "Graphite"
        case .custom: "Custom"
        }
    }
}

public enum AppearanceMode: String, Codable, Sendable, CaseIterable {
    case system, light, dark
}

/// An sRGB color with components in 0...1.
public struct RGB: Codable, Sendable, Equatable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// "#RRGGBB" or "RRGGBB".
    public init?(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    public var hex: String {
        func byte(_ component: Double) -> Int { Int((min(max(component, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }
}

/// The look of PACE's windows. Applying a preset fills every value; editing
/// a value makes the theme "Custom".
public struct ThemeSettings: Codable, Sendable, Equatable {
    public private(set) var preset: ThemePreset
    /// nil follows the system accent color.
    public private(set) var accent: RGB?
    /// How much of the window background tints the glass, 0...0.9.
    public private(set) var glassTint: Double
    public private(set) var appearance: AppearanceMode

    public init(preset: ThemePreset = .standard) {
        self.preset = .standard
        accent = nil
        glassTint = 0.6
        appearance = .system
        apply(preset)
    }

    public mutating func apply(_ preset: ThemePreset) {
        guard preset != .custom else {
            self.preset = .custom
            return
        }
        let values = Self.values(for: preset)
        self.preset = preset
        accent = values.accent
        glassTint = values.glassTint
        appearance = values.appearance
    }

    public mutating func setAccent(_ rgb: RGB?) {
        accent = rgb
        preset = .custom
    }

    public mutating func setGlassTint(_ value: Double) {
        glassTint = min(max(value, 0), 0.9)
        preset = .custom
    }

    public mutating func setAppearance(_ mode: AppearanceMode) {
        appearance = mode
        preset = .custom
    }

    private static func values(for preset: ThemePreset) -> (accent: RGB?, glassTint: Double, appearance: AppearanceMode) {
        switch preset {
        case .standard, .custom: (nil, 0.6, .system)
        case .midnight: (RGB(hex: "#5E8BFF"), 0.8, .dark)
        case .paper: (RGB(hex: "#B5652E"), 0.75, .light)
        case .sunset: (RGB(hex: "#FF6B4A"), 0.5, .system)
        case .graphite: (RGB(hex: "#8E8E93"), 0.85, .system)
        }
    }

    // Tolerant decoding: missing keys fall back to the preset's values.
    private enum CodingKeys: String, CodingKey { case preset, accent, glassTint, appearance }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let preset = (try? container.decodeIfPresent(ThemePreset.self, forKey: .preset)) ?? .standard
        self.init(preset: preset)
        if let accent = try? container.decodeIfPresent(RGB.self, forKey: .accent) { self.accent = accent }
        if let tint = try? container.decodeIfPresent(Double.self, forKey: .glassTint) { glassTint = min(max(tint, 0), 0.9) }
        if let mode = try? container.decodeIfPresent(AppearanceMode.self, forKey: .appearance) { appearance = mode }
    }
}
