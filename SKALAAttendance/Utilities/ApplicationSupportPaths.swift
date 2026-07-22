import Foundation

struct ApplicationSupportPaths: Sendable {
    let root: URL

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        root = homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent(AppConstants.bundleIdentifier, isDirectory: true)
    }

    var chromeProfile: URL {
        root.appendingPathComponent("ChromeProfile", isDirectory: true)
    }

    var state: URL {
        root.appendingPathComponent("State", isDirectory: true)
    }

    var logs: URL {
        root.appendingPathComponent("Logs", isDirectory: true)
    }

    var preferencesFile: URL {
        state.appendingPathComponent("preferences.json")
    }

    func isAppOwned(_ url: URL) -> Bool {
        let rootPath = root.standardizedFileURL.path
        let candidate = url.standardizedFileURL.path
        return candidate == rootPath || candidate.hasPrefix(rootPath + "/")
    }
}
