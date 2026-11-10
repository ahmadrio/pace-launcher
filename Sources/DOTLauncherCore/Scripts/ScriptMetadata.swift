import Foundation

public enum ScriptMode: String, Sendable {
    case fullOutput, compact, silent, inline
}

public struct ScriptDropdownItem: Sendable, Equatable, Decodable {
    public let title: String
    public let value: String

    public init(title: String, value: String) {
        self.title = title
        self.value = value
    }
}

public struct ScriptArgument: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case text
        case password
        case dropdown([ScriptDropdownItem])
    }

    public let kind: Kind
    public let placeholder: String
    public let optional: Bool
    public let percentEncoded: Bool

    /// The first field the keyboard can type into (text or password); nil
    /// when the form only has dropdowns.
    public static func firstTypingIndex(in arguments: [ScriptArgument]) -> Int? {
        arguments.firstIndex { argument in
            switch argument.kind {
            case .text, .password: true
            case .dropdown: false
            }
        }
    }
}

/// The comment header of a script command. Reads both the community
/// `@raycast.key value` convention and DOT's own `@dot.key value`.
public struct ScriptMetadata: Sendable, Equatable {
    public let title: String
    public let mode: ScriptMode
    public let packageName: String?
    public let icon: String?
    public let description: String?
    public let arguments: [ScriptArgument]
    public let currentDirectoryPath: String?
    public let needsConfirmation: Bool

    /// nil when the file has no title (it is not a script command).
    /// Only comment lines (`#` or `//`) in the first 60 lines are read;
    /// unknown keys and malformed arguments are ignored.
    public static func parse(_ source: String) -> ScriptMetadata? {
        var raycast: [String: String] = [:]
        var dot: [String: String] = [:]

        for line in source.split(separator: "\n", omittingEmptySubsequences: false).prefix(60) {
            var text = line.trimmingCharacters(in: .whitespaces)
            if text.hasPrefix("//") {
                text.removeFirst(2)
            } else if text.hasPrefix("#"), !text.hasPrefix("#!") {
                text.removeFirst()
            } else {
                continue
            }
            text = text.trimmingCharacters(in: .whitespaces)

            for (prefix, isDot) in [("@raycast.", false), ("@dot.", true)] where text.hasPrefix(prefix) {
                let rest = text.dropFirst(prefix.count)
                let key = String(rest.prefix { !$0.isWhitespace })
                let value = rest.dropFirst(key.count).trimmingCharacters(in: .whitespaces)
                guard !key.isEmpty else { continue }
                if isDot { dot[key] = value } else { raycast[key] = value }
            }
        }

        let fields = raycast.merging(dot) { _, dotValue in dotValue }
        guard let title = fields["title"], !title.isEmpty else { return nil }

        func optional(_ key: String) -> String? {
            fields[key].flatMap { $0.isEmpty ? nil : $0 }
        }

        let arguments = (1...3).compactMap { index in
            fields["argument\(index)"].flatMap(Self.argument)
        }

        return ScriptMetadata(
            title: title,
            mode: fields["mode"].flatMap(ScriptMode.init(rawValue:)) ?? .fullOutput,
            packageName: optional("packageName"),
            icon: optional("icon"),
            description: optional("description"),
            arguments: arguments,
            currentDirectoryPath: optional("currentDirectoryPath"),
            needsConfirmation: fields["needsConfirmation"]?.lowercased() == "true"
        )
    }

    private struct RawArgument: Decodable {
        let type: String?
        let placeholder: String?
        let optional: Bool?
        let percentEncoded: Bool?
        let data: [ScriptDropdownItem]?
    }

    private static func argument(_ json: String) -> ScriptArgument? {
        guard let raw = try? JSONDecoder().decode(RawArgument.self, from: Data(json.utf8)) else { return nil }
        let kind: ScriptArgument.Kind = switch raw.type {
        case "password": .password
        case "dropdown": .dropdown(raw.data ?? [])
        default: .text
        }
        return ScriptArgument(
            kind: kind,
            placeholder: raw.placeholder ?? "",
            optional: raw.optional ?? false,
            percentEncoded: raw.percentEncoded ?? false
        )
    }
}
