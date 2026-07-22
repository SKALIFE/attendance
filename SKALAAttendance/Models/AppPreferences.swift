import Foundation

struct AppPreferences: Codable, Equatable, Sendable {
    var onboardingCompleted: Bool
    var analyticsEnabled: Bool
    var launchAtLoginEnabled: Bool
    var openOnMenuClick: Bool
    var automaticUpdateChecks: Bool
    var windowBounds: WindowBounds
    var anonymousInstallID: String?
    var installEventSent: Bool

    static let defaults = AppPreferences(
        onboardingCompleted: false,
        analyticsEnabled: true,
        launchAtLoginEnabled: false,
        openOnMenuClick: false,
        automaticUpdateChecks: false,
        windowBounds: AppConstants.defaultWindowBounds,
        anonymousInstallID: nil,
        installEventSent: false
    )
}

protocol PreferencesStore: Sendable {
    func load() throws -> AppPreferences
    func save(_ preferences: AppPreferences) throws
}

struct JSONPreferencesStore: PreferencesStore {
    let fileURL: URL

    func load() throws -> AppPreferences {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .defaults
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(AppPreferences.self, from: data)
    }

    func save(_ preferences: AppPreferences) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(preferences)
        try data.write(to: fileURL, options: .atomic)
    }
}
