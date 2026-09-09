import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "FloatingTerminal Settings"
        window.isReleasedWhenClosed = false
        // Keep settings visible above the floating terminal panel.
        window.level = .statusBar
        super.init(window: window)
        window.contentView = NSHostingView(rootView: SettingsView())
    }

    required init?(coder: NSCoder) { nil }

    func show() {
        if window?.isVisible != true {
            window?.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
