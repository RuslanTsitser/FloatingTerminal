import Observation

@MainActor
@Observable
final class TerminalViewState {
    private let session: TerminalSession
    private let dismiss: () -> Void
    private(set) var isStarted = false

    init(session: TerminalSession, dismiss: @escaping () -> Void = {}) {
        self.session = session
        self.dismiss = dismiss
    }

    func appeared() {
        guard !isStarted else { return }
        session.start(in: nil)
        isStarted = true
    }

    func escapePressed() {
        dismiss()
    }

    func stop() {
        session.stop()
        isStarted = false
    }
}
