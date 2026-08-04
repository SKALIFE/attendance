import AppKit
import WebKit
import SwiftUI
import os

enum AuthenticationProfileFillResult: Equatable, Sendable {
    case filled
    case profileIncomplete
    case notAuthenticationPage
    case pageChanged
    case unexpectedForm
    case regionUnavailable
    case classUnavailable
    case verificationFailed

    var failureMessage: String? {
        switch self {
        case .filled:
            nil
        case .profileIncomplete:
            "설정에서 이름, 지역, 반을 모두 저장해 주세요."
        case .notAuthenticationPage:
            "SKALA 인증 화면에서만 저장된 정보를 입력할 수 있습니다."
        case .pageChanged:
            "입력 중 인증 화면이 변경되었습니다. 다시 시도해 주세요."
        case .unexpectedForm:
            "인증 화면 구성이 예상과 달라 입력을 중단했습니다."
        case .regionUnavailable:
            "저장된 지역을 현재 인증 화면에서 찾을 수 없습니다."
        case .classUnavailable:
            "저장된 반을 현재 인증 화면에서 찾을 수 없습니다."
        case .verificationFailed:
            "저장된 정보가 모두 입력되지 않았습니다. 다시 시도해 주세요."
        }
    }
}

private let authenticationProfileFillScript = """
const nameInput = document.querySelector(
    'input[type="text"][placeholder="훈련생 이름 입력"]'
);
const initialSelects = [...document.querySelectorAll('select')];
const nextButton = [...document.querySelectorAll('button')].find(
    (button) => button.textContent?.trim() === '다음 (Google 인증)'
);

if (
    !nameInput
    || initialSelects.length !== 2
    || !nextButton
    || initialSelects[0].options[0]?.textContent?.trim() !== '지역 선택'
    || initialSelects[1].options[0]?.textContent?.trim() !== '반 선택'
) {
    return 'unexpected-form';
}

const setInputValue = Object.getOwnPropertyDescriptor(
    HTMLInputElement.prototype,
    'value'
)?.set;
const setSelectValue = Object.getOwnPropertyDescriptor(
    HTMLSelectElement.prototype,
    'value'
)?.set;

if (!setInputValue || !setSelectValue) {
    return 'unexpected-form';
}

if (![...initialSelects[0].options].some((option) => option.value === regionCode)) {
    return 'region-unavailable';
}

setInputValue.call(nameInput, profileName);
nameInput.dispatchEvent(new Event('input', { bubbles: true }));
nameInput.dispatchEvent(new Event('change', { bubbles: true }));

setSelectValue.call(initialSelects[0], regionCode);
initialSelects[0].dispatchEvent(new Event('input', { bubbles: true }));
initialSelects[0].dispatchEvent(new Event('change', { bubbles: true }));

const deadline = performance.now() + 1500;
let classSelect;
while (performance.now() < deadline) {
    classSelect = document.querySelectorAll('select')[1];
    if (
        classSelect
        && !classSelect.disabled
        && [...classSelect.options].some((option) => option.value === classCode)
    ) {
        break;
    }
    await new Promise(requestAnimationFrame);
}

if (
    !classSelect
    || classSelect.disabled
    || ![...classSelect.options].some((option) => option.value === classCode)
) {
    return 'class-unavailable';
}

setSelectValue.call(classSelect, classCode);
classSelect.dispatchEvent(new Event('input', { bubbles: true }));
classSelect.dispatchEvent(new Event('change', { bubbles: true }));
await new Promise(requestAnimationFrame);

const currentSelects = document.querySelectorAll('select');
if (
    nameInput.value !== profileName
    || currentSelects[0]?.value !== regionCode
    || currentSelects[1]?.value !== classCode
) {
    return 'verification-failed';
}

return 'filled';
"""

enum AnalyticsLifecycle {
    static let installationIDKey = "anonymousInstallID"
    static let installEventSentKey = "installEventSent"
    static let installEventSchemaVersionKey = "installEventSchemaVersion"
    static let activeInstallationDayKey = "activeInstallationDay"

    static func utcDay(containing date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func shouldSendInstall(defaults: UserDefaults) -> Bool {
        defaults.integer(forKey: installEventSchemaVersionKey) < AnalyticsSchema.currentVersion
    }

    static func recordInstallDelivery(
        _ result: AnalyticsDeliveryResult,
        defaults: UserDefaults
    ) {
        guard result == .accepted else { return }
        defaults.set(true, forKey: installEventSentKey)
        defaults.set(AnalyticsSchema.currentVersion, forKey: installEventSchemaVersionKey)
    }

    static func recordActiveInstallationDelivery(
        _ result: AnalyticsDeliveryResult,
        day: String,
        defaults: UserDefaults
    ) {
        guard result == .accepted else { return }
        defaults.set(day, forKey: activeInstallationDayKey)
    }
}

@MainActor
final class AttendanceController: ObservableObject {

