import AppKit
import SwiftUI

private final class FloatingTerminalPanel: NSPanel {
    var increaseFontSize: (() -> Void)?
    var decreaseFontSize: (() -> Void)?
    var resetFontSize: (() -> Void)?
    var handleOptionKey: ((NSEvent) -> Bool)?
    var handleCommandKey: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            if handleOptionKey?(event) == true || handleCommandKey?(event) == true {
                return
            }
        }
        super.sendEvent(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers == .command else { return super.performKeyEquivalent(with: event) }

        switch event.charactersIgnoringModifiers {
        case "+", "=": increaseFontSize?(); return true
        case "-": decreaseFontSize?(); return true
        case "0": resetFontSize?(); return true
        default: return super.performKeyEquivalent(with: event)
        }
    }
}

private extension NSToolbarItem.Identifier {
    static let floatingTerminalSidebar = NSToolbarItem.Identifier("FloatingTerminal.sidebar")
    static let floatingTerminalNew = NSToolbarItem.Identifier("FloatingTerminal.new")
    static let floatingTerminalPin = NSToolbarItem.Identifier("FloatingTerminal.pin")
}

private enum PanelPersistence {
    static let frameAutosaveName = "FloatingTerminalPanelFrame"
    static let windowPinnedKey = "FloatingTerminal.windowPinned"
}

@MainActor
final class TerminalPanelController: NSObject, NSWindowDelegate, NSToolbarDelegate {
    private let workspaceState = TerminalWorkspaceViewState()
    private lazy var panel: FloatingTerminalPanel = makePanel()
    private var hasPositionedPanel = false
    private var shouldRestoreFocusUntil: Date?
    private var previousExternalApplication: NSRunningApplication?
    private var pinToolbarItem: NSToolbarItem?

    private var isWindowPinned: Bool {
        get {
            guard UserDefaults.standard.object(forKey: PanelPersistence.windowPinnedKey) != nil else {
                return true
            }
            return UserDefaults.standard.bool(forKey: PanelPersistence.windowPinnedKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: PanelPersistence.windowPinnedKey)
        }
    }

    override init() {
        super.init()
        if let application = NSWorkspace.shared.frontmostApplication,
           application.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousExternalApplication = application
        }
        workspaceState.onCommandSubmitted = { [weak self] command in
            guard command.trimmingCharacters(in: .whitespaces).hasPrefix("open") else { return }
            self?.shouldRestoreFocusUntil = Date().addingTimeInterval(5)
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidActivateApplication),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func toggle(anchorButton: NSStatusBarButton? = nil, restorePreviousApplication: Bool = false) {
        if panel.isVisible {
            hide()
            if restorePreviousApplication, let application = previousExternalApplication, !application.isTerminated {
                application.activate(options: [])
            }
        } else {
            show(anchorButton: anchorButton)
        }
    }

    func show(anchorButton: NSStatusBarButton? = nil) {
        if !hasPositionedPanel {
            positionBelowMenuBar(anchorButton: anchorButton)
            hasPositionedPanel = true
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.panel.makeFirstResponder(self.workspaceState.selectedTerminalView)
        }
    }

    func hide() {
        panel.orderOut(nil)
        shouldRestoreFocusUntil = nil
    }

    func stopAllSessions() {
        workspaceState.stopAll()
    }

    func increaseFontSize() { workspaceState.selectedSession?.increaseFontSize() }
    func decreaseFontSize() { workspaceState.selectedSession?.decreaseFontSize() }
    func resetFontSize() { workspaceState.selectedSession?.resetFontSize() }

