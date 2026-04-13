import AppKit
import SwiftUI
import Combine

final class PanelManager: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = PanelManager()

    @Published var isVisible = false
    @Published var opacity: Double

    private var panel: FloatingPanel?
    private var cancellables = Set<AnyCancellable>()

    override init() {
        let saved = UserDefaults.standard.double(forKey: Constants.panelOpacityKey)
        self.opacity = saved >= 0.3 ? saved : Constants.defaultOpacity
        super.init()

        $opacity
            .dropFirst()
            .sink { [weak self] newValue in
                self?.panel?.alphaValue = CGFloat(newValue)
                UserDefaults.standard.set(newValue, forKey: Constants.panelOpacityKey)
            }
            .store(in: &cancellables)
    }

    func setupPanel() {
        let frame = restoreFrame()
        let panel = FloatingPanel(contentRect: frame)
        panel.delegate = self

        let contentView = FloatingNoteView()
            .environmentObject(NoteStore.shared)
            .environmentObject(self)
            .environmentObject(LanguageManager.shared)
            .environment(\.locale, LanguageManager.shared.language.locale)
            .background(.ultraThinMaterial)

        let hostingView = NSHostingView(rootView: contentView)
        panel.contentView = hostingView
        panel.alphaValue = CGFloat(opacity)

        self.panel = panel
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        panel?.alphaValue = CGFloat(opacity)
        panel?.orderFrontRegardless()
        isVisible = true
    }

    func hide() {
        saveFrame()
        panel?.orderOut(nil)
        isVisible = false
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        saveFrame()
        isVisible = false
    }

    func windowDidMove(_ notification: Notification) {
        saveFrame()
    }

    func windowDidResize(_ notification: Notification) {
        saveFrame()
    }

    // MARK: - Frame Persistence

    private func saveFrame() {
        guard let frame = panel?.frame else { return }
        let defaults = UserDefaults.standard
        defaults.set(frame.origin.x, forKey: Constants.panelFrameXKey)
        defaults.set(frame.origin.y, forKey: Constants.panelFrameYKey)
        defaults.set(frame.size.width, forKey: Constants.panelFrameWidthKey)
        defaults.set(frame.size.height, forKey: Constants.panelFrameHeightKey)
    }

    private func restoreFrame() -> NSRect {
        let defaults = UserDefaults.standard
        let w = defaults.double(forKey: Constants.panelFrameWidthKey)
        let h = defaults.double(forKey: Constants.panelFrameHeightKey)

        if w > 0 && h > 0 {
            let x = defaults.double(forKey: Constants.panelFrameXKey)
            let y = defaults.double(forKey: Constants.panelFrameYKey)
            return NSRect(x: x, y: y, width: w, height: h)
        }

        guard let screen = NSScreen.main else {
            return NSRect(
                x: 100, y: 100,
                width: Constants.defaultPanelWidth,
                height: Constants.defaultPanelHeight
            )
        }
        let x = screen.visibleFrame.maxX - Constants.defaultPanelWidth - 20
        let y = screen.visibleFrame.maxY - Constants.defaultPanelHeight - 20
        return NSRect(
            x: x, y: y,
            width: Constants.defaultPanelWidth,
            height: Constants.defaultPanelHeight
        )
    }
}
