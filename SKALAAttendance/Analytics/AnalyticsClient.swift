import Foundation

struct AnalyticsPayload: Equatable, Sendable {
    let type = "event"
    let website: String
    let hostname: String
    let url: String
    let name: String
    let distinctID: String
    let data: [String: String]

    func jsonObject() -> [String: Any] {
        [
            "type": type,
            "payload": [
                "website": website,
                "hostname": hostname,
                "url": url,
                "name": name,
                "distinctId": distinctID,
                "id": distinctID,
                "data": data
            ]
        ]
    }
}

struct AnalyticsClient: Sendable {
    let configuration: AnalyticsConfiguration
    let preferences: AppPreferences
    var session: URLSession = .shared

    func payload(for event: AnalyticsEvent, preferences current: AppPreferences) -> AnalyticsPayload? {
        guard current.analyticsEnabled,
              configuration.isConfigured,
              let websiteID = configuration.websiteID,
              let installID = current.anonymousInstallID else {
            return nil
        }
        return AnalyticsPayload(
            website: websiteID,
            hostname: configuration.hostname,
            url: event.path,
            name: event.rawValue,
            distinctID: installID,
            data: [
                "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                "build_number": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
                "macos_version": ProcessInfo.processInfo.operatingSystemVersionString,
                "architecture": "arm64"
            ]
        )
    }

    func track(_ event: AnalyticsEvent, preferences current: AppPreferences) async {
        guard let payload = payload(for: event, preferences: current),
              let baseURL = configuration.baseURL else {
            return
        }
        var request = URLRequest(url: baseURL.appendingPathComponent("api/send"))
        request.httpMethod = "POST"
        request.timeoutInterval = 3
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("SKALA-Attendance/1.0.0 (macOS; arm64)", forHTTPHeaderField: "User-Agent")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload.jsonObject())
        _ = try? await session.data(for: request)
    }
}
