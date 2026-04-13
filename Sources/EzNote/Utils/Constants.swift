import Foundation

extension Notification.Name {
    /// 从 Dock 点击图标且没有主窗口时，由菜单栏场景响应并 `openWindow()`。
    static let eznoteOpenMainWindow = Notification.Name("com.eznote.openMainWindow")
    /// 打开主窗口内的快捷键设置表单（应用内，非系统设置）。
    static let eznoteOpenShortcutSettings = Notification.Name("com.eznote.openShortcutSettings")
}

enum Constants {
    static let appName = "EzNote"
    static let appLanguageKey = "appLanguage"
    static let lastSelectedNoteKey = "lastSelectedNoteID"
    static let panelOpacityKey = "panelOpacity"
    static let panelFrameXKey = "panelFrameX"
    static let panelFrameYKey = "panelFrameY"
    static let panelFrameWidthKey = "panelFrameWidth"
    static let panelFrameHeightKey = "panelFrameHeight"
    static let defaultPanelWidth: CGFloat = 320
    static let defaultPanelHeight: CGFloat = 420
    static let defaultOpacity: Double = 0.95
}
