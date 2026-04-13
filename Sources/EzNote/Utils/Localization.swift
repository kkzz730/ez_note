import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var displayName: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        }
    }

    static func initialValue() -> AppLanguage {
        let defaults = UserDefaults.standard
        if let rawValue = defaults.string(forKey: Constants.appLanguageKey),
           let language = AppLanguage(rawValue: rawValue) {
            return language
        }

        if let preferred = Locale.preferredLanguages.first,
           preferred.lowercased().hasPrefix("zh") {
            return .simplifiedChinese
        }
        return .english
    }
}

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Constants.appLanguageKey)
        }
    }

    private init() {
        language = AppLanguage.initialValue()
    }

    var strings: LocalizedStrings {
        LocalizedStrings(language: language)
    }
}

struct LocalizedStrings {
    let language: AppLanguage

    var settings: String { text(zh: "设置", en: "Settings") }
    var shortcutsAndLanguage: String { text(zh: "快捷键与语言", en: "Shortcuts & Language") }
    var shortcutSettings: String { text(zh: "快捷键设置…", en: "Shortcut Settings…") }
    var toggleFloatingPanel: String { text(zh: "切换悬浮面板", en: "Toggle Floating Panel") }
    var modifyShortcutsInApp: String { text(zh: "打开设置…", en: "Open Settings…") }
    var openMainWindow: String { text(zh: "打开主窗口", en: "Open Main Window") }
    var quitEzNote: String { text(zh: "退出 EzNote", en: "Quit EzNote") }
    var newNote: String { text(zh: "新建笔记", en: "New Note") }
    var searchNotes: String { text(zh: "搜索笔记...", en: "Search notes...") }
    var confirmDelete: String { text(zh: "确认删除", en: "Delete Note") }
    var cancel: String { text(zh: "取消", en: "Cancel") }
    var delete: String { text(zh: "删除", en: "Delete") }
    var noNotes: String { text(zh: "没有笔记", en: "No notes") }
    var allNotes: String { text(zh: "所有笔记", en: "All Notes") }
    var otherNotes: String { text(zh: "其他笔记", en: "Other Notes") }
    var pinned: String { text(zh: "置顶", en: "Pinned") }
    var unpin: String { text(zh: "取消置顶", en: "Unpin") }
    var blankNote: String { text(zh: "空白笔记", en: "Empty note") }
    /// 列表行「上次修改」在极短时间内的友好文案（避免系统相对时间出现 “in 0 sec” 等怪字）
    var relativeModifiedJustNow: String { text(zh: "刚刚", en: "Just now") }
    var selectNoteToStart: String { text(zh: "选择一个笔记开始编辑", en: "Select a note to start editing") }
    var orCreateNewNote: String { text(zh: "或创建一个新笔记", en: "Or create a new note") }
    var titlePlaceholder: String { text(zh: "标题", en: "Title") }
    var pinnedState: String { text(zh: "已置顶", en: "Pinned") }
    var createFirstNote: String { text(zh: "点击 + 创建第一个笔记", en: "Click + to create your first note") }
    var noNoteSelected: String { text(zh: "无笔记", en: "No Notes") }
    var createNoteHelp: String { text(zh: "新建笔记", en: "Create Note") }
    var deleteCurrentNoteHelp: String { text(zh: "删除当前笔记", en: "Delete Current Note") }
    var shortcutWindowTitle: String { text(zh: "EzNote · 设置", en: "EzNote · Settings") }
    var shortcutSectionTitle: String { text(zh: "切换悬浮面板 · 全局快捷键", en: "Toggle Floating Panel · Global Shortcut") }
    var shortcutSectionDescription: String { text(zh: "以下快捷键在任意 App 前台时都可切换悬浮面板。", en: "The shortcut below can toggle the floating panel from any app.") }
    var preset: String { text(zh: "预设", en: "Preset") }
    var customCombination: String { text(zh: "自定义组合", en: "Custom Combination") }
    var key: String { text(zh: "按键", en: "Key") }
    var save: String { text(zh: "保存", en: "Save") }
    var languageTitle: String { text(zh: "语言", en: "Language") }
    var languageDescription: String { text(zh: "切换应用界面的显示语言。", en: "Choose the display language for the app interface.") }
    var languageQuickSwitch: String { text(zh: "界面语言", en: "Interface Language") }
    var switchToChinese: String { text(zh: "切换为简体中文", en: "Switch to Simplified Chinese") }
    var switchToEnglish: String { text(zh: "切换为 English", en: "Switch to English") }
    var atLeastOneModifier: String { text(zh: "请至少勾选一项修饰键（⌘ / ⌃ / ⌥ / ⇧）。", en: "Select at least one modifier key (⌘ / ⌃ / ⌥ / ⇧).") }
    var untitledNote: String { text(zh: "未命名笔记", en: "Untitled Note") }
    var welcomeTitle: String { text(zh: "欢迎使用 EzNote", en: "Welcome to EzNote") }
    var shortcutMenuCommand: String { text(zh: "EzNote 设置…", en: "EzNote Settings…") }

