import Foundation

struct CDPTarget: Codable, Equatable, Sendable {
    let id: String
    let type: String
    let url: String
    let webSocketDebuggerURL: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case url
        case webSocketDebuggerURL = "webSocketDebuggerUrl"
    }
}
