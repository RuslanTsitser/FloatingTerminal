import AppKit
import Observation

@MainActor
@Observable
final class TerminalWorkspaceViewState {
    struct SessionItem: Identifiable, Equatable {
        let id: UUID
        var workingDirectory: String?
        var lastCommand: String?
        var isRunning: Bool

        var title: String {
            guard let workingDirectory, !workingDirectory.isEmpty else { return "Terminal" }
            return URL(fileURLWithPath: workingDirectory).lastPathComponent
        }

        var subtitle: String {
            lastCommand ?? workingDirectory ?? "New shell"
        }
    }

    private struct LiveSession {
        let id: UUID
        let session: SwiftTermSession
        var workingDirectory: String?
        var lastCommand: String?
    }

    private var sessions: [LiveSession] = []
    private let snapshotStore: TerminalSessionSnapshotStore
    private(set) var items: [SessionItem] = []
    private(set) var selectedID: UUID?
    private(set) var isSidebarVisible = false
    var onChange: (() -> Void)?
    var onCommandSubmitted: ((String) -> Void)?

    var selectedTerminalView: NSView? {
        guard let selectedID else { return nil }
        return sessions.first(where: { $0.id == selectedID })?.session.terminalView
    }

    var selectedSession: TerminalSession? {
        guard let selectedID else { return nil }
        return sessions.first(where: { $0.id == selectedID })?.session
    }

    init(snapshotStore: TerminalSessionSnapshotStore = UserDefaultsTerminalSessionSnapshotStore()) {
        self.snapshotStore = snapshotStore
    }

    func restore() {
        guard sessions.isEmpty else { return }
        let snapshots = snapshotStore.load()
        if snapshots.isEmpty {
            createTerminal()
        } else {
            for snapshot in snapshots {
                createTerminal(
                    id: snapshot.id,
                    workingDirectory: snapshot.workingDirectory,
                    lastCommand: snapshot.lastCommand,
                    transcript: snapshot.transcript,
                    select: selectedID == nil
                )
            }
        }
    }

    func createTerminal(in workingDirectory: String? = nil) {
        createTerminal(
            id: UUID(),
            workingDirectory: workingDirectory,
            lastCommand: nil,
            transcript: "",
            select: true
        )
    }

    func select(_ id: UUID) {
        guard sessions.contains(where: { $0.id == id }) else { return }
        selectedID = id
        rebuildItems()
    }

    func toggleSidebar() {
        isSidebarVisible.toggle()
        onChange?()
    }

    func kill(_ id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        let removed = sessions.remove(at: index)
        removed.session.stop()
        if selectedID == id {
            selectedID = sessions.last?.id
        }
        if sessions.isEmpty { createTerminal() } else { rebuildItems(); persist() }
    }

    func stopAll() {
        sessions.forEach { $0.session.stop() }
        persist()
    }

    private func createTerminal(
        id: UUID,
        workingDirectory: String?,
        lastCommand: String?,
        transcript: String,
        select: Bool
    ) {
        let session = SwiftTermSession()
        session.restoreTranscript(transcript)
        session.onWorkingDirectoryChanged = { [weak self] directory in
            self?.update(id: id, workingDirectory: directory)
        }
        session.onLastCommandChanged = { [weak self] command in
            self?.update(id: id, lastCommand: command)
            if let command { self?.onCommandSubmitted?(command) }
        }
        session.onTranscriptChanged = { [weak self] _ in
            self?.persist()
        }
        sessions.append(LiveSession(id: id, session: session, workingDirectory: workingDirectory, lastCommand: lastCommand))
        session.start(in: workingDirectory)
        if select { selectedID = id }
        rebuildItems()
        persist()
    }

    private func update(id: UUID, workingDirectory: String? = nil, lastCommand: String? = nil) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        if let workingDirectory { sessions[index].workingDirectory = workingDirectory }
        if let lastCommand { sessions[index].lastCommand = lastCommand }
        rebuildItems()
        persist()
    }

    private func rebuildItems() {
        items = sessions.map {
            SessionItem(
                id: $0.id,
                workingDirectory: $0.workingDirectory,
                lastCommand: $0.lastCommand,
                isRunning: $0.session.isRunning
            )
        }
        onChange?()
    }

    private func persist() {
        snapshotStore.save(sessions.map {
            TerminalSessionSnapshot(
                id: $0.id,
                workingDirectory: $0.workingDirectory,
                lastCommand: $0.lastCommand,
                transcript: $0.session.currentTranscript()
            )
        })
    }
}
