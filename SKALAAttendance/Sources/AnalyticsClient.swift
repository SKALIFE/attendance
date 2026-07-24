import Foundation
import os

struct AnalyticsClient: Sendable {
    let configuration: AnalyticsConfiguration
    var session: URLSession = .shared
    private let logger = Logger(subsystem: "kr.skalife.attendance", category: "analytics")

    func track(
        _ event: AnalyticsEvent,
        distinctID: String,
        analyticsEnabled: Bool
    ) async {
        guard analyticsEnabled,
              configuration.isConfigured,
              let baseURL = configuration.baseURL,
              let websiteID = configuration.websiteID else {
            return
        }

        let payload: [String: Any] = [
            "type": "event",
            "payload": [
                "website": websiteID,
                "hostname": configuration.hostname,
                "url": event.path,
                "name": event.rawValue,
                "distinctId": distinctID,
                "id": distinctID,
                "data": [
                    "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0",
                    "build_number": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
                    "macos_version": ProcessInfo.processInfo.operatingSystemVersionString,
                    "architecture": "arm64"
                ]
            ]
        ]

        var request = URLRequest(url: baseURL.appendingPathComponent("api/send"))
        request.httpMethod = "POST"
        request.timeoutInterval = 3
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("SKALA-Attendance/0.1.0 (macOS; arm64)", forHTTPHeaderField: "User-Agent")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                logger.debug("analytics \(event.rawValue): HTTP \(http.statusCode)")
            }
        } catch {
            logger.debug("analytics \(event.rawValue) failed: \(error.localizedDescription)")
        }
    }
}
