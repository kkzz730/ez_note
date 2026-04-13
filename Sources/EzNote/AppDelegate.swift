import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        PanelManager.shared.setupPanel()

        HotKeyManager.shared.setPanelToggleHandler {
            PanelManager.shared.toggle()
        }

        // 从 Finder / 应用程序 启动时，SwiftUI 主窗口有时不会自动前置，延迟激活一次
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where !(window is NSPanel) {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let mains = NSApp.windows.filter { !($0 is NSPanel) }
        if mains.isEmpty {
            NotificationCenter.default.post(name: .eznoteOpenMainWindow, object: nil)
        } else {
            for window in mains {
                if window.isMiniaturized { window.deminiaturize(nil) }
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        NoteStore.shared.save()
    }

}
