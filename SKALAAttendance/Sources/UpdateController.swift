import Foundation
import Sparkle

@MainActor
final class UpdateController: ObservableObject {
    private let telemetryDelegate: UpdateTelemetryDelegate
    private let controller: SPUStandardUpdaterController?

    init() {
        let telemetryDelegate = UpdateTelemetryDelegate(
            analyticsClient: AnalyticsClient(configuration: .fromBundle)
        )
        self.telemetryDelegate = telemetryDelegate

        let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        if publicKey.isEmpty {
            controller = nil
            return
        }
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: telemetryDelegate,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    var automaticallyChecksForUpdates: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }
}

@MainActor
private final class UpdateTelemetryDelegate: NSObject, SPUUpdaterDelegate {
    private let analyticsClient: AnalyticsClient
    private let defaults = UserDefaults.standard
    private var state = UpdateTelemetryState()

    init(analyticsClient: AnalyticsClient) {
        self.analyticsClient = analyticsClient
    }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        state.beginUpdateCheck()
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        state.didFindUpdate()
        track(.updateCheck, result: .found)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        state.didNotFindUpdate()
        track(.updateCheck, result: .notFound)
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        if state.didAbortUpdateCheck() {
            track(.updateCheck, result: .error)
        }
    }

    func updater(_ updater: SPUUpdater, willDownloadUpdate item: SUAppcastItem, with request: NSMutableURLRequest) {
        track(.updateDownload, result: .starting)
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        track(.updateDownload, result: .completed)
    }

    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        state.didFailDownload()
        track(.updateDownload, result: .failed)
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        track(.updateInstall, result: .starting)
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        track(.updateInstall, result: .relaunching)
    }

    private func track(_ event: AnalyticsEvent, result: UpdateTelemetryResult) {
        guard let installationID = defaults.string(
            forKey: AnalyticsLifecycle.installationIDKey
        ) else {
            return
        }

        let analyticsEnabled = defaults.object(forKey: "analyticsEnabled") as? Bool ?? true
        Task { [analyticsClient] in
            await analyticsClient.track(
                event,
                installationID: installationID,
                analyticsEnabled: analyticsEnabled,
                extraData: ["result": result.rawValue]
            )
        }
    }
}

private enum UpdateTelemetryResult: String {
    case found
    case notFound = "not_found"
    case error
    case starting
    case completed
    case failed
    case relaunching
}

struct UpdateTelemetryState {
    private enum Stage {
        case checking
        case updateFound
        case noUpdate
        case downloadFailed
    }

    private var stage = Stage.checking

    mutating func beginUpdateCheck() {
        stage = .checking
    }

    mutating func didFindUpdate() {
        stage = .updateFound
    }

    mutating func didNotFindUpdate() {
        stage = .noUpdate
    }

    mutating func didFailDownload() {
        stage = .downloadFailed
    }

    mutating func didAbortUpdateCheck() -> Bool {
        defer { stage = .checking }
        switch stage {
        case .checking:
            return true
        case .updateFound, .noUpdate, .downloadFailed:
            return false
        }
    }
}
