import Foundation

struct ChromeVersion: Equatable, Sendable {
    let major: Int
    let full: String

    static func parse(_ output: String) -> ChromeVersion? {
        let pattern = #"(\d+)\.([\d.]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
              let fullRange = Range(match.range(at: 0), in: output),
              let majorRange = Range(match.range(at: 1), in: output),
              let major = Int(output[majorRange]) else {
            return nil
        }
        return ChromeVersion(major: major, full: String(output[fullRange]))
    }
}

struct ChromeVersionReader: Sendable {
    func readVersion(executableURL: URL) -> ChromeVersion? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executableURL
        process.arguments = ["--version"]
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8).flatMap(ChromeVersion.parse)
    }
}
