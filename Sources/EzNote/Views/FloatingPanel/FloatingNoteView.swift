import SwiftUI

struct FloatingNoteView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var panelManager: PanelManager
    @EnvironmentObject var languageManager: LanguageManager

    @State private var selectedNoteID: UUID?
    @State private var editingContent: String = ""
    @State private var showDeleteAlert = false

    private var selectedNote: Note? {
        if let id = selectedNoteID {
            return store.notes.first { $0.id == id }
        }
        return store.notes.first
    }

    var body: some View {
        let l10n = languageManager.strings

        VStack(spacing: 0) {
            headerBar
            Divider()
            editorArea
            Divider()
            opacityBar
        }
        .frame(minWidth: 260, minHeight: 280)
        .onAppear {
            restoreLastSelection()
            syncContent()
        }
        .onChange(of: selectedNoteID) { _, _ in
            syncContent()
            if let id = selectedNoteID {
                UserDefaults.standard.set(id.uuidString, forKey: Constants.lastSelectedNoteKey)
            }
        }
        .alert(l10n.confirmDelete, isPresented: $showDeleteAlert) {
            Button(l10n.cancel, role: .cancel) {}
            Button(l10n.delete, role: .destructive) {
                deleteCurrentNote()
            }
        } message: {
            Text(l10n.deleteMessage(noteTitle: selectedNote?.title ?? ""))
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        let l10n = languageManager.strings

        return HStack(spacing: 8) {
            Picker("", selection: $selectedNoteID) {
                if store.notes.isEmpty {
                    Text(l10n.noNoteSelected).tag(nil as UUID?)
                }
                ForEach(store.notes) { note in
                    Text(note.title)
                        .lineLimit(1)
                        .tag(note.id as UUID?)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)

            Button(action: createNote) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help(l10n.createNoteHelp)

            Button {
                if selectedNote != nil {
                    showDeleteAlert = true
                }
            } label: {
                Image(systemName: "trash")
                    .font(.title3)
                    .foregroundStyle(selectedNote != nil ? .red : .gray)
            }
            .buttonStyle(.plain)
            .disabled(selectedNote == nil)
            .help(l10n.deleteCurrentNoteHelp)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Editor

    private var editorArea: some View {
        let l10n = languageManager.strings

        return Group {
            if selectedNote != nil {
                TextEditor(text: $editingContent)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .onChange(of: editingContent) { _, newValue in
                        guard let id = selectedNoteID ?? store.notes.first?.id else { return }
                        store.updateNote(id: id) { $0.content = newValue }
                    }
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "note.text")
                        .font(.system(size: 36))
                        .foregroundStyle(.quaternary)
                    Text(l10n.createFirstNote)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Opacity

    private var opacityBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "sun.min")
                .foregroundStyle(.secondary)
                .font(.caption2)
            Slider(value: $panelManager.opacity, in: 0.3...1.0, step: 0.05)
                .controlSize(.mini)
            Image(systemName: "sun.max")
                .foregroundStyle(.secondary)
                .font(.caption2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func createNote() {
        let note = store.addNote()
        selectedNoteID = note.id
        editingContent = note.content
    }

    private func deleteCurrentNote() {
        guard let id = selectedNoteID ?? store.notes.first?.id else { return }
        let currentIndex = store.notes.firstIndex(where: { $0.id == id })
        store.deleteNote(id: id)

        if let idx = currentIndex {
            if idx < store.notes.count {
                selectedNoteID = store.notes[idx].id
            } else if let last = store.notes.last {
                selectedNoteID = last.id
            } else {
                selectedNoteID = nil
            }
        }
        syncContent()
    }

    private func syncContent() {
        editingContent = selectedNote?.content ?? ""
    }

    private func restoreLastSelection() {
        if let idString = UserDefaults.standard.string(forKey: Constants.lastSelectedNoteKey),
           let id = UUID(uuidString: idString),
           store.notes.contains(where: { $0.id == id }) {
            selectedNoteID = id
        } else if let first = store.notes.first {
            selectedNoteID = first.id
        }
    }
}
