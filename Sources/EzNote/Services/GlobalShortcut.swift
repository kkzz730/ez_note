import AppKit

/// 全局快捷键（持久化到 UserDefaults）。至少需含一个修饰键，避免无修饰键误触全局输入。
struct GlobalShortcut: Equatable {
    var keyCode: UInt16
    /// 仅使用 deviceIndependent 修饰位
    var modifierFlags: NSEvent.ModifierFlags

    /// 只比较这四个修饰键，忽略 Caps Lock、Fn 等，避免「按对了却不触发」。
    static let globalModifierMask: NSEvent.ModifierFlags = [.command, .control, .option, .shift]

    private static let keyCodeDefaults = "hotKeyKeyCode"
    private static let modifiersDefaults = "hotKeyModifiersRaw"

    static let `default` = GlobalShortcut(
        keyCode: 45, // N
        modifierFlags: [.command, .control]
    )

    static func load() -> GlobalShortcut {
        let d = UserDefaults.standard
        let code = d.object(forKey: keyCodeDefaults) as? Int
        let raw = d.object(forKey: modifiersDefaults) as? UInt
        if let code, let raw {
            let flags = NSEvent.ModifierFlags(rawValue: raw).intersection(globalModifierMask)
            let s = GlobalShortcut(keyCode: UInt16(code), modifierFlags: flags)
            if s.isValid { return s }
        }
        return .default
    }

    func save() {
        let d = UserDefaults.standard
        d.set(Int(keyCode), forKey: Self.keyCodeDefaults)
        d.set(modifierFlags.intersection(Self.globalModifierMask).rawValue, forKey: Self.modifiersDefaults)
    }

    var isValid: Bool {
        let f = modifierFlags.intersection(Self.globalModifierMask)
        let hasMod = f.contains(.command) || f.contains(.control) || f.contains(.option) || f.contains(.shift)
        return hasMod
    }

    func matches(_ event: NSEvent) -> Bool {
        let want = modifierFlags.intersection(Self.globalModifierMask)
        let got = event.modifierFlags.intersection(Self.globalModifierMask)
        return got == want && event.keyCode == keyCode
    }

    var displayString: String {
        var parts: [String] = []
        let f = modifierFlags.intersection(Self.globalModifierMask)
        if f.contains(.control) { parts.append("⌃") }
        if f.contains(.option) { parts.append("⌥") }
        if f.contains(.shift) { parts.append("⇧") }
        if f.contains(.command) { parts.append("⌘") }
        parts.append(Self.symbol(for: keyCode))
        return parts.joined()
    }

    private static func symbol(for keyCode: UInt16) -> String {
        LanguageManager.shared.strings.keySymbol(for: keyCode)
    }

    struct Preset: Identifiable {
        let id: String
        let title: String
        let shortcut: GlobalShortcut
    }

    /// 内置预设；“自定义”仅用于 UI，不参与相等匹配。
    static func presets(for language: AppLanguage) -> [Preset] {
        let l10n = LocalizedStrings(language: language)
        return [
            Preset(id: "cmd_ctrl_n", title: l10n.presetTitle(for: "cmd_ctrl_n"), shortcut: GlobalShortcut(keyCode: 45, modifierFlags: [.command, .control])),
            Preset(id: "cmd_shift_n", title: l10n.presetTitle(for: "cmd_shift_n"), shortcut: GlobalShortcut(keyCode: 45, modifierFlags: [.command, .shift])),
            Preset(id: "opt_space", title: l10n.presetTitle(for: "opt_space"), shortcut: GlobalShortcut(keyCode: 49, modifierFlags: [.option])),
            Preset(id: "ctrl_opt_n", title: l10n.presetTitle(for: "ctrl_opt_n"), shortcut: GlobalShortcut(keyCode: 45, modifierFlags: [.control, .option])),
            Preset(id: "cmd_opt_n", title: l10n.presetTitle(for: "cmd_opt_n"), shortcut: GlobalShortcut(keyCode: 45, modifierFlags: [.command, .option])),
            Preset(id: "cmd_ctrl_space", title: l10n.presetTitle(for: "cmd_ctrl_space"), shortcut: GlobalShortcut(keyCode: 49, modifierFlags: [.command, .control])),
            Preset(id: "custom", title: l10n.presetTitle(for: "custom"), shortcut: GlobalShortcut.default)
        ]
    }

    static func presetId(matching shortcut: GlobalShortcut) -> String {
        for p in presets(for: .english) where p.id != "custom" && p.shortcut == shortcut {
            return p.id
        }
        return "custom"
    }
}
