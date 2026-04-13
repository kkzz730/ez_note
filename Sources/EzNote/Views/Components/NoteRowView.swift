import SwiftUI

struct NoteRowView: View {
    @Environment(\.locale) private var locale
    @EnvironmentObject private var languageManager: LanguageManager
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Text(note.title)
                    .font(.headline)
                    .lineLimit(1)
            }

            Text(note.content.isEmpty ? languageManager.strings.blankNote : note.content)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(relativeDate(note.modifiedAt))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func relativeDate(_ date: Date) -> String {
        let now = Date()
        // 避免 modifiedAt 略晚于「当前时刻」时，英文相对时间误用 “in …”（未来时态）。
        let anchor = min(date, now)
        let secondsAgo = now.timeIntervalSince(anchor)
        if secondsAgo < 1 {
            return languageManager.strings.relativeModifiedJustNow
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: anchor, relativeTo: now)
    }
}
