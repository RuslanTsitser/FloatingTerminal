import Foundation

@MainActor
final class HotKeySettings {
    static let shared = HotKeySettings()
    static let didChange = Notification.Name("HotKeySettings.didChange")
    private let keyCodeKey = "hotKey.keyCode"
    private let modifiersKey = "hotKey.modifiers"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var shortcut: (keyCode: UInt32, modifiers: UInt32)? {
        guard defaults.object(forKey: keyCodeKey) != nil else { return nil }
        return (UInt32(defaults.integer(forKey: keyCodeKey)), UInt32(defaults.integer(forKey: modifiersKey)))
    }

    var shortcutDescription: String { shortcut == nil ? "No shortcut assigned" : "Shortcut assigned" }

    func save(keyCode: UInt32, modifiers: UInt32) {
        defaults.set(Int(keyCode), forKey: keyCodeKey)
        defaults.set(Int(modifiers), forKey: modifiersKey)
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }

    func clear() {
        defaults.removeObject(forKey: keyCodeKey)
        defaults.removeObject(forKey: modifiersKey)
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }
}
