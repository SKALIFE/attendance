import Foundation

struct ChromeProfileManager: Sendable {
    let paths: ApplicationSupportPaths

    func prepareProfile() throws {
        try SafeFileManager(paths: paths).createAppDirectories()
    }

    func devToolsPortFile() -> URL {
        paths.chromeProfile.appendingPathComponent("DevToolsActivePort")
    }

    func readDevToolsPort() throws -> Int {
        try readDevToolsEndpoint().port
    }

    func readDevToolsEndpoint() throws -> DevToolsEndpoint {
        let text = try String(contentsOf: devToolsPortFile(), encoding: .utf8)
        guard let firstLine = text.split(separator: "\n").first,
               let port = Int(firstLine) else {
            throw ChromeSessionError.devToolsPortMissing
        }
        let browserPath = text.split(separator: "\n").dropFirst().first.map(String.init)
        return DevToolsEndpoint(port: port, browserPath: browserPath)
    }
}

struct DevToolsEndpoint: Equatable, Sendable {
    let port: Int
    let browserPath: String?
}
