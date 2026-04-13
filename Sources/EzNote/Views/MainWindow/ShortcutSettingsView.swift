import AppKit
import SwiftUI

struct ShortcutSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: LanguageManager

    @State private var presetId: String
    @State private var customKeyCode: UInt16
    @State private var useCommand: Bool
    @State private var useControl: Bool
    @State private var useOption: Bool
    @State private var useShift: Bool
    @State private var errorMessage: String?

    init() {
        let loaded = GlobalShortcut.load()
        _presetId = State(initialValue: GlobalShortcut.presetId(matching: loaded))
        _customKeyCode = State(initialValue: loaded.keyCode)
        let f = loaded.modifierFlags.intersection(GlobalShortcut.globalModifierMask)
        _useCommand = State(initialValue: f.contains(.command))
        _useControl = State(initialValue: f.contains(.control))
        _useOption = State(initialValue: f.contains(.option))
        _useShift = State(initialValue: f.contains(.shift))
    }

    var body: some View {
        let l10n = languageManager.strings

        VStack(alignment: .leading, spacing: 16) {
            Text(l10n.shortcutSectionTitle)
                .font(.headline)

            Text(l10n.shortcutSectionDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker(l10n.preset, selection: $presetId) {
                ForEach(GlobalShortcut.presets(for: languageManager.language)) { item in
                    Text(item.title).tag(item.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.radioGroup)

            if presetId == "custom" {
                GroupBox(l10n.customCombination) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("⌘ Command", isOn: $useCommand)
                        Toggle("⌃ Control", isOn: $useControl)
                        Toggle("⌥ Option", isOn: $useOption)
                        Toggle("⇧ Shift", isOn: $useShift)

                        Picker(l10n.key, selection: $customKeyCode) {
                            ForEach(languageManager.strings.selectableKeys, id: \.0) { pair in
                                Text(pair.1).tag(pair.0)
                            }
                        }
                        .frame(maxWidth: 220)
                    }
                    .padding(8)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button(l10n.cancel) { dismiss() }
                Spacer()
                Button(l10n.save) { save() }
                    .keyboardShortcut(.defaultAction)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.languageTitle)
                    .font(.headline)

                Text(l10n.languageDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker(l10n.languageTitle, selection: $languageManager.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
        .onChange(of: presetId) { _, newValue in
            if newValue != "custom", let p = GlobalShortcut.presets(for: languageManager.language).first(where: { $0.id == newValue }) {
                let s = p.shortcut
                customKeyCode = s.keyCode
                let f = s.modifierFlags.intersection(GlobalShortcut.globalModifierMask)
                useCommand = f.contains(.command)
                useControl = f.contains(.control)
                useOption = f.contains(.option)
                useShift = f.contains(.shift)
            }
            errorMessage = nil
        }
    }

    private func save() {
        let l10n = languageManager.strings
        let shortcut: GlobalShortcut
        if presetId == "custom" {
            var flags: NSEvent.ModifierFlags = []
            if useCommand { flags.insert(.command) }
            if useControl { flags.insert(.control) }
            if useOption { flags.insert(.option) }
            if useShift { flags.insert(.shift) }
            shortcut = GlobalShortcut(keyCode: customKeyCode, modifierFlags: flags)
        } else if presetId != "custom", let p = GlobalShortcut.presets(for: languageManager.language).first(where: { $0.id == presetId }) {
            shortcut = p.shortcut
        } else {
            shortcut = .default
        }

        guard shortcut.isValid else {
            errorMessage = l10n.atLeastOneModifier
            return
        }

        shortcut.save()
        HotKeyManager.shared.reloadFromSavedShortcut()
        dismiss()
    }
}
