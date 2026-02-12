import AppKit

struct NotchInfo {
    /// Center-X of the notch in screen coordinates
    let centerX: CGFloat
    /// Top-Y of the screen in screen coordinates
    let topY: CGFloat
    /// Physical notch width (or estimated width for non-notch displays)
    let notchWidth: CGFloat
    /// Whether a hardware notch was detected
    let hasNotch: Bool
}

final class NotchDetector {

    static func detect() -> NotchInfo {
        guard let screen = NSScreen.main else {
            return NotchInfo(centerX: 0, topY: 0, notchWidth: 0, hasNotch: false)
        }

        let frame = screen.frame

        if #available(macOS 12.0, *),
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea,
           left != .zero, right != .zero {
            let notchWidth = right.minX - left.maxX
            let centerX = left.maxX + notchWidth / 2.0
            return NotchInfo(
                centerX: centerX,
                topY: frame.maxY,
                notchWidth: notchWidth,
                hasNotch: true
            )
        }

        // Fallback: center of the menu-bar area
        return NotchInfo(
            centerX: frame.midX,
            topY: frame.maxY,
            notchWidth: Constants.collapsedWidth,
            hasNotch: false
        )
    }
}
