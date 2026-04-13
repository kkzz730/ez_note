import SwiftUI

struct NoteEditorView: View {
    @Environment(\.locale) private var locale
    @EnvironmentObject private var languageManager: LanguageManager
    @Binding var note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider()
            editorSection
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(languageManager.strings.titlePlaceholder, text: $note.title)
                .font(.title.bold())
                .textFieldStyle(.plain)
                .onChange(of: note.title) { _, _ in
                    note.modifiedAt = Date()
                }

            HStack(spacing: 16) {
                Label(formatDate(note.createdAt), systemImage: "calendar")
                Label(formatDate(note.modifiedAt), systemImage: "clock")
                if note.isPinned {
                    Label(languageManager.strings.pinnedState, systemImage: "pin.fill")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

        }
        .padding()
    }

    // MARK: - Editor

    private var editorSection: some View {
        TextEditor(text: $note.content)
            .font(.body)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .onChange(of: note.content) { _, _ in
                note.modifiedAt = Date()
            }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