    private func handleOptionKey(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers == .option,
              let session = workspaceState.selectedSession,
              let terminalView = workspaceState.selectedTerminalView as? RecordingLocalProcessTerminalView,
              terminalView.getTerminal().keyboardEnhancementFlags.isEmpty else {
            return false
        }

        let input: [UInt8]
        switch event.keyCode {
        case 123: input = [0x1b, 0x62] // Option-Left: previous word (Meta-b)
        case 124: input = [0x1b, 0x66] // Option-Right: next word (Meta-f)
        case 51: input = [0x1b, 0x7f]  // Option-Backspace: delete previous word
        case 117: input = [0x1b, 0x64] // Option-Delete: delete next word (Meta-d)
        default: return false
        }
        session.send(Data(input))
        return true
    }

    private func handleCommandKey(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers == .command,
              let session = workspaceState.selectedSession,
              let terminalView = workspaceState.selectedTerminalView as? RecordingLocalProcessTerminalView else {
            return false
        }

        switch event.keyCode {
        case 123 where terminalView.getTerminal().keyboardEnhancementFlags.isEmpty:
            session.send(Data([0x01])) // Command-Left: beginning of line (Control-A)
        case 124 where terminalView.getTerminal().keyboardEnhancementFlags.isEmpty:
            session.send(Data([0x05])) // Command-Right: end of line (Control-E)
        case 51 where terminalView.getTerminal().keyboardEnhancementFlags.isEmpty:
            session.send(Data([0x15])) // Command-Backspace: delete to beginning (Control-U)
        case 117 where terminalView.getTerminal().keyboardEnhancementFlags.isEmpty:
            session.send(Data([0x0b])) // Command-Delete: delete to end (Control-K)
        case 126:
            terminalView.scroll(toPosition: 0)
        case 125:
            terminalView.scroll(toPosition: 1)
        default:
            guard let character = event.charactersIgnoringModifiers?.lowercased() else { return false }
            switch character {
            case "c":
                let item = NSMenuItem(title: "Copy", action: #selector(terminalView.copy(_:)), keyEquivalent: "")
                guard terminalView.validateUserInterfaceItem(item) else { return true }
                terminalView.copy(self)
            case "v":
                terminalView.paste(self)
            case "a":
                terminalView.selectAll(self)
            case "f":
                let item = NSMenuItem(title: "Find", action: #selector(terminalView.performFindPanelAction(_:)), keyEquivalent: "")
                item.tag = Int(NSFindPanelAction.showFindPanel.rawValue)
                terminalView.performFindPanelAction(item)
            case "k":
                session.send(Data([0x0c])) // Redraw the prompt on a clean screen.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    terminalView.getTerminal().clearScrollback()
                }
            default:
                return false
            }
        }
        return true
    }

    func createTerminal(in workingDirectory: String? = nil) {
        workspaceState.restore()
        workspaceState.createTerminal(in: workingDirectory)
        show()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !isWindowPinned, !hasVisibleChildWindow else { return }
        hide()
    }

    private func makePanel() -> FloatingTerminalPanel {
        let panel = FloatingTerminalPanel(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.title = "FloatingTerminal"
        panel.titlebarAppearsTransparent = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 480, height: 280)
        panel.backgroundColor = .black
        panel.isOpaque = true
        panel.hasShadow = true
        panel.setFrameAutosaveName(PanelPersistence.frameAutosaveName)
        hasPositionedPanel = panel.setFrameUsingName(PanelPersistence.frameAutosaveName, force: true)
            && isVisibleOnConnectedDisplay(panel.frame)
        panel.increaseFontSize = { [weak self] in self?.increaseFontSize() }
        panel.decreaseFontSize = { [weak self] in self?.decreaseFontSize() }
        panel.resetFontSize = { [weak self] in self?.resetFontSize() }
        panel.handleOptionKey = { [weak self] event in self?.handleOptionKey(event) ?? false }
        panel.handleCommandKey = { [weak self] event in self?.handleCommandKey(event) ?? false }
        panel.delegate = self
        panel.toolbar = makeToolbar()
        panel.toolbarStyle = .unifiedCompact
        panel.contentView = NSHostingView(rootView: TerminalWorkspaceView(
            state: workspaceState,
            dismiss: { [weak self] in self?.hide() }
        ))
        return panel
    }

    private func isVisibleOnConnectedDisplay(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { screen in
            let intersection = frame.intersection(screen.visibleFrame)
            return intersection.width >= 80 && intersection.height >= 80
        }
    }

    private func makeToolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "FloatingTerminalToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        return toolbar
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.floatingTerminalSidebar, .flexibleSpace, .floatingTerminalNew, .floatingTerminalPin]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.floatingTerminalSidebar, .flexibleSpace, .floatingTerminalNew, .floatingTerminalPin]
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.target = self
        switch itemIdentifier {
        case .floatingTerminalSidebar:
            item.label = "Terminals"
            item.toolTip = "Show terminals"
            item.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "Show terminals")
            item.action = #selector(toggleSidebar)
        case .floatingTerminalNew:
            item.label = "New Terminal"
            item.toolTip = "New terminal"
            item.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "New terminal")
            item.action = #selector(createNewTerminal)
        case .floatingTerminalPin:
            pinToolbarItem = item
            updatePinToolbarItem()
            item.action = #selector(toggleWindowPin)
        default:
            return nil
        }
        return item
    }

    @objc private func toggleSidebar() {
        workspaceState.toggleSidebar()
    }

    @objc private func createNewTerminal() {
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.allowsMultipleSelection = false
        picker.canCreateDirectories = true
        picker.prompt = "Open Terminal"
        picker.beginSheetModal(for: panel) { [weak self] response in
            guard response == .OK, let directory = picker.url else { return }
            self?.createTerminal(in: directory.path)
        }
    }

    @objc private func toggleWindowPin() {
        isWindowPinned.toggle()
        updatePinToolbarItem()
    }

    private var hasVisibleChildWindow: Bool {
        panel.attachedSheet?.isVisible == true || panel.childWindows?.contains(where: \.isVisible) == true
    }

    private func updatePinToolbarItem() {
        guard let pinToolbarItem else { return }
        let pinned = isWindowPinned
        pinToolbarItem.label = pinned ? "Keep window open" : "Close when clicking outside"
        pinToolbarItem.toolTip = pinToolbarItem.label
        pinToolbarItem.image = NSImage(
            systemSymbolName: pinned ? "pin.fill" : "pin.slash",
            accessibilityDescription: pinToolbarItem.label
        )
    }

    @objc private func workspaceDidActivateApplication(_ notification: Notification) {
        guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        previousExternalApplication = application

        guard panel.isVisible,
              let deadline = shouldRestoreFocusUntil,
              deadline > Date()
        else { return }
        shouldRestoreFocusUntil = nil
        DispatchQueue.main.async { [weak self] in
            guard let self, self.panel.isVisible else { return }
            NSApp.activate(ignoringOtherApps: true)
            self.panel.makeKeyAndOrderFront(nil)
            self.panel.makeFirstResponder(self.workspaceState.selectedTerminalView)
        }
    }

    private func positionBelowMenuBar(anchorButton: NSStatusBarButton?) {
        let screen = anchorButton?.window?.screen
            ?? NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
            ?? NSScreen.main
        guard let screen else { return }
        let visibleFrame = screen.visibleFrame
        let margin: CGFloat = 12
        let gap: CGFloat = 8
        let size = NSSize(
            width: min(900, visibleFrame.width - margin * 2),
            height: min(560, visibleFrame.height - margin * 2)
        )
        let iconMidX: CGFloat
        if let anchorButton, let window = anchorButton.window {
            let buttonRect = anchorButton.convert(anchorButton.bounds, to: nil)
            iconMidX = window.convertToScreen(buttonRect).midX
        } else {
            iconMidX = visibleFrame.maxX - margin - size.width / 2
        }
        let x = min(max(iconMidX - size.width / 2, visibleFrame.minX + margin), visibleFrame.maxX - size.width - margin)
        let y = visibleFrame.maxY - size.height - gap
        panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
    }
}
