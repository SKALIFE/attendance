import Foundation

struct ChromeProcess: Sendable {
    func launch(configuration: ChromeLaunchConfiguration) throws -> Process {
        let process = Process()
        process.executableURL = configuration.executableURL
        process.arguments = configuration.arguments
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()
        process.terminationHandler = { terminatedProcess in
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            if let errorString = String(data: errorData, encoding: .utf8), !errorString.isEmpty {
                AppLogger.chrome.error("Chrome stderr: \(errorString, privacy: .public)")
            }
            AppLogger.chrome.info("Chrome exited status=\(terminatedProcess.terminationStatus, privacy: .public)")
        }
        try process.run()
        AppLogger.chrome.info("Chrome launched pid=\(process.processIdentifier, privacy: .public)")
        return process
    }
}
