import XCTest
@testable import FloatingTerminal

@MainActor
final class TerminalViewStateTests: XCTestCase {
    func testAppearingStartsSessionOnlyOnce() {
        let session = SpyTerminalSession()
        let state = TerminalViewState(session: session)

        state.appeared()
        state.appeared()

        XCTAssertEqual(session.startCount, 1)
    }

    func testEscapeDismissesWithoutStoppingSession() {
        let session = SpyTerminalSession()
        var dismissCount = 0
        let state = TerminalViewState(session: session) { dismissCount += 1 }

        state.escapePressed()

        XCTAssertEqual(dismissCount, 1)
        XCTAssertEqual(session.stopCount, 0)
    }

    func testStopTerminatesSession() {
        let session = SpyTerminalSession()
        let state = TerminalViewState(session: session)

        state.stop()

        XCTAssertEqual(session.stopCount, 1)
    }

    func testFontSizeIsClampedAndPersisted() {
        let suite = "SwiftTermSessionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let session = SwiftTermSession(defaults: defaults)

        for _ in 0..<30 { session.increaseFontSize() }
        XCTAssertEqual(session.fontSize, 32)

        for _ in 0..<40 { session.decreaseFontSize() }
        XCTAssertEqual(session.fontSize, 8)

        session.resetFontSize()
        XCTAssertEqual(SwiftTermSession(defaults: defaults).fontSize, 14)
        defaults.removePersistentDomain(forName: suite)
    }
}

@MainActor
private final class SpyTerminalSession: TerminalSession {
    var isRunning = false
    var fontSize = 14.0
    var startCount = 0
    var stopCount = 0
    func start(in workingDirectory: String? = nil) { startCount += 1; isRunning = true }
    func send(_ input: Data) {}
    func changeDirectory(to path: String) {}
    func increaseFontSize() { fontSize += 1 }
    func decreaseFontSize() { fontSize -= 1 }
    func resetFontSize() { fontSize = 14 }
    func resize(columns: Int, rows: Int) {}
    func stop() { stopCount += 1; isRunning = false }
}
