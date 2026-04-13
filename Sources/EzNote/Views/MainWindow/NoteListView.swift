import SwiftUI

struct NoteListView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    let pinnedNotes: [Note]
    let unpinnedNotes: [Note]
    @Binding var selectedNoteID: UUID?
    var onTogglePin: (Note) -> Void
    var onRequestDelete: (Note) -> Void

    var body: some View {
        let l10n = languageManager.strings

        List(selection: $selectedNoteID) {
            if !pinnedNotes.isEmpty {
                Section(l10n.pinned) {
                    ForEach(pinnedNotes) { note in
                        NoteRowView(note: note)
                            .tag(note.id)
                            .contextMenu { contextMenu(for: note) }
                    }
                }
            }

            Section(pinnedNotes.isEmpty ? l10n.allNotes : l10n.otherNotes) {
                if unpinnedNotes.isEmpty && pinnedNotes.isEmpty {
                    Text(l10n.noNotes)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    ForEach(unpinnedNotes) { note in
                        NoteRowView(note: note)
                            .tag(note.id)
                            .contextMenu { contextMenu(for: note) }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func contextMenu(for note: Note) -> some View {
        let l10n = languageManager.strings

        Button {
            onTogglePin(note)
        } label: {
            Label(
                note.isPinned ? l10n.unpin : l10n.pinned,
                systemImage: note.isPinned ? "pin.slash" : "pin"
            )
        }

        Divider()

        Button(role: .destructive) {
            onRequestDelete(note)
        } label: {
            Label(l10n.delete, systemImage: "trash")
        }
    }
}
