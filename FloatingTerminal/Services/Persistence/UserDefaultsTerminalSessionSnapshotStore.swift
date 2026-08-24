import Foundation

final class UserDefaultsTerminalSessionSnapshotStore: TerminalSessionSnapshotStore {
    private let defaults: UserDefaults
    private let key = "terminal.sessionSnapshots"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [TerminalSessionSnapshot] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([TerminalSessionSnapshot].self, from: data)) ?? []
    }

    func save(_ snapshots: [TerminalSessionSnapshot]) {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        defaults.set(data, forKey: key)
    }
}
