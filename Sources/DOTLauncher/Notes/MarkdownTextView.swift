import AppKit
import DOTLauncherCore
import SwiftUI

/// A plain-text editor that styles Markdown as you type. The stored text
/// never changes; only its display attributes do.
struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    /// Hands out the text view so the window can focus it.
    var onCreate: (NSTextView) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false
        guard let textView = scroll.documentView as? NSTextView else { return scroll }

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 14, height: 12)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.font = Coordinator.bodyFont
        textView.typingAttributes = Coordinator.bodyAttributes
        textView.string = text
        Coordinator.restyle(textView)
        onCreate(textView)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView, textView.string != text else { return }
        textView.string = text
        Coordinator.restyle(textView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        static let bodyFont = NSFont.systemFont(ofSize: 14)
        static let monoFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        static let bodyAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: NSColor.labelColor]

        private let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
            Self.restyle(textView)
        }

        static func restyle(_ textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            storage.beginEditing()
            storage.setAttributes(bodyAttributes, range: NSRange(location: 0, length: storage.length))
            // Size and family first (heading, code), then traits and colors on top.
            let spans = MarkdownHighlighter.spans(in: storage.string).sorted { order($0.kind) < order($1.kind) }
            for span in spans {
                apply(span, to: storage)
            }
            storage.endEditing()
            textView.typingAttributes = bodyAttributes
        }

        private static func order(_ kind: MarkdownSpan.Kind) -> Int {
            switch kind {
            case .heading, .inlineCode, .codeBlock: 0
            case .bold, .italic: 1
            default: 2
            }
        }

        private static func apply(_ span: MarkdownSpan, to storage: NSTextStorage) {
            let range = span.range
            switch span.kind {
            case .heading(let level):
                let size: CGFloat = level == 1 ? 22 : level == 2 ? 18 : 16
                storage.addAttribute(.font, value: NSFont.systemFont(ofSize: size, weight: .bold), range: range)
            case .bold:
                convert(storage, range, to: .boldFontMask)
            case .italic:
                convert(storage, range, to: .italicFontMask)
            case .strikethrough:
                storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            case .inlineCode, .codeBlock:
                storage.addAttribute(.font, value: monoFont, range: range)
            case .link:
                storage.addAttribute(.foregroundColor, value: NSColor.linkColor, range: range)
            case .syntax, .listMarker, .task, .quote:
                storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: range)
            }
        }

        /// Adds a trait to whatever font each run already has.
        private static func convert(_ storage: NSTextStorage, _ range: NSRange, to trait: NSFontTraitMask) {
            storage.enumerateAttribute(.font, in: range) { value, run, _ in
                let font = (value as? NSFont) ?? bodyFont
                storage.addAttribute(.font, value: NSFontManager.shared.convert(font, toHaveTrait: trait), range: run)
            }
        }
    }
}
