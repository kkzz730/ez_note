import Foundation
import Combine

final class NoteStore: ObservableObject {
    static let shared = NoteStore()

    @Published var notes: [Note] = []

    private let saveURL: URL
    private var autosaveCancellable: AnyCancellable?

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.appendingPathComponent("EzNote", isDirectory: true)

        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        saveURL = appSupport.appendingPathComponent("notes.json")

        load()

        autosaveCancellable = $notes
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.save()
            }
    }

    // MARK: - CRUD

    func addNote(title: String = LanguageManager.shared.strings.untitledNote, content: String = "") -> Note {
        let note = Note(title: title, content: content)
        notes.insert(note, at: 0)
        return note
    }

    func deleteNote(id: UUID) {
        notes.removeAll { $0.id == id }
    }

    func updateNote(id: UUID, mutate: (inout Note) -> Void) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        mutate(&notes[idx])
        notes[idx].modifiedAt = Date()
    }

    func togglePin(id: UUID) {
        updateNote(id: id) { $0.isPinned.toggle() }
    }

    func note(byID id: UUID) -> Note? {
        notes.first { $0.id == id }
    }

    // MARK: - Persistence

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(notes)
            try data.write(to: saveURL, options: .atomic)
        } catch {
            print("NoteStore: save failed - \(error)")
        }
    }

    func load() {
        guard FileManager.default.fileExists(atPath: saveURL.path) else {
            createWelcomeNote()
            return
        }
        do {
            let data = try Data(contentsOf: saveURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            notes = try decoder.decode([Note].self, from: data)
        } catch {
            print("NoteStore: load failed - \(error)")
            createWelcomeNote()
        }
    }

    private func createWelcomeNote() {
        let l10n = LanguageManager.shared.strings
        let _ = addNote(
            title: l10n.welcomeTitle,
            content: l10n.welcomeContent
        )
    }

    var sortedNotes: [Note] {
        notes.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.modifiedAt > b.modifiedAt
        }
    }
}
