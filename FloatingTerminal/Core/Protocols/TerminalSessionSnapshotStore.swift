import Foundation

protocol TerminalSessionSnapshotStore {
    func load() -> [TerminalSessionSnapshot]
    func save(_ snapshots: [TerminalSessionSnapshot])
}
