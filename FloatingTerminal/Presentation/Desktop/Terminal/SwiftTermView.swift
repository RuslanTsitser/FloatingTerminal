import SwiftUI

struct SwiftTermView: NSViewRepresentable {
    let session: SwiftTermSession?

    func makeNSView(context: Context) -> NSView {
        guard let session else { return NSView() }
        return session.terminalView
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