    func deleteMessage(noteTitle: String) -> String {
        switch language {
        case .simplifiedChinese:
            return "确定要删除「\(noteTitle)」吗？此操作不可撤销。"
        case .english:
            return "Delete \"\(noteTitle)\"? This action cannot be undone."
        }
    }

    var welcomeContent: String {
        switch language {
        case .simplifiedChinese:
            return """
            这是你的第一个笔记！

            按 ⌘⌃N 可以随时呼出/隐藏悬浮面板。

            试试以下功能：
            • 新建笔记
            • 置顶重要笔记
            • 调节面板透明度
            • 搜索笔记内容

            在菜单栏点击 EzNote 图标可以打开主窗口管理所有笔记。

            修改快捷键和语言：主窗口右上角「设置」，或菜单栏中的「在 EzNote 内修改快捷键…」，或按 ⌘,。
            """
        case .english:
            return """
            This is your first note.

            Press ⌘⌃N to show or hide the floating panel at any time.

            Try these features:
            • Create notes
            • Pin important notes
            • Adjust panel opacity
            • Search note content

            Click the EzNote menu bar icon to open the main window and manage all notes.

            To change the shortcut or app language, open Settings from the toolbar, the menu bar, or press ⌘,.
            """
        }
    }

    func presetTitle(for id: String) -> String {
        switch id {
        case "cmd_ctrl_n":
            return text(zh: "⌘⌃N（默认）", en: "⌘⌃N (Default)")
        case "cmd_shift_n":
            return "⌘⇧N"
        case "opt_space":
            return language == .simplifiedChinese ? "⌥空格" : "⌥Space"
        case "ctrl_opt_n":
            return "⌃⌥N"
        case "cmd_opt_n":
            return "⌘⌥N"
        case "cmd_ctrl_space":
            return language == .simplifiedChinese ? "⌘⌃空格" : "⌘⌃Space"
        case "custom":
            return text(zh: "自定义…", en: "Custom…")
        default:
            return id
        }
    }

    func keySymbol(for keyCode: UInt16) -> String {
        switch keyCode {
        case 49:
            return language == .simplifiedChinese ? "空格" : "Space"
        case 36:
            return "↩"
        case 48:
            return "⇥"
        case 53:
            return "⎋"
        case 45:
            return "N"
        case 12:
            return "Q"
        case 13:
            return "W"
        case 14:
            return "E"
        case 15:
            return "R"
        case 16:
            return "Y"
        case 17:
            return "T"
        case 31:
            return "O"
        case 32:
            return "U"
        case 34:
            return "I"
        case 35:
            return "P"
        case 37:
            return "L"
        case 38:
            return "J"
        case 40:
            return "K"
        case 0:
            return "A"
        case 1:
            return "S"
        case 2:
            return "D"
        case 3:
            return "F"
        case 4:
            return "H"
        case 5:
            return "G"
        case 6:
            return "Z"
        case 7:
            return "X"
        case 8:
            return "C"
        case 9:
            return "V"
        case 11:
            return "B"
        case 46:
            return "M"
        case 18:
            return "1"
        case 19:
            return "2"
        case 20:
            return "3"
        case 21:
            return "4"
        case 23:
            return "5"
        case 22:
            return "6"
        case 26:
            return "7"
        case 28:
            return "8"
        case 25:
            return "9"
        case 29:
            return "0"
        default:
            return language == .simplifiedChinese ? "键码\(keyCode)" : "Key \(keyCode)"
        }
    }

    var selectableKeys: [(UInt16, String)] {
        let baseCodes: [UInt16] = [
            45, 12, 13, 14, 15, 16, 17,
            31, 32, 34, 35, 37, 38, 40,
            0, 1, 2, 3, 4, 5, 6, 7,
            8, 9, 11, 46, 49
        ]
        return baseCodes.map { ($0, keySymbol(for: $0)) }
    }

    private func text(zh: String, en: String) -> String {
        language == .simplifiedChinese ? zh : en
    }
}
