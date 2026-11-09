import AppKit
import SwiftUI

/// An AppKit text field. Unlike a SwiftUI TextField it can be made first
/// responder deterministically on every show, and it hands us ↑ ↓ ⏎ ⎋ as
/// editing commands without any event monitors.
struct SearchField: NSViewRepresentable {
    let model: LauncherModel
    let placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 22, weight: .regular)
        field.placeholderString = placeholder
        field.cell?.lineBreakMode = .byTruncatingTail
        field.cell?.isScrollable = true
        field.delegate = context.coordinator
        model.searchField = field
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != model.query {
            field.stringValue = model.query
        }
        if field.placeholderString != placeholder {
            field.placeholderString = placeholder
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let model: LauncherModel

        init(model: LauncherModel) {
            self.model = model
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            model.query = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.moveUp(_:)):
                model.moveSelection(by: -1)
            case #selector(NSResponder.moveDown(_:)):
                model.moveSelection(by: 1)
            case #selector(NSResponder.insertNewline(_:)):
                model.performSelected()
            case #selector(NSResponder.cancelOperation(_:)):
                model.escape()
            case #selector(NSResponder.insertTab(_:)):
                // Tab sends the query to AI Chat from root; elsewhere it
                // does nothing (there is no other control to focus).
                model.onTab?()
            default:
                return false
            }
            return true
        }
    }
}
