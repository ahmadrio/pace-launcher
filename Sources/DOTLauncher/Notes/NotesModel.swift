import DOTLauncherCore
import Foundation
import Observation

/// The note being edited and the list of notes. Saves 0.5 s after typing
/// stops, and immediately when switching notes or closing the window.
@Observable
final class NotesModel {
    private(set) var summaries: [NoteSummary] = []
    private(set) var currentID: UUID?
    var body = "" {
        didSet {
            guard body != oldValue, !isLoading else { return }
            scheduleSave()
        }
    }
    /// Shows the ⌘P switcher, and what it is filtered by.
    var showingSwitcher = false {
        didSet { if !showingSwitcher { switcherQuery = "" } }
    }
    var switcherQuery = ""
    /// First ⌃X / Delete press seen; the next one deletes.
    private(set) var deleteArmed = false

    @ObservationIgnored private let store: NoteStore
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var isLoading = false
    @ObservationIgnored private var confirmation = PressConfirmation()

    init(store: NoteStore) {
        self.store = store
        reloadList()
    }

    var title: String { NoteTitle.title(for: body) }

    func reloadList() {
        do {
            summaries = try store.list()
        } catch {
            Log.app.error("could not list notes: \(String(describing: error), privacy: .public)")
        }
    }

    func open(_ id: UUID) {
        flush()
        currentID = id
        load((try? store.load(id)) ?? "")
    }

    func openLatest() {
        reloadList()
        if let latest = summaries.first {
            open(latest.id)
        } else {
            createNew()
        }
    }

    func createNew() {
        flush()
        currentID = UUID()
        load("")
    }

    /// Saves now. A blank note is removed rather than saved.
    func flush() {
        saveTask?.cancel()
        saveTask = nil
        // Never drop typed text: text without a note becomes a new note.
        if currentID == nil, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            currentID = UUID()
        }
        guard let id = currentID else { return }
        do {
            try store.save(id, body: body)
        } catch {
            Log.app.error("could not save note: \(String(describing: error), privacy: .public)")
        }
        reloadList()
    }

    /// ⌃X on the open note: the first press arms, the second moves it to
    /// the Trash and opens the next most recent note.
    func requestTrashCurrent() {
        guard let id = currentID else { return }
        guard confirmation.press(id.uuidString, at: .now) else {
            deleteArmed = true
            return
        }
        trash(id)
    }

    /// Moves a note to the Trash (from the launcher or the window). When it
    /// is the open note, the next most recent one (or a new one) opens, so
    /// the editor always has a note to save into.
    func trash(_ id: UUID) {
        let wasCurrent = id == currentID
        if wasCurrent {
            flush()
            // Clear the editor too, or the next flush would save the
            // trashed text again as a new note.
            currentID = nil
            load("")
        }
        do {
            try store.trash(id)
        } catch {
            Log.app.error("could not trash note: \(String(describing: error), privacy: .public)")
        }
        if wasCurrent {
            openLatest()
        } else {
            reloadList()
        }
    }

    func body(of id: UUID) -> String {
        (try? store.load(id)) ?? ""
    }

    private func load(_ text: String) {
        isLoading = true
        body = text
        isLoading = false
        deleteArmed = false
        confirmation.reset()
    }

    private func scheduleSave() {
        deleteArmed = false
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            flush()
        }
    }
}
