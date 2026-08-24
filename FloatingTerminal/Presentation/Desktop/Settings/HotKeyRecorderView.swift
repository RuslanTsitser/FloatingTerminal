import AppKit
import SwiftUI
import Carbon

struct HotKeyRecorderView: NSViewRepresentable {
    let onRecord: (UInt32, UInt32) -> Void

    func makeNSView(context: Context) -> HotKeyRecorderControl {
        HotKeyRecorderControl(onRecord: onRecord)
    }

    func updateNSView(_ nsView: HotKeyRecorderControl, context: Context) {}
}

final class HotKeyRecorderControl: NSButton {
    private let onRecord: (UInt32, UInt32) -> Void

    init(onRecord: @escaping (UInt32, UInt32) -> Void) {
        self.onRecord = onRecord
        super.init(frame: .zero)
        title = "Record shortcut"
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(beginRecording)
    }

    required init?(coder: NSCoder) { nil }

    @objc private func beginRecording() {
        title = "Press a shortcut…"
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = carbonModifiers(from: event.modifierFlags)
        guard modifiers != 0 else { return }
        onRecord(UInt32(event.keyCode), modifiers)
        title = "Record shortcut"
        window?.makeFirstResponder(nil)
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}
