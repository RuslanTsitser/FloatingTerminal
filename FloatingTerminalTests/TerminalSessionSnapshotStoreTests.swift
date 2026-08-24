import XCTest
@testable import FloatingTerminal

final class TerminalSessionSnapshotStoreTests: XCTestCase {
    func testStoreRoundTripsSessionMetadataAndTranscript() {
        let suite = "TerminalSessionSnapshotStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = UserDefaultsTerminalSessionSnapshotStore(defaults: defaults)
        let snapshot = TerminalSessionSnapshot(
            id: UUID(),
            workingDirectory: "/tmp/project",
            lastCommand: "git status",
            transcript: "last output"
        )

        store.save([snapshot])

        XCTAssertEqual(store.load(), [snapshot])
        defaults.removePersistentDomain(forName: suite)
    }
}
