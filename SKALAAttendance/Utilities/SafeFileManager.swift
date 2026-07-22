import Foundation

enum SafeFileManagerError: Error, Equatable {
    case outsideApplicationSupport(URL)
}

struct SafeFileManager: Sendable {
    let paths: ApplicationSupportPaths

    func createAppDirectories() throws {
        try FileManager.default.createDirectory(at: paths.chromeProfile, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: paths.state, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: paths.logs, withIntermediateDirectories: true)
    }

    func removeChromeProfile() throws {
        guard paths.isAppOwned(paths.chromeProfile) else {
            throw SafeFileManagerError.outsideApplicationSupport(paths.chromeProfile)
        }
        if FileManager.default.fileExists(atPath: paths.chromeProfile.path) {
            try FileManager.default.removeItem(at: paths.chromeProfile)
        }
    }
}
