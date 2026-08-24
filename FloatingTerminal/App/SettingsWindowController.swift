import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private let selectedTerminalSession: () -> TerminalSession?

    init(selectedTerminalSession: @escaping () -> TerminalSession?) {
        self.selectedTerminalSession = selectedTerminalSession
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "FloatingTerminal Settings"
        window.isReleasedWhenClosed = false
        // The terminal panel lives at .statusBar so it can remain visible over
        // full-screen apps. Settings must share that level or the panel covers it.
        window.level = .statusBar
        super.init(window: window)

        window.contentView = NSHostingView(rootView: SettingsView(
            state: SettingsViewState(
                terminalSessionProvider: selectedTerminalSession,
                chooseDirectory: { [weak self] completion in self?.presentFolderPicker(completion: completion) }
            )
        ))
    }

    required init?(coder: NSCoder) { nil }

    func show(above parentWindow: NSWindow) {
        window?.center()
        if let window, window.parent !== parentWindow {
            window.parent?.removeChildWindow(window)
            parentWindow.addChildWindow(window, ordered: .above)
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        guard let window else { return }
        window.parent?.removeChildWindow(window)
        window.orderOut(nil)
    }

    private func presentFolderPicker(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Use Folder"
        guard let window else {
            completion(nil)
            return
        }
        panel.beginSheetModal(for: window) { response in
            completion(response == .OK ? panel.url : nil)
        }
    }
}
