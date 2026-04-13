import AppKit
import Carbon

final class HotKeyManager {
    static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var panelToggleHandler: (() -> Void)?
    private var eventHandler: EventHandlerRef?

    private static let hotKeyID = EventHotKeyID(
        signature: OSType(0x455A4E54), // "EZNT"
        id: 1
    )

    func setPanelToggleHandler(_ handler: @escaping () -> Void) {
        panelToggleHandler = handler
        reinstall()
    }

    func reloadFromSavedShortcut() {
        reinstall()
    }

    private func reinstall() {
        unregister()
        guard panelToggleHandler != nil else { return }

        let shortcut = GlobalShortcut.load()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let mgr = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if hotKeyID.id == HotKeyManager.hotKeyID.id {
                    DispatchQueue.main.async {
                        mgr.panelToggleHandler?()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )

        var carbonMods: UInt32 = 0
        let flags = shortcut.modifierFlags
        if flags.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if flags.contains(.control) { carbonMods |= UInt32(controlKey) }
        if flags.contains(.option)  { carbonMods |= UInt32(optionKey) }
        if flags.contains(.shift)   { carbonMods |= UInt32(shiftKey) }

        let keyID = HotKeyManager.hotKeyID
        RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            carbonMods,
            keyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
}
