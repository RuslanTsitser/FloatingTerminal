import AppKit

@MainActor
final class TerminalWorkspaceContainerController: NSSplitViewController, NSTableViewDataSource, NSTableViewDelegate {
    var dismiss: () -> Void = {}
    private let state: TerminalWorkspaceViewState
    private let tableView = NSTableView()
    private let terminalHost = TerminalHostContainerView()
    private var sidebarItem: NSSplitViewItem!

    init(state: TerminalWorkspaceViewState) { self.state = state; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("sessions"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowSizeStyle = .medium
        tableView.rowHeight = 56
        tableView.style = .sourceList
        tableView.selectionHighlightStyle = .regular
        tableView.dataSource = self
        tableView.delegate = self
        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.contentInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        let sidebarController = NSViewController()
        sidebarController.view = scrollView
        sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
        sidebarItem.minimumThickness = 180
        sidebarItem.maximumThickness = 600
        addSplitViewItem(sidebarItem)

        let terminalController = NSViewController()
        terminalController.view = terminalHost
        terminalHost.wantsLayer = true
        terminalHost.layer?.backgroundColor = NSColor.black.cgColor
        addSplitViewItem(NSSplitViewItem(viewController: terminalController))
        splitView.setPosition(240, ofDividerAt: 0)

        state.onChange = { [weak self] in self?.reload() }
        state.restore()
        reload()
    }

    override func cancelOperation(_ sender: Any?) { dismiss() }
    func numberOfRows(in tableView: NSTableView) -> Int { state.items.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("TerminalSessionCell")
        let cell = (tableView.makeView(withIdentifier: identifier, owner: self) as? TerminalSessionCellView) ?? TerminalSessionCellView(frame: .zero)
        cell.identifier = identifier
        let item = state.items[row]
        cell.configure(item: item) { [weak self] in self?.state.kill(item.id) }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard state.items.indices.contains(row) else { return }
        let selectedID = state.items[row].id
        guard state.selectedID != selectedID else { return }
        state.select(selectedID)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.view.window?.makeFirstResponder(self.state.selectedTerminalView)
        }
    }

    private func reload() {
        sidebarItem.isCollapsed = !state.isSidebarVisible
        tableView.reloadData()
        if let selectedID = state.selectedID, let row = state.items.firstIndex(where: { $0.id == selectedID }) {
            if tableView.selectedRow != row {
                tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            }
        }
        terminalHost.show(state.selectedTerminalView)
    }
}

private final class TerminalHostContainerView: NSView {
    private let contentInset: CGFloat = 12
    private weak var terminalView: NSView?

    func show(_ terminalView: NSView?) {
        guard self.terminalView !== terminalView else { return }
        subviews.forEach { $0.removeFromSuperview() }
        guard let terminalView else { return }
        self.terminalView = terminalView
        addSubview(terminalView)
        layout()
    }

    override func layout() {
        super.layout()
        terminalView?.frame = bounds.insetBy(dx: contentInset, dy: contentInset)
    }
}

private final class TerminalSessionCellView: NSTableCellView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let killButton = NSButton()
    private var actionTarget: BlockActionTarget?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        subtitleLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        killButton.bezelStyle = .inline
        killButton.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "Kill terminal")
        killButton.toolTip = "Kill terminal"
        killButton.isHidden = true
        [titleLabel, subtitleLabel, killButton].forEach(addSubview)
        [titleLabel, subtitleLabel, killButton].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            titleLabel.trailingAnchor.constraint(equalTo: killButton.leadingAnchor, constant: -8),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8),
            killButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            killButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            killButton.widthAnchor.constraint(equalToConstant: 24),
            killButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    required init?(coder: NSCoder) { nil }
    func configure(item: TerminalWorkspaceViewState.SessionItem, kill: @escaping () -> Void) {
        titleLabel.stringValue = item.title
        subtitleLabel.stringValue = item.subtitle
        actionTarget = BlockActionTarget(action: kill)
        killButton.target = actionTarget
        killButton.action = #selector(BlockActionTarget.invoke)
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect], owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) { killButton.isHidden = false }
    override func mouseExited(with event: NSEvent) { killButton.isHidden = true }
}

private final class BlockActionTarget: NSObject {
    private let action: () -> Void
    init(action: @escaping () -> Void) { self.action = action }
    @objc func invoke() { action() }
}
