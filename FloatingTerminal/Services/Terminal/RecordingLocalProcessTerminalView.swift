import AppKit
@preconcurrency import SwiftTerm

final class RecordingLocalProcessTerminalView: LocalProcessTerminalView {
    var onOutput: ((Data) -> Void)?
    var onInput: ((Data) -> Void)?

    override func dataReceived(slice: ArraySlice<UInt8>) {
        super.dataReceived(slice: slice)
        onOutput?(Data(slice))
    }

    override func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
        onInput?(Data(data))
        super.send(source: source, data: data)
    }

    override func cursorStyleChanged(source: SwiftTerm.Terminal, newStyle: CursorStyle) {
        let steadyStyle: CursorStyle
        switch newStyle {
        case .blinkBlock, .steadyBlock: steadyStyle = .steadyBlock
        case .blinkUnderline, .steadyUnderline: steadyStyle = .steadyUnderline
        case .blinkBar, .steadyBar: steadyStyle = .steadyBar
        }
        super.cursorStyleChanged(source: source, newStyle: steadyStyle)
    }
}
