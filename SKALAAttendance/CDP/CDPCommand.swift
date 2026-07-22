import Foundation

struct CDPCommand: Equatable, Sendable {
    let method: String
    let params: [String: CDPValue]

    static let pageEnable = CDPCommand(method: "Page.enable", params: [:])
    static let pageReload = CDPCommand(method: "Page.reload", params: [:])
    static let pageBringToFront = CDPCommand(method: "Page.bringToFront", params: [:])
    static let browserClose = CDPCommand(method: "Browser.close", params: [:])
    static let getWindowForTarget = CDPCommand(method: "Browser.getWindowForTarget", params: [:])
    static let targetSetDiscoverTargets = CDPCommand(method: "Target.setDiscoverTargets", params: ["discover": .bool(true)])

    static func setWindowBounds(windowID: Int, bounds: WindowBounds) -> CDPCommand {
        CDPCommand(method: "Browser.setWindowBounds", params: [
            "windowId": .int(windowID),
            "bounds": .object([
                "left": .int(bounds.x),
                "top": .int(bounds.y),
                "width": .int(bounds.width),
                "height": .int(bounds.height),
                "windowState": .string("normal")
            ])
        ])
    }

    static func navigate(to url: URL) -> CDPCommand {
        CDPCommand(method: "Page.navigate", params: ["url": .string(url.absoluteString)])
    }

    static func createTarget(url: URL) -> CDPCommand {
        CDPCommand(method: "Target.createTarget", params: ["url": .string(url.absoluteString)])
    }
}

enum CDPValue: Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: CDPValue])
    case array([CDPValue])
}
