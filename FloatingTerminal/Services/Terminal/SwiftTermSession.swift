import AppKit
@preconcurrency import SwiftTerm

@MainActor
final class SwiftTermSession: NSObject, TerminalSession {
    private static let defaultFontSize = 14.0
    private static let fontSizeRange = 8.0...32.0
    private static let fontSizeKey = "terminal.fontSize"

    let terminalView = RecordingLocalProcessTerminalView(
        frame: .zero,
        options: TerminalOptions(cursorStyle: .steadyBlock)
    )
    private(set) var isRunning = false
    private let defaults: UserDefaults
    private(set) var fontSize: Double
    var onWorkingDirectoryChanged: ((String?) -> Void)?
    var onLastCommandChanged: ((String?) -> Void)?
    var onTranscriptChanged: ((String) -> Void)?
    private var pendingCommand = ""
    private var transcript = ""
    private let transcriptLimit = 120_000

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedSize = defaults.object(forKey: Self.fontSizeKey) as? Double
        fontSize = Self.clamp(storedSize ?? Self.defaultFontSize)
        super.init()
        terminalView.processDelegate = self
        terminalView.onOutput = { [weak self] output in
            self?.recordOutput(output)
        }
        terminalView.onInput = { [weak self] input in
            self?.recordInput(input)
        }
        applyFont()
        terminalView.optionAsMetaKey = true
        terminalView.nativeBackgroundColor = .black
        terminalView.nativeForegroundColor = .white
    }

    func start(in workingDirectory: String? = nil) {
        guard !isRunning else { return }
        let environment = ProcessInfo.processInfo.environment
            .merging(["TERM": "xterm-256color", "COLORTERM": "truecolor"]) { _, terminalValue in
                terminalValue
            }
            .map { "\($0.key)=\($0.value)" }
        terminalView.startProcess(
            executable: "/bin/zsh",
            args: ["-l"],
            environment: environment,
            currentDirectory: workingDirectory
        )
        isRunning = true
    }

    func send(_ input: Data) {
        terminalView.send(source: terminalView, data: Array(input)[...])
    }

    func changeDirectory(to path: String) {
        let quotedPath = "'" + path.replacing("'", with: "'\\''") + "'"
        send(Data("cd -- \(quotedPath)\n".utf8))
    }

    func increaseFontSize() {
        setFontSize(fontSize + 1)
    }

    func decreaseFontSize() {
        setFontSize(fontSize - 1)
    }

    func resetFontSize() {
        setFontSize(Self.defaultFontSize)
    }

    func resize(columns: Int, rows: Int) {}

    func stop() {
        terminalView.terminate()
        isRunning = false
    }

    func restoreTranscript(_ savedTranscript: String) {
        guard !savedTranscript.isEmpty else { return }
        transcript = String(Self.plainText(from: savedTranscript).suffix(transcriptLimit))
        terminalView.feed(text: transcript)
    }

    func currentTranscript() -> String {
        transcript
    }

    private func setFontSize(_ size: Double) {
        fontSize = Self.clamp(size)
        defaults.set(fontSize, forKey: Self.fontSizeKey)
        applyFont()
    }

    private func applyFont() {
        terminalView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    private static func clamp(_ size: Double) -> Double {
        min(max(size, fontSizeRange.lowerBound), fontSizeRange.upperBound)
    }

    private func recordOutput(_ output: Data) {
        guard !output.isEmpty else { return }
        let snapshot = terminalView.getTerminal().getBufferAsData(kind: .normal)
        guard let text = String(data: snapshot, encoding: .utf8) else { return }
        transcript = String(text.suffix(transcriptLimit))
        onTranscriptChanged?(transcript)
    }

    private static func plainText(from text: String) -> String {
        enum State {
            case text
            case escape
            case controlSequence
            case controlString
            case controlStringEscape
        }

        var result = String.UnicodeScalarView()
        var state = State.text

        for scalar in text.unicodeScalars {
            switch state {
            case .text:
                switch scalar.value {
                case 0x1b:
                    state = .escape
                case 0x0a, 0x0d, 0x09:
                    result.append(scalar)
                case 0x20...0x7e, 0xa0...0x10ffff:
                    result.append(scalar)
                default:
                    break
                }
            case .escape:
                switch scalar.value {
                case 0x5b: // CSI
                    state = .controlSequence
                case 0x5d, 0x50, 0x5e, 0x5f: // OSC, DCS, PM, APC
                    state = .controlString
                case 0x20...0x2f:
                    break
                default:
                    state = .text
                }
            case .controlSequence:
                if scalar.value >= 0x40 && scalar.value <= 0x7e {
                    state = .text
                }
            case .controlString:
                if scalar.value == 0x07 {
                    state = .text
                } else if scalar.value == 0x1b {
                    state = .controlStringEscape
                }
            case .controlStringEscape:
                state = scalar.value == 0x5c ? .text : .controlString
            }
        }

        return String(result)
    }

    private func recordInput(_ input: Data) {
        guard let text = String(data: input, encoding: .utf8) else { return }
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 10, 13:
                let command = pendingCommand.trimmingCharacters(in: .whitespacesAndNewlines)
                if !command.isEmpty { onLastCommandChanged?(command) }
                pendingCommand = ""
            case 8, 127:
                if !pendingCommand.isEmpty { pendingCommand.removeLast() }
            case 32...126:
                pendingCommand.unicodeScalars.append(scalar)
            default:
                break
            }
        }
    }

}

extension SwiftTermSession: LocalProcessTerminalViewDelegate {
    nonisolated func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    nonisolated func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    nonisolated func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {
        Task { @MainActor [weak self] in self?.onWorkingDirectoryChanged?(directory) }
    }
    nonisolated func processTerminated(source: SwiftTerm.TerminalView, exitCode: Int32?) {
        Task { @MainActor [weak self] in self?.isRunning = false }
    }
}
