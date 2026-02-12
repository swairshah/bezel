import AppKit

final class AnimationController {

    private let window: NotchWindow
    private(set) var notchInfo: NotchInfo
    private(set) var isExpanded = false
    private var isAnimating = false

    init(window: NotchWindow, notchInfo: NotchInfo) {
        self.window = window
        self.notchInfo = notchInfo
    }

    // MARK: - Public

    func updateNotchInfo(_ info: NotchInfo) {
        notchInfo = info
    }

    /// Smoothly animate from notch size to collapsed state on app launch
    func animateOpen(completion: (() -> Void)? = nil) {
        let start = notchFrame()
        let target = collapsedFrame()
        
        // Start at notch size
        window.setFrame(start, display: false)
        window.orderFront(nil)
        
        // Small delay before expanding for visual effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = Constants.openDuration
                ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1) // spring-like
                self?.window.animator().setFrame(target, display: true)
            }, completionHandler: completion)
        }
    }

    func expand(completion: (() -> Void)? = nil) {
        guard !isExpanded, !isAnimating else { return }
        isAnimating = true
        isExpanded = true

        let target = expandedFrame()

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Constants.expandDuration
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
            window.animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            self?.isAnimating = false
            completion?()
        })
    }

    func collapse(completion: (() -> Void)? = nil) {
        guard isExpanded, !isAnimating else { return }
        isAnimating = true
        isExpanded = false

        let target = collapsedFrame()

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Constants.collapseDuration
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
            window.animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            self?.isAnimating = false
            completion?()
        })
    }

    // MARK: - Frame calculations

    /// Frame matching the Mac notch (starting point for open animation)
    func notchFrame() -> NSRect {
        let w = notchInfo.notchWidth + 10  // slightly wider than notch
        let h: CGFloat = 32                 // approximate notch height
        return NSRect(
            x: notchInfo.centerX - w / 2,
            y: notchInfo.topY - h,
            width: w,
            height: h
        )
    }

    func collapsedFrame() -> NSRect {
        let w = Constants.collapsedWidth
        let h = Constants.collapsedHeight
        return NSRect(
            x: notchInfo.centerX - w / 2,
            y: notchInfo.topY - h,
            width: w,
            height: h
        )
    }

    func expandedFrame() -> NSRect {
        let w = Constants.expandedWidth
        let h = Constants.expandedHeight
        return NSRect(
            x: notchInfo.centerX - w / 2,
            y: notchInfo.topY - h,
            width: w,
            height: h
        )
    }
}
