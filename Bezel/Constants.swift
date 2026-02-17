import AppKit

enum Constants {
    // Bezel dimensions — expands both horizontally and vertically
    static let collapsedWidth: CGFloat = 300
    static let expandedWidth: CGFloat = 360
    static let expandedHeight: CGFloat = 120
    static let collapsedHeightWithNotch: CGFloat = 36
    static let collapsedHeightWithoutNotch: CGFloat = 25
    static let shoulderSizeWithNotch: CGFloat = 16
    static let shoulderSizeWithoutNotch: CGFloat = 12
    static let bottomRadiusWithNotch: CGFloat = 22
    static let bottomRadiusWithoutNotch: CGFloat = 10

    // Animation
    static let openDuration: TimeInterval = 0.5     // initial open from notch
    static let expandDuration: TimeInterval = 0.25
    static let collapseDuration: TimeInterval = 0.2

    // Hover detection
    static let hoverPadding: CGFloat = 30
    static let debounceInterval: TimeInterval = 0.02

    // Bezel shape
    static let topInset: CGFloat = 32      // narrowing at each side of the top edge
    static let curveHeight: CGFloat = 12   // height of the ear curve transition
    static let bottomRadius: CGFloat = 12  // convex corner radius at bottom

    // Card styling
    static let sectionRadius: CGFloat = 14
    static let chipRadius: CGFloat = 10

    // Colors
    static let sectionColor = NSColor(white: 0.14, alpha: 1)
    static let chipColor    = NSColor(white: 0.22, alpha: 1)
    static let dimText      = NSColor(white: 0.45, alpha: 1)

    static func collapsedHeight(hasNotch: Bool) -> CGFloat {
        hasNotch ? collapsedHeightWithNotch : collapsedHeightWithoutNotch
    }

    static func shoulderSize(hasNotch: Bool) -> CGFloat {
        hasNotch ? shoulderSizeWithNotch : shoulderSizeWithoutNotch
    }

    static func bottomRadiusLimit(hasNotch: Bool) -> CGFloat {
        hasNotch ? bottomRadiusWithNotch : bottomRadiusWithoutNotch
    }
}
