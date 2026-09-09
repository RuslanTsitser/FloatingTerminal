import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewState {
    private let settings: HotKeySettings
    private(set) var shortcutDescription: String

    init(settings: HotKeySettings = .shared) {
        self.settings = settings
        shortcutDescription = settings.shortcutDescription
    }

    func clearShortcut() {
        settings.clear()
        shortcutDescription = settings.shortcutDescription
    }

    func saveShortcut(keyCode: UInt32, modifiers: UInt32) {
        settings.save(keyCode: keyCode, modifiers: modifiers)
        shortcutDescription = settings.shortcutDescription
    }

}
