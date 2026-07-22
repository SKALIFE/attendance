import CoreGraphics
import Foundation

struct WindowBounds: Codable, Equatable, Sendable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int

    func clamped(to screen: CGRect) -> WindowBounds {
        let safeWidth = min(max(width, 360), Int(screen.width))
        let safeHeight = min(max(height, 640), Int(screen.height))
        let maxX = Int(screen.maxX) - safeWidth
        let maxY = Int(screen.maxY) - safeHeight
        return WindowBounds(
            x: min(max(x, Int(screen.minX)), maxX),
            y: min(max(y, Int(screen.minY)), maxY),
            width: safeWidth,
            height: safeHeight
        )
    }
}
