import Foundation

enum AppConstants {
    static let appName = "SKALA Attendance"
    static let bundleIdentifier = "kr.skalife.attendance"
    static let attendanceURL = URL(string: "https://att.skala-ai.com/")!
    static let chromeDownloadURL = URL(string: "https://www.google.com/chrome/")!
    static let repositoryURL = URL(string: "https://github.com/skalife/attendance")!
    static let privacyDocumentName = "PRIVACY.md"
    static let appcastURL = URL(string: "https://skalife.github.io/attendance/appcast.xml")!
    static let analyticsHostname = "attendance-app.skalife.kr"
    static let defaultWindowBounds = WindowBounds(x: 10_000, y: 0, width: 430, height: 900)
}
