import Carbon

@MainActor
final class GlobalHotKeyController {
    private let action: () -> Void
    private nonisolated(unsafe) var hotKeyRef: EventHotKeyRef?
    private nonisolated(unsafe) var eventHandler: EventHandlerRef?

    init(action: @escaping () -> Void) {
        self.action = action
        installHandler()
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    func registerSavedShortcut() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        guard let shortcut = HotKeySettings.shared.shortcut else { return }
        let id = EventHotKeyID(signature: OSType(0x4654_4552), id: 1)
        RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    private func installHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let controller = Unmanaged<GlobalHotKeyController>.fromOpaque(userData).takeUnretainedValue()
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            if id.id == 1 { controller.action() }
            return noErr
        }, 1, &eventType, pointer, &eventHandler)
    }
}