    let webView: WKWebView
    @Published var isLoading = true
    @Published private(set) var isAuthenticationPage = false

    private let analyticsConfig = AnalyticsConfiguration.fromBundle
    private let analyticsClient: AnalyticsClient
    private lazy var navigationDelegate = WebViewNavigationDelegate(
        onNavigationFailure: { [weak self] reason in
            self?.trackWebViewLoadFailure(reason)
        },
        onNavigationFinished: { [weak self] url in
            self?.isAuthenticationPage = isAuthenticationPageURL(url)
        }
    )
    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "kr.skalife.attendance", category: "app")

    init() {
        let config = makeMobileWebViewConfiguration()
        let view = WKWebView(
            frame: NSRect(x: 0, y: 0, width: 390, height: 780),
            configuration: config
        )
        view.customUserAgent = mobileUserAgent
        self.webView = view
        self.analyticsClient = AnalyticsClient(configuration: analyticsConfig)
        view.navigationDelegate = navigationDelegate
        view.load(URLRequest(url: attendanceURL))

        trackLifecycleEvents()
    }

    func returnToAttendance() {
        isAuthenticationPage = false
        webView.load(URLRequest(url: attendanceURL))
    }

    func reload() {
        webView.reload()
    }

    func fillAuthenticationProfile(
        name: String,
        regionCode: String,
        classCode: String
    ) async -> AuthenticationProfileFillResult {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty, !regionCode.isEmpty, !classCode.isEmpty else {
            return .profileIncomplete
        }
        guard isAuthenticationPageURL(webView.url) else {
            return .notAuthenticationPage
        }

        do {
            let rawResult = try await webView.callAsyncJavaScript(
                authenticationProfileFillScript,
                arguments: [
                    "profileName": normalizedName,
                    "regionCode": regionCode,
                    "classCode": classCode,
                ],
                in: nil,
                contentWorld: .page
            )

            guard isAuthenticationPageURL(webView.url) else {
                return .pageChanged
            }

            switch rawResult as? String {
            case "filled":
                return .filled
            case "region-unavailable":
                return .regionUnavailable
            case "class-unavailable":
                return .classUnavailable
            case "verification-failed":
                return .verificationFailed
            default:
                return .unexpectedForm
            }
        } catch {
            logger.error("authentication profile fill failed")
            return isAuthenticationPageURL(webView.url) ? .unexpectedForm : .pageChanged
        }
    }

    var analyticsEnabled: Bool {
        get { defaults.object(forKey: "analyticsEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "analyticsEnabled") }
    }

    private func trackLifecycleEvents() {
        let installationID = anonymousInstallID
        let enabled = analyticsEnabled
        let activeDay = AnalyticsLifecycle.utcDay()

        if AnalyticsLifecycle.shouldSendInstall(defaults: defaults) {
            Task {
                let result = await analyticsClient.track(
                    .install,
                    installationID: installationID,
                    analyticsEnabled: enabled
                )
                AnalyticsLifecycle.recordInstallDelivery(result, defaults: defaults)
            }
        }

        if defaults.string(forKey: AnalyticsLifecycle.activeInstallationDayKey) != activeDay {
            Task {
                let result = await analyticsClient.track(
                    .activeInstallation,
                    installationID: installationID,
                    analyticsEnabled: enabled
                )
                AnalyticsLifecycle.recordActiveInstallationDelivery(
                    result,
                    day: activeDay,
                    defaults: defaults
                )
            }
        }

        Task {
            await analyticsClient.track(
                .appLaunch,
                installationID: installationID,
                analyticsEnabled: enabled
            )
            await analyticsClient.track(
                .attendanceOpen,
                installationID: installationID,
                analyticsEnabled: enabled
            )
        }

        logger.info("app launched, analytics configured: \(self.analyticsConfig.isConfigured)")
    }

    private var anonymousInstallID: String {
        if let existing = defaults.string(forKey: AnalyticsLifecycle.installationIDKey) {
            return existing
        }

        let installationID = UUID().uuidString
        defaults.set(installationID, forKey: AnalyticsLifecycle.installationIDKey)
        return installationID
    }

    private func trackWebViewLoadFailure(_ reason: WebViewLoadFailureReason) {
        let installationID = anonymousInstallID
        let enabled = analyticsEnabled

        Task {
            await analyticsClient.track(
                .webViewLoadFailed,
                installationID: installationID,
                analyticsEnabled: enabled,
                extraData: ["reason": reason.rawValue]
            )
        }
    }
}
