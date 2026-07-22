import Foundation

struct AnonymousInstallID: Equatable, Sendable {
    let value: String

    static func generate() -> AnonymousInstallID {
        AnonymousInstallID(value: UUID().uuidString)
    }
}
