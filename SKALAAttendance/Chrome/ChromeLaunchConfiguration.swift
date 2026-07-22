import Foundation

struct ChromeLaunchConfiguration: Equatable, Sendable {
    let executableURL: URL
    let profileURL: URL
    let remoteDebuggingPort: Int?
    let windowBounds: WindowBounds

    var arguments: [String] {
        [
            "--user-data-dir=\(profileURL.path)",
            "--remote-debugging-address=127.0.0.1",
            "--remote-debugging-port=0",
            "--app=about:blank",
            "--window-size=\(windowBounds.width),\(windowBounds.height)",
            "--window-position=\(windowBounds.x),\(windowBounds.y)",
            "--no-first-run",
            "--no-default-browser-check"
        ]
    }
}
