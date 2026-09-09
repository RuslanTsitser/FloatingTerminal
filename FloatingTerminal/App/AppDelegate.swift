import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let panelController = TerminalPanelController()
    private var hotKeyController: GlobalHotKeyController?
    private var statusItem: NSStatusItem?
    private lazy var settingsWindowController = SettingsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "Floating Terminal")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleStatusItemClick)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        self.statusItem = statusItem
        let controller = GlobalHotKeyController { [weak self] in
            self?.panelController.toggle()
        }
        controller.registerSavedShortcut()
        hotKeyController = controller
        NotificationCenter.default.addObserver(
            forName: HotKeySettings.didChange,
            object: nil,
            queue: .main
        ) { [weak controller] _ in
            Task { @MainActor in
                controller?.registerSavedShortcut()
            }
        }
    }

    @objc private func handleStatusItemClick(_ sender: Any?) {
        guard let button = sender as? NSStatusBarButton else { return }
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            let menu = NSMenu()
            let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: "")
            settingsItem.target = self
            menu.addItem(settingsItem)
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
        } else {
            panelController.toggle(anchorButton: button)
        }
    }

    @objc private func showSettings() {
        settingsWindowController.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        panelController.stopAllSessions()
    }

    @objc func openTerminalAtSelectedFolder(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let url = pasteboard.readObjects(forClasses: [NSURL.self], options: options)?.first as? URL else {
            error.pointee = "Select a folder in Finder." as NSString
            return
        }
        var isDirectory: ObjCBool = false
        let directory = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
            ? url
            : url.deletingLastPathComponent()
        panelController.createTerminal(in: directory.path)
    }
}
