import Foundation

@MainActor
protocol TerminalSession: AnyObject {
    var isRunning: Bool { get }
    var fontSize: Double { get }
    func start(in workingDirectory: String?)
    func send(_ input: Data)
    func changeDirectory(to path: String)
    func increaseFontSize()
    func decreaseFontSize()
    func resetFontSize()
    func resize(columns: Int, rows: Int)
    func stop()
}
