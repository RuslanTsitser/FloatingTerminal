import Foundation

struct TerminalSessionSnapshot: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var workingDirectory: String?
    var lastCommand: String?
    var transcript: String
}
