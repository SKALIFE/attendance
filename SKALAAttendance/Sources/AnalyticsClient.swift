import Foundation
import os

enum AnalyticsSchema {
    static let currentVersion = 2
}

enum AnalyticsDeliveryResult: Equatable, Sendable {
    case accepted
    case suppressed
    case retryableFailure
    case invalidRequest
    case rejected(statusCode: Int)
}

struct AnalyticsRetryPolicy: Sendable {
    static let standard = AnalyticsRetryPolicy(maximumAttempts: 3, initialDelayNanoseconds: 250_000_000)

    let maximumAttempts: Int
    let initialDelayNanoseconds: UInt64

    init(maximumAttempts: Int, initialDelayNanoseconds: UInt64) {
        self.maximumAttempts = max(1, maximumAttempts)
        self.initialDelayNanoseconds = initialDelayNanoseconds
    }

    func delayNanoseconds(afterFailedAttempt attempt: Int) -> UInt64 {
        let exponent = min(max(0, attempt - 1), 6)
        return initialDelayNanoseconds.multipliedReportingOverflow(by: UInt64(1 << exponent)).partialValue
    }
}

enum AnalyticsIdentity {
    static let sessionID = UUID().uuidString
}

struct AnalyticsClient: Sendable {
    let configuration: AnalyticsConfiguration
    var session: URLSession = .shared
    var retryPolicy: AnalyticsRetryPolicy = .standard
    private let logger = Logger(subsystem: "kr.skalife.attendance", category: "analytics")

    @discardableResult
    func track(
        _ event: AnalyticsEvent,
        installationID: String,
        analyticsEnabled: Bool,
        sessionID: String = AnalyticsIdentity.sessionID,
        extraData: [String: String] = [:]
    ) async -> AnalyticsDeliveryResult {
        guard analyticsEnabled,
              configuration.isConfigured,
              let baseURL = configuration.baseURL,
              let websiteID = configuration.websiteID else {
            return .suppressed
        }

        guard let payloadData = serializedPayload(
            for: event,
            installationID: installationID,
            sessionID: sessionID,
            extraData: extraData,
            websiteID: websiteID
        ) else {
            return .invalidRequest
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("api/send"))
        request.httpMethod = "POST"
        request.timeoutInterval = 3
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = payloadData

        for attempt in 1...retryPolicy.maximumAttempts {
            let result = await send(request, event: event)
            guard result == .retryableFailure, attempt < retryPolicy.maximumAttempts else {
                return result
            }

            do {
                try await Task.sleep(
                    nanoseconds: retryPolicy.delayNanoseconds(afterFailedAttempt: attempt)
                )
            } catch {
                return .retryableFailure
            }
        }

        return .retryableFailure
    }

    func serializedPayload(
        for event: AnalyticsEvent,
        installationID: String,
        sessionID: String,
        extraData: [String: String],
        websiteID: String
    ) -> Data? {
        let data = [
            "analytics_schema": String(AnalyticsSchema.currentVersion),
            "app_version": appVersion,
            "build_number": buildNumber,
            "macos_version": ProcessInfo.processInfo.operatingSystemVersionString,
            "architecture": "arm64",
            "installation_id": installationID,
            "session_id": sessionID
        ].merging(extraData) { existing, _ in existing }

        let payload: [String: Any] = [
            "type": "event",
            "payload": [
                "website": websiteID,
                "hostname": configuration.hostname,
                "url": event.path,
                "name": event.rawValue,
                "id": installationID,
                "data": data
            ]
        ]
        return try? JSONSerialization.data(withJSONObject: payload)
    }

    static func deliveryResult(for statusCode: Int) -> AnalyticsDeliveryResult {
        switch statusCode {
        case 200..<300:
            .accepted
        case 408, 425, 429, 500..<600:
            .retryableFailure
        default:
            .rejected(statusCode: statusCode)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
    }

    private var userAgent: String {
        "SKALA-Attendance/\(appVersion) (macOS; arm64)"
    }

    private func send(
        _ request: URLRequest,
        event: AnalyticsEvent
    ) async -> AnalyticsDeliveryResult {
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                logger.debug("analytics \(event.rawValue): non-HTTP response")
                return .retryableFailure
            }

            let result = Self.deliveryResult(for: http.statusCode)
            logger.debug("analytics \(event.rawValue): HTTP \(http.statusCode)")
            return result
        } catch {
            logger.debug("analytics \(event.rawValue) transport failed")
            return .retryableFailure
        }
    }
}
