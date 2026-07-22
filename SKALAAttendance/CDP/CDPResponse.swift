import Foundation

struct CDPResponse: Equatable, Sendable {
    let id: Int
    let result: [String: CDPValue]
    let error: CDPError?
}

struct CDPError: Error, Equatable, Sendable {
    let code: Int
    let message: String
}

enum CDPClientError: Error, Equatable {
    case notConnected
    case invalidMessage
    case responseMismatch(expected: Int, actual: Int?)
    case commandFailed(CDPError)
    case commandTimedOut(Int)
    case connectionClosed
}
