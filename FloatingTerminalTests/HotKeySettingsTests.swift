import XCTest
@testable import FloatingTerminal

@MainActor
final class HotKeySettingsTests: XCTestCase {
    func testSavingAndClearingShortcut() {
        let suite = "HotKeySettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let settings = HotKeySettings(defaults: defaults)

        settings.save(keyCode: 49, modifiers: 256)
        XCTAssertEqual(settings.shortcut?.keyCode, 49)
        XCTAssertEqual(settings.shortcut?.modifiers, 256)

        settings.clear()
        XCTAssertNil(settings.shortcut)
        defaults.removePersistentDomain(forName: suite)
    }

    func testChoosingFolderSendsChangeDirectoryToCurrentSession() {
        let session = DirectorySpySession()
        let folder = URL(fileURLWithPath: "/tmp/project")
        let state = SettingsViewState(
            terminalSessionProvider: { session },
            chooseDirectory: { completion in completion(folder) }
        )

        state.chooseWorkingDirectory()

        XCTAssertEqual(session.changedDirectory, "/tmp/project")
        XCTAssertEqual(state.workingDirectoryDescription, "/tmp/project")
    }
}

@MainActor
private final class DirectorySpySession: TerminalSession {
    var isRunning = false
    var fontSize = 14.0
    var changedDirectory: String?
    func start(in workingDirectory: String? = nil) {}
    func send(_ input: Data) {}
    func changeDirectory(to path: String) { changedDirectory = path }
    func increaseFontSize() { fontSize += 1 }
    func decreaseFontSize() { fontSize -= 1 }
    func resetFontSize() { fontSize = 14 }
    func resize(columns: Int, rows: Int) {}
    func stop() {}
}
