import Foundation

struct Note: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    /// 纯文本视图，用于列表预览、搜索与兼容旧数据。
    var content: String
    /// 富文本数据（NSKeyedArchiver 序列化的 NSAttributedString），可包含内嵌图片。
    /// 为空表示当前笔记只有纯文本。
    var richData: Data?
    var createdAt: Date
    var modifiedAt: Date
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        title: String = LanguageManager.shared.strings.untitledNote,
        content: String = "",
        richData: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.richData = richData
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.isPinned = false
    }
}
