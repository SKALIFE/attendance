import Foundation

struct UpdateSettings: Equatable, Sendable {
    let feedURL = AppConstants.appcastURL
    let automaticChecksEnabled: Bool
}
