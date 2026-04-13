import SwiftUI

@main
struct EzNoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = NoteStore.shared
    @StateObject private var languageManager = LanguageManager.shared

    var body: some Scene {
        // WindowGroup 必须排在前面：从「应用程序」或 Dock 启动时才会自动出现主窗口
        WindowGroup(id: "main") {
            MainView()
                .environmentObject(store)
                .environmentObject(languageManager)
                .environment(\.locale, languageManager.language.locale)
        }
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(languageManager.strings.shortcutMenuCommand) {
                    InAppShortcutSettings.open()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        MenuBarExtra("EzNote", systemImage: "note.text") {
            MenuBarContentView()
                .environmentObject(languageManager)
                .environment(\.locale, languageManager.language.locale)
        }
    }
}

struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        let l10n = languageManager.strings

        VStack(alignment: .leading, spacing: 0) {
            Button(l10n.toggleFloatingPanel) {
                PanelManager.shared.toggle()
            }

            Divider()

            Button {
                InAppShortcutSettings.open()
            } label: {
                Label(l10n.modifyShortcutsInApp, systemImage: "keyboard")
            }

            Menu(l10n.languageTitle) {
                Button(l10n.switchToChinese) {
                    languageManager.language = .simplifiedChinese
                }
                .disabled(languageManager.language == .simplifiedChinese)

                Button(l10n.switchToEnglish) {
                    languageManager.language = .english
                }
                .disabled(languageManager.language == .english)
            }

            Divider()

            Button(l10n.openMainWindow) {
                showOrOpenMainWindow()
            }

            Divider()

            Button(l10n.quitEzNote) {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .onReceive(NotificationCenter.default.publisher(for: .eznoteOpenMainWindow)) { _ in
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showOrOpenMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        let mains = NSApp.windows.filter { !($0 is NSPanel) }
        if let w = mains.first {
            if w.isMiniaturized { w.deminiaturize(nil) }
            w.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
    }
}
