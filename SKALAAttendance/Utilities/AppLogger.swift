import OSLog

enum AppLogger {
    static let chrome = Logger(subsystem: AppConstants.bundleIdentifier, category: "chrome")
    static let cdp = Logger(subsystem: AppConstants.bundleIdentifier, category: "cdp")
    static let analytics = Logger(subsystem: AppConstants.bundleIdentifier, category: "analytics")
    static let app = Logger(subsystem: AppConstants.bundleIdentifier, category: "app")
}
