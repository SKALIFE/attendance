import Foundation

struct CDPWindowController: Sendable {
    let client: CDPClient

    @discardableResult
    func setBounds(_ bounds: WindowBounds) async throws -> WindowBounds {
        let response = try await client.send(.getWindowForTarget)
        guard case .int(let windowID) = response.result["windowId"] else {
            throw CDPClientError.invalidMessage
        }
        try await client.send(.setWindowBounds(windowID: windowID, bounds: bounds))
        return try await currentBounds()
    }

    func currentBounds() async throws -> WindowBounds {
        let response = try await client.send(.getWindowForTarget)
        guard let bounds = response.windowBounds else {
            throw CDPClientError.invalidMessage
        }
        return bounds
    }
}

private extension CDPResponse {
    var windowBounds: WindowBounds? {
        guard case .object(let object) = result["bounds"],
              case .int(let left) = object["left"],
              case .int(let top) = object["top"],
              case .int(let width) = object["width"],
              case .int(let height) = object["height"] else {
            return nil
        }
        return WindowBounds(x: left, y: top, width: width, height: height)
    }
}
