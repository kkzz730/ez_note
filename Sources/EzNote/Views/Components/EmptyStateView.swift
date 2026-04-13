import SwiftUI

struct EmptyStateView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    var onCreateNote: (() -> Void)?

    var body: some View {
        let l10n = languageManager.strings

        VStack(spacing: 16) {
            Image(systemName: "note.text.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(.quaternary)

            Text(l10n.selectNoteToStart)
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(l10n.orCreateNewNote)
                .font(.callout)
                .foregroundStyle(.tertiary)

            if let action = onCreateNote {
                Button(action: action) {
                    Label(l10n.newNote, systemImage: "plus")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
