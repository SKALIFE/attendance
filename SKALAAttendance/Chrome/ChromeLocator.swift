import Foundation

struct ChromeLocator: Sendable {
    let candidateApps: [URL]
    static let expectedBundleIdentifier = "com.google.Chrome"

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        candidateApps = [
            URL(fileURLWithPath: "/Applications/Google Chrome.app"),
            homeDirectory.appendingPathComponent("Applications/Google Chrome.app")
        ]
    }

    init(customApps: [URL]) {
        candidateApps = customApps
    }

    func findChromeApp() throws -> URL {
        for candidate in candidateApps where FileManager.default.fileExists(atPath: candidate.path) {
            guard hasValidBundleIdentity(candidate) else {
                throw ChromeLocatorError.identityMismatch
            }
            return candidate
        }
        throw ChromeLocatorError.notFound
    }

    func executableURL() throws -> URL {
        try findChromeApp()
            .appendingPathComponent("Contents/MacOS/Google Chrome")
    }

    private func hasValidBundleIdentity(_ appURL: URL) -> Bool {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let plist = NSDictionary(contentsOf: plistURL),
              let bundleIdentifier = plist["CFBundleIdentifier"] as? String else {
            return false
        }
        return bundleIdentifier == Self.expectedBundleIdentifier
    }
}
