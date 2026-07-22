import Foundation

struct MobileEmulationProfile: Equatable, Sendable {
    let viewportWidth = 430
    let viewportHeight = 900
    let deviceScaleFactor = 3
    let maxTouchPoints = 5
    let platform = "Android"
    let platformVersion = "15"
    let model = "Pixel 9"

    func userAgent(chromeMajorVersion: Int, fullVersion: String? = nil) -> String {
        let version = fullVersion ?? "\(chromeMajorVersion).0.0.0"
        return "Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/\(version) Mobile Safari/537.36"
    }

    func deviceMetricsCommand() -> CDPCommand {
        CDPCommand(method: "Emulation.setDeviceMetricsOverride", params: [
            "width": .int(viewportWidth),
            "height": .int(viewportHeight),
            "deviceScaleFactor": .int(deviceScaleFactor),
            "mobile": .bool(true),
            "screenWidth": .int(viewportWidth),
            "screenHeight": .int(viewportHeight),
            "screenOrientation": .object([
                "type": .string("portraitPrimary"),
                "angle": .int(0)
            ])
        ])
    }

    func touchCommand() -> CDPCommand {
        CDPCommand(method: "Emulation.setTouchEmulationEnabled", params: [
            "enabled": .bool(true),
            "maxTouchPoints": .int(maxTouchPoints)
        ])
    }

    func userAgentCommand(chromeMajorVersion: Int, fullVersion: String? = nil) -> CDPCommand {
        let version = fullVersion ?? "\(chromeMajorVersion).0.0.0"
        return CDPCommand(method: "Emulation.setUserAgentOverride", params: [
            "userAgent": .string(userAgent(chromeMajorVersion: chromeMajorVersion, fullVersion: fullVersion)),
            "platform": .string(platform),
            "userAgentMetadata": .object([
                "mobile": .bool(true),
                "platform": .string(platform),
                "platformVersion": .string(platformVersion),
                "model": .string(model),
                "architecture": .string("arm"),
                "bitness": .string("64"),
                "fullVersionList": .array([
                    .object(["brand": .string("Chromium"), "version": .string(version)]),
                    .object(["brand": .string("Google Chrome"), "version": .string(version)])
                ])
            ])
        ])
    }
}
