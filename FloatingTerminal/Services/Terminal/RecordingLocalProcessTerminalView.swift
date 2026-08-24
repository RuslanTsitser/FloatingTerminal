import AppKit
@preconcurrency import SwiftTerm

final class RecordingLocalProcessTerminalView: LocalProcessTerminalView {
    var onOutput: ((Data) -> Void)?
    var onInput: ((Data) -> Void)?

    override func dataReceived(slice: ArraySlice<UInt8>) {
        onOutput?(Data(slice))
        super.dataReceived(slice: slice)
    }

    override func send(source: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
        onInput?(Data(data))
        super.send(source: source, data: data)
    }
}
