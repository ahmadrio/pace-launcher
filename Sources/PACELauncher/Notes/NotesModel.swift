import PACELauncherCore
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

    /// Notes iCloud has not downloaded to this Mac yet.
    private(set) var downloadingCount = 0
    /// Called when placeholders are seen, to ask iCloud for them.
    @ObservationIgnored var onPlaceholders: (() -> Void)?

    @ObservationIgnored private var store: NoteStore
    /// The text last read from or written to disk for the open note.
    @ObservationIgnored private var savedBody = ""
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var isLoading = false
    @ObservationIgnored private var confirmation = PressConfirmation()

    init(store: NoteStore) {
        self.store = store
        reloadList()
    }

    var title: String { NoteTitle.title(for: body) }

    /// Points the model at another folder (sync turned on or off). Call
    /// `flush()` before the files move; the open note is re-read after.
    func switchStore(_ store: NoteStore) {
        saveTask?.cancel()
        saveTask = nil
        self.store = store
        if let id = currentID, let body = try? store.load(id) {
            load(body)
        }
        reloadList()
    }

    func reloadList() {
        do {
            summaries = try store.list()
        } catch {
            Log.app.error("could not list notes: \(String(describing: error), privacy: .public)")
        }
        downloadingCount = store.placeholders().count
        if downloadingCount > 0 { onPlaceholders?() }
        reloadOpenNoteIfChangedOnDisk()
    }

    /// Picks up edits made elsewhere (Files on iPhone, another editor),
    /// but never over typing that is not saved yet.
    private func reloadOpenNoteIfChangedOnDisk() {
        guard let id = currentID, saveTask == nil, body == savedBody,
              let disk = try? store.load(id), disk != body
        else { return }
        load(disk)
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
            savedBody = body
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
        savedBody = text
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
