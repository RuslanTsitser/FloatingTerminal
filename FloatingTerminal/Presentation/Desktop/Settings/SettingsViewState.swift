import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewState {
    private let settings: HotKeySettings
    private let terminalSessionProvider: () -> TerminalSession?
    private let chooseDirectory: (@escaping (URL?) -> Void) -> Void
    private(set) var shortcutDescription: String
    private(set) var workingDirectoryDescription = "No folder selected"

    init(
        settings: HotKeySettings = .shared,
        terminalSessionProvider: @escaping () -> TerminalSession? = { PreviewTerminalSession() },
        chooseDirectory: @escaping (@escaping (URL?) -> Void) -> Void = { completion in completion(nil) }
    ) {
        self.settings = settings
        self.terminalSessionProvider = terminalSessionProvider
        self.chooseDirectory = chooseDirectory
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

    func chooseWorkingDirectory() {
        chooseDirectory { [weak self] url in
            guard let self, let url else { return }
            self.terminalSessionProvider()?.changeDirectory(to: url.path)
            self.workingDirectoryDescription = url.path
        }
    }
}
