import XCTest
@testable import FloatingTerminal

@MainActor
final class SwiftTermSessionTests: XCTestCase {
    func testRestoredLinesStartInFirstColumn() {
        let session = SwiftTermSession()

        session.restoreTranscript("first command\nsecond command\nthird command\n")

        XCTAssertEqual(line(0, in: session), "first command")
        XCTAssertEqual(line(1, in: session), "second command")
        XCTAssertEqual(line(2, in: session), "third command")
        XCTAssertEqual(session.terminalView.getTerminal().getCursorLocation().x, 0)
        XCTAssertEqual(session.terminalView.getTerminal().getCursorLocation().y, 3)
    }

    func testRemovesOnlyTrailingBlankLines() {
        let session = SwiftTermSession()

        session.restoreTranscript("  first\n\n  second\n\n  \n\t\n")
        session.terminalView.feed(text: "$ ")

        XCTAssertEqual(session.currentTranscript(), "  first\n\n  second\n")
        XCTAssertEqual(line(0, in: session), "  first")
        XCTAssertEqual(line(1, in: session), "")
        XCTAssertEqual(line(2, in: session), "  second")
        XCTAssertEqual(line(3, in: session), "$ ")
    }

    func testNormalizesMixedLineEndingsWithoutAddingBlankLines() {
        let session = SwiftTermSession()

        session.restoreTranscript("one\r\ntwo\rthree\nfour")
        session.terminalView.feed(text: "$ ")

        XCTAssertEqual(session.currentTranscript(), "one\ntwo\nthree\nfour\n")
        XCTAssertEqual(line(0, in: session), "one")
        XCTAssertEqual(line(1, in: session), "two")
        XCTAssertEqual(line(2, in: session), "three")
        XCTAssertEqual(line(3, in: session), "four")
        XCTAssertEqual(line(4, in: session), "$ ")
    }

    func testEmptyHistoryDoesNotMoveCursor() {
        for transcript in ["", "\n\r\n  \n\t", "\u{1b}[31m\u{1b}[0m"] {
            let session = SwiftTermSession()

            session.restoreTranscript(transcript)

            XCTAssertEqual(session.currentTranscript(), "")
            XCTAssertEqual(session.terminalView.getTerminal().getCursorLocation().x, 0)
            XCTAssertEqual(session.terminalView.getTerminal().getCursorLocation().y, 0)
        }
    }

    func testLegacyControlSequencesAreNotReplayed() {
        let session = SwiftTermSession()

        session.restoreTranscript("\u{1b}]0;old title\u{7}\u{1b}[31mПривет\u{1b}[0m\nworld\u{1b}[2J")

        XCTAssertEqual(session.currentTranscript(), "Привет\nworld\n")
        XCTAssertEqual(line(0, in: session), "Привет")
        XCTAssertEqual(line(1, in: session), "world")
    }

    func testRepeatedSaveAndRestoreDoesNotAccumulateOffsetsOrBlankTail() {
        var transcript = "first\n\nsecond\n" + String(repeating: "\n", count: 30)

        for _ in 0..<3 {
            let session = SwiftTermSession()
            session.restoreTranscript(transcript)
            // A carriage return triggers the same snapshot path as shell output.
            session.terminalView.dataReceived(slice: Array("\r".utf8)[...])
            transcript = session.currentTranscript()

            XCTAssertEqual(transcript, "first\n\nsecond\n")
            XCTAssertEqual(line(0, in: session), "first")
            XCTAssertEqual(line(1, in: session), "")
            XCTAssertEqual(line(2, in: session), "second")
            XCTAssertEqual(session.terminalView.getTerminal().getCursorLocation().x, 0)
            XCTAssertEqual(session.terminalView.getTerminal().getCursorLocation().y, 3)
        }
    }

    private func line(_ row: Int, in session: SwiftTermSession) -> String? {
        session.terminalView.getTerminal().getLine(row: row)?.translateToString(trimRight: true)
    }
}
