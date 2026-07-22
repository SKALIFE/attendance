import AppKit
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var status: AppStatus = .ready
    @Published var preferences: AppPreferences
    @Published var chromeDescription = "확인 전"
    @Published var chromeVersionDescription = "확인 전"
    @Published var mobileModeDescription = "적용 전"
    @Published var connectionDiagnostics: String?
    @Published private(set) var isReplayingOnboarding = false
    private(set) var appLaunchTracked = false
    private var isOpenInProgress = false

    let paths: ApplicationSupportPaths
    let preferencesStore: PreferencesStore
    private let analyticsConfiguration: AnalyticsConfiguration
    lazy var analytics = AnalyticsClient(configuration: analyticsConfiguration, preferences: preferences)
    lazy var chromeController = ChromeSessionController(paths: paths)
    lazy var loginItem = LoginItemController()
    lazy var updater = UpdateController()

    init(paths: ApplicationSupportPaths = ApplicationSupportPaths(), analyticsConfiguration: AnalyticsConfiguration? = nil) {
        self.paths = paths
        let store = JSONPreferencesStore(fileURL: paths.preferencesFile)
        preferencesStore = store
        self.analyticsConfiguration = analyticsConfiguration ?? .fromBundle
        preferences = (try? store.load()) ?? .defaults
        Task { @MainActor [weak self] in
            await self?.start()
        }
    }

    func start() async {
        refreshChromeStatus()
        updater.automaticallyChecksForUpdates = preferences.automaticUpdateChecks
        guard preferences.onboardingCompleted else {
            return
        }
        await trackCurrentLaunchIfNeeded()
    }

    func refreshChromeStatus() {
        if let url = try? ChromeLocator().executableURL() {
            chromeDescription = "설치됨"
            if let version = ChromeVersionReader().readVersion(executableURL: url)?.full {
                chromeVersionDescription = version
            }
        } else {
            chromeDescription = "미설치"
            chromeVersionDescription = "-"
        }
    }

    func completeOnboarding() async {
        preferences.onboardingCompleted = true
        isReplayingOnboarding = false
        savePreferences()
        await trackCurrentLaunchIfNeeded()
    }

    var onboardingShouldBePresented: Bool {
        !preferences.onboardingCompleted || isReplayingOnboarding
    }

    func beginOnboardingReplay() {
        isReplayingOnboarding = true
    }

    func cancelOnboardingReplay() {
        isReplayingOnboarding = false
    }

    private func trackCurrentLaunchIfNeeded() async {
        if preferences.analyticsEnabled && preferences.anonymousInstallID == nil {
            preferences.anonymousInstallID = AnonymousInstallID.generate().value
        }
        if preferences.analyticsEnabled && !preferences.installEventSent && analytics.configuration.isConfigured {
            preferences.installEventSent = true
            savePreferences()
            let prefs = preferences
            Task { [analytics] in await analytics.track(.install, preferences: prefs) }
        }
        if !appLaunchTracked {
            appLaunchTracked = true
            let prefs = preferences
            Task { [analytics] in await analytics.track(.appLaunch, preferences: prefs) }
        }
    }

    func setAnalyticsEnabled(_ enabled: Bool) async {
        let wasEnabled = preferences.analyticsEnabled
        preferences.analyticsEnabled = enabled
        guard enabled else {
            savePreferences()
            return
        }
        guard preferences.onboardingCompleted else {
            savePreferences()
            return
        }
        if preferences.anonymousInstallID == nil {
            preferences.anonymousInstallID = AnonymousInstallID.generate().value
        }
        if !preferences.installEventSent && analytics.configuration.isConfigured {
            preferences.installEventSent = true
            let prefs = preferences
            Task { [analytics] in await analytics.track(.install, preferences: prefs) }
        }
        savePreferences()
        if !wasEnabled && !appLaunchTracked {
            appLaunchTracked = true
            let prefs = preferences
            Task { [analytics] in await analytics.track(.appLaunch, preferences: prefs) }
        }
    }

    func savePreferences() {
        do {
            try preferencesStore.save(preferences)
        } catch {
            AppLogger.app.error("Failed to save preferences: \(error.localizedDescription, privacy: .public)")
        }
    }

    func openAttendance() async {
        guard !isOpenInProgress else { return }
        isOpenInProgress = true
        defer { isOpenInProgress = false }
        status = .chromeStarting
        do {
            try SafeFileManager(paths: paths).createAppDirectories()
            status = .cdpConnecting
            let restoredBounds = attendanceLaunchBounds.clampedToMainScreen()
            let appliedBounds = try await chromeController.openAttendancePage(bounds: restoredBounds)
            preferences.windowBounds = appliedBounds
            savePreferences()
            mobileModeDescription = "적용됨"
            chromeDescription = "실행 중"
            if let url = try? ChromeLocator().executableURL(),
               let version = ChromeVersionReader().readVersion(executableURL: url)?.full {
                chromeVersionDescription = version
            }
            status = .ready
            await analytics.track(.attendanceOpen, preferences: preferences)
        } catch ChromeLocatorError.notFound {
            AppLogger.chrome.error("Chrome not found")
            chromeDescription = "미설치"
            status = .chromeMissing
        } catch ChromeLocatorError.identityMismatch {
            AppLogger.chrome.error("Chrome bundle identity mismatch")
            chromeDescription = "번들 식별자 불일치"
            status = .chromeMissing
        } catch {
            AppLogger.app.error("openAttendance failed: \(error.localizedDescription, privacy: .public)")
            status = .connectionError(error.localizedDescription)
        }
    }

    var attendanceLaunchBounds: WindowBounds {
        preferences.windowBounds
    }

    func bringForward() async {
        do {
            try await chromeController.bringToFront()
            try await persistCurrentWindowBounds()
            status = .ready
        } catch {
            status = .connectionError(error.localizedDescription)
        }
    }

    func persistCurrentWindowBounds() async throws {
        preferences.windowBounds = try await chromeController.currentWindowBounds().clampedToMainScreen()
        savePreferences()
    }

    func reload() async {
        do {
            try await chromeController.reload()
            status = .ready
        } catch {
            status = .connectionError(error.localizedDescription)
        }
    }

    func resetBrowserSession() async {
        do {
            let exited = await chromeController.closeDedicatedChrome()
            guard exited else {
                status = .connectionError("Chrome이 종료되지 않았습니다. 수동으로 종료 후 다시 시도해 주세요.")
                return
            }
            try SafeFileManager(paths: paths).removeChromeProfile()
            status = .profileResetRequired
        } catch {
            status = .connectionError(error.localizedDescription)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try loginItem.setEnabled(enabled)
            preferences.launchAtLoginEnabled = enabled
            savePreferences()
        } catch {
            status = .connectionError(error.localizedDescription)
        }
    }
}

private extension WindowBounds {
    func clampedToMainScreen() -> WindowBounds {
        guard let primaryScreen = NSScreen.screens.first else { return self }
        let totalHeight = primaryScreen.frame.height
        let appKitY = Int(totalHeight) - y - height

        var targetFrame: CGRect?
        for screen in NSScreen.screens {
            if screen.visibleFrame.contains(CGPoint(x: CGFloat(x), y: CGFloat(appKitY))) {
                targetFrame = screen.visibleFrame
                break
            }
        }
        guard let frame = targetFrame ?? NSScreen.main?.visibleFrame else { return self }

        let safeWidth = min(max(width, 360), Int(frame.width))
        let safeHeight = min(max(height, 640), Int(frame.height))
        let clampedAppKitY = min(max(appKitY, Int(frame.minY)), Int(frame.maxY) - safeHeight)
        let clampedX = min(max(x, Int(frame.minX)), Int(frame.maxX) - safeWidth)
        let cdpY = Int(totalHeight) - clampedAppKitY - safeHeight

        return WindowBounds(x: clampedX, y: cdpY, width: safeWidth, height: safeHeight)
    }
}
