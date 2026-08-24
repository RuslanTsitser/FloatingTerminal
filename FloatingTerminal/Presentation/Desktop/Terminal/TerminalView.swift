import SwiftUI

struct TerminalView: View {
    @State private var state: TerminalViewState
    let terminalSession: SwiftTermSession?

    init(state: TerminalViewState, terminalSession: SwiftTermSession? = nil) {
        _state = State(initialValue: state)
        self.terminalSession = terminalSession
    }

    var body: some View {
        ZStack {
            SwiftTermView(session: terminalSession)
                .background(Color.black)
        }
        .background(.black)
        .task { state.appeared() }
        .onExitCommand { state.escapePressed() }
    }
}

#Preview {
    TerminalView(
        state: TerminalViewState(session: PreviewTerminalSession()),
        terminalSession: nil
    )
    .frame(width: 900, height: 560)
}
