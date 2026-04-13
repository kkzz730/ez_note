import SwiftUI

struct MainView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var languageManager: LanguageManager

    @State private var selectedNoteID: UUID?
    @State private var searchText = ""
    @State private var noteToDelete: Note?
    @State private var showDeleteAlert = false
    @State private var showShortcutSettings = false

    private var filteredNotes: [Note] {
        let sorted = store.notes.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.modifiedAt > b.modifiedAt
        }
        if searchText.isEmpty { return sorted }
        return sorted.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var pinnedNotes: [Note] {
        filteredNotes.filter { $0.isPinned }
    }

    private var unpinnedNotes: [Note] {
        filteredNotes.filter { !$0.isPinned }
    }

    var body: some View {
        let l10n = languageManager.strings

        NavigationSplitView {
            NoteListView(
                pinnedNotes: pinnedNotes,
                unpinnedNotes: unpinnedNotes,
                selectedNoteID: $selectedNoteID,
                onTogglePin: { store.togglePin(id: $0.id) },
                onRequestDelete: { note in
                    noteToDelete = note
                    showDeleteAlert = true
                }
            )
            .searchable(text: $searchText, prompt: l10n.searchNotes)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: createNote) {
                        Label(l10n.newNote, systemImage: "square.and.pencil")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(l10n.shortcutSettings) {
                            showShortcutSettings = true
                        }

                        Divider()

                        Picker(l10n.languageTitle, selection: $languageManager.language) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                    } label: {
                        Label(l10n.settings, systemImage: "gearshape")
                    }
                }
            }
        } detail: {
            Group {
                if let id = selectedNoteID,
                   let idx = store.notes.firstIndex(where: { $0.id == id }) {
                    NoteEditorView(note: $store.notes[idx])
                } else {
                    EmptyStateView(onCreateNote: createNote)
                }
            }
        }
        .navigationTitle("")
        .alert(l10n.confirmDelete, isPresented: $showDeleteAlert, presenting: noteToDelete) { note in
            Button(l10n.cancel, role: .cancel) {}
            Button(l10n.delete, role: .destructive) {
                if selectedNoteID == note.id {
                    selectedNoteID = nil
                }
                store.deleteNote(id: note.id)
            }
        } message: { note in
            Text(l10n.deleteMessage(noteTitle: note.title))
        }
        .sheet(isPresented: $showShortcutSettings) {
            NavigationStack {
                ShortcutSettingsView()
                    .navigationTitle(l10n.shortcutWindowTitle)
            }
            .frame(minWidth: 440, minHeight: 420)
        }
        .onReceive(NotificationCenter.default.publisher(for: .eznoteOpenShortcutSettings)) { _ in
            showShortcutSettings = true
        }
    }

    private func createNote() {
        let note = store.addNote()
        selectedNoteID = note.id
    }
}
