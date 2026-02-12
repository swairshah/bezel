import AppKit

enum Constants {
    // Bezel dimensions — expands both horizontally and vertically
    static let collapsedWidth: CGFloat = 300
    static let collapsedHeight: CGFloat = 36
    static let expandedWidth: CGFloat = 360
    static let expandedHeight: CGFloat = 180

    // Animation
    static let openDuration: TimeInterval = 0.9     // initial open from notch
    static let expandDuration: TimeInterval = 0.3
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
}
