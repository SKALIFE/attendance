import Foundation

struct CDPEvent: Equatable, Sendable {
    let method: String
    let params: [String: CDPValue]
}
