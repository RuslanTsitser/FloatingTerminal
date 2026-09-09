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

}
