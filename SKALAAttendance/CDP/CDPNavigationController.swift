import Foundation

struct CDPNavigationController: Sendable {
    let client: CDPClient

    func openAttendance(version: ChromeVersion) async throws {
        let profile = MobileEmulationProfile()
        try await client.send(.pageEnable)
        try await client.send(profile.deviceMetricsCommand())
        try await client.send(profile.touchCommand())
        try await client.send(profile.userAgentCommand(chromeMajorVersion: version.major, fullVersion: version.full))
        try await client.send(.navigate(to: AppConstants.attendanceURL))
        try await client.send(.pageBringToFront)
    }
}
