import Foundation

@MainActor
final class PreviewTerminalSession: TerminalSession {
    private(set) var isRunning = false
    private(set) var fontSize = 14.0

    func start(in workingDirectory: String? = nil) { isRunning = true }
    func send(_ input: Data) {}
    func changeDirectory(to path: String) {}
    func increaseFontSize() { fontSize = min(fontSize + 1, 32) }
    func decreaseFontSize() { fontSize = max(fontSize - 1, 8) }
    func resetFontSize() { fontSize = 14 }
    func resize(columns: Int, rows: Int) {}
    func stop() { isRunning = false }
}
