import AppKit

enum InAppShortcutSettings {
    static func open() {
        NSApp.activate(ignoringOtherApps: true)

        let mains = NSApp.windows.filter { !($0 is NSPanel) }
        if let w = mains.first {
            if w.isMiniaturized { w.deminiaturize(nil) }
            w.makeKeyAndOrderFront(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NotificationCenter.default.post(name: .eznoteOpenShortcutSettings, object: nil)
            }
        } else {
            NotificationCenter.default.post(name: .eznoteOpenMainWindow, object: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                NotificationCenter.default.post(name: .eznoteOpenShortcutSettings, object: nil)
            }
        }
    }
}
