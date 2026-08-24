import SwiftUI

struct TerminalWorkspaceView: NSViewControllerRepresentable {
    @State private var state: TerminalWorkspaceViewState
    private let dismiss: () -> Void

    init(state: TerminalWorkspaceViewState, dismiss: @escaping () -> Void = {}) {
        _state = State(initialValue: state)
        self.dismiss = dismiss
    }

    func makeNSViewController(context: Context) -> TerminalWorkspaceContainerController {
        let controller = TerminalWorkspaceContainerController(state: state)
        controller.dismiss = dismiss
        return controller
    }

    func updateNSViewController(_ nsViewController: TerminalWorkspaceContainerController, context: Context) {}
}

#Preview {
    TerminalWorkspaceView(state: TerminalWorkspaceViewState()).frame(width: 900, height: 560)
}
