import AppKit
import QuartzCore

// MARK: - Flipped NSView helper (Y-down coordinate system)

private class FlippedView: NSView {
    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - NotchContentView

final class NotchContentView: NSView, NSTextFieldDelegate {

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    let pomodoroTimer = PomodoroTimer()

    /// Shape mask that clips to the bezel silhouette.
    private let shapeMask = CAShapeLayer()
    private var internalShapeMorphProgress: CGFloat = 1

    /// 0 = native notch-like profile, 1 = custom Bezel silhouette.
    @objc dynamic var shapeMorphProgress: CGFloat {
        get { internalShapeMorphProgress }
        set {
            let clamped = min(max(newValue, 0), 1)
            guard clamped != internalShapeMorphProgress else { return }
            internalShapeMorphProgress = clamped
            needsLayout = true
        }
    }

    // ── Top bar (always visible) ───────────────────────────────
    private var dotView: NSView!
    private var dotIsActive = false
    private var timerDisplay: NSTextField!
    private var timerHovered = false
    private var timerTrackingArea: NSTrackingArea?

    // ── Expanded-only content ──────────────────────────────────
    private var gearIcon: NSImageView!
    private var expandedPanel: NSView!

    // Timer row
    private var timerRow: NSView!
    private var durationChip: NSView!
    private var durationLabel: NSTextField!
    private var taskLabel: NSTextField!
    private var playChip: NSView!
    private var playIcon: NSImageView!

    // Feature cards
    private var focusPalCard: NSView!
    private var focusPalLabel: NSTextField!
    private var focusPalEmoji: NSTextField!
    private var musicCard: NSView!
    private var musicLabel: NSTextField!
    private var offChip: NSView!
    private var offLabel: NSTextField!

    // ── Init ───────────────────────────────────────────────────

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    override class func defaultAnimation(forKey key: NSAnimatablePropertyKey) -> Any? {
        if key == "shapeMorphProgress" {
            return CABasicAnimation()
        }
        return super.defaultAnimation(forKey: key)
    }

    // MARK: - Build UI

    private func buildUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        // Use a custom bezel-shaped mask instead of simple cornerRadius
        shapeMask.fillColor = NSColor.white.cgColor
        layer?.mask = shapeMask

        buildTopBar()
        buildExpandedPanel()

        pomodoroTimer.onChange = { [weak self] in
            self?.refreshTimerLabel()
        }
    }

    // MARK: Top bar

    private func buildTopBar() {
        // Clickable dot
        dotView = NSView()
        dotView.wantsLayer = true
        dotView.layer?.backgroundColor = NSColor(white: 0.5, alpha: 1.0).cgColor  // dimmer gray
        dotView.layer?.cornerRadius = 5  // 10x10 dot, so radius = 5
        addSubview(dotView)

        timerDisplay = makeLabel("25:00", size: 11, weight: .medium)
        timerDisplay.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        addSubview(timerDisplay)
    }

    // MARK: Expanded panel

    private func buildExpandedPanel() {
        if let img = sfImage("gearshape", size: 14, weight: .medium) {
            gearIcon = NSImageView(image: img)
            gearIcon.contentTintColor = Constants.dimText
        } else {
            gearIcon = NSImageView()
        }
        gearIcon.alphaValue = 0
        addSubview(gearIcon)

        expandedPanel = FlippedView()
        expandedPanel.wantsLayer = true
        expandedPanel.alphaValue = 0
        addSubview(expandedPanel)

        buildTimerRow()
    }

    private func buildTimerRow() {
        timerRow = roundedBox(Constants.sectionColor, radius: Constants.sectionRadius)
        expandedPanel.addSubview(timerRow)

        durationChip = roundedBox(Constants.chipColor, radius: Constants.chipRadius)
        durationLabel = makeLabel("25 min", size: 13, weight: .semibold)
        durationChip.addSubview(durationLabel)
        timerRow.addSubview(durationChip)

        taskLabel = NSTextField()
        taskLabel.placeholderAttributedString = NSAttributedString(
            string: "Task (optional)",
            attributes: [
                .foregroundColor: NSColor(white: 0.45, alpha: 1),
                .font: NSFont.systemFont(ofSize: 13)
            ]
        )
        taskLabel.font = .systemFont(ofSize: 13)
        taskLabel.textColor = .white
        taskLabel.backgroundColor = .clear
        taskLabel.isBezeled = false
        taskLabel.focusRingType = .none
        taskLabel.isEditable = false  // disabled by default
        taskLabel.isSelectable = false
        taskLabel.drawsBackground = false
        taskLabel.delegate = self
        timerRow.addSubview(taskLabel)

        playChip = roundedBox(Constants.chipColor, radius: Constants.chipRadius)
        if let img = sfImage("play.fill", size: 12, weight: .medium) {
            playIcon = NSImageView(image: img)
            playIcon.contentTintColor = .white
        } else {
            playIcon = NSImageView()
        }
        playChip.addSubview(playIcon)
        timerRow.addSubview(playChip)
    }

    private func buildFeatureCards() {
        focusPalCard = roundedBox(Constants.sectionColor, radius: Constants.sectionRadius)
        focusPalLabel = makeLabel("Focus Pal", size: 13, weight: .medium)
        focusPalEmoji = makeLabel("🐈", size: 15)
        focusPalCard.addSubview(focusPalLabel)
        focusPalCard.addSubview(focusPalEmoji)
        expandedPanel.addSubview(focusPalCard)

        musicCard = roundedBox(Constants.sectionColor, radius: Constants.sectionRadius)
        musicLabel = makeLabel("Music", size: 13, weight: .medium)
        musicCard.addSubview(musicLabel)

        offChip = roundedBox(Constants.chipColor, radius: 6)
        offLabel = makeLabel("OFF", size: 10, weight: .bold, color: Constants.dimText)
        offChip.addSubview(offLabel)
        musicCard.addSubview(offChip)

        expandedPanel.addSubview(musicCard)
    }

    // MARK: - Layout

    override func layout() {
        super.layout()

        // Update the bezel shape mask (drawn in layer coords: y-up)
        shapeMask.frame = layer!.bounds
        shapeMask.path = bezelPath(in: layer!.bounds, morph: shapeMorphProgress)

        let w = bounds.width
        let barH: CGFloat = Constants.collapsedHeight
        let pad: CGFloat = 26
        
        // Calculate offset to keep dot/timer in same absolute screen position
        // when bezel expands horizontally
        let widthDiff = w - Constants.collapsedWidth
        let edgeOffset = widthDiff / 2

        // ── Top bar ──
        let dotSize: CGFloat = 10
        dotView.frame = NSRect(x: pad + edgeOffset, y: (barH - dotSize) / 2, width: dotSize, height: dotSize)
        dotView.layer?.cornerRadius = dotSize / 2
        
        timerDisplay.sizeToFit()
        timerDisplay.frame.origin = CGPoint(x: w - timerDisplay.frame.width - 20 - edgeOffset,
                                            y: (barH - timerDisplay.frame.height) / 2)

        // ── Expanded panel ──
        let panelX: CGFloat = 20
        let panelY: CGFloat = barH + 18
        
        // Gear icon positioned to the right of the timer (in the expanded space)
        gearIcon.frame = NSRect(x: w - 20 - edgeOffset + 8, y: (barH - 16) / 2, width: 16, height: 16)
        let panelW = w - panelX * 2
        expandedPanel.frame = NSRect(x: panelX, y: panelY,
                                     width: panelW,
                                     height: bounds.height - panelY - 12)

        layoutTimerRow(panelW)
    }

    private func layoutTimerRow(_ pw: CGFloat) {
        let rowH: CGFloat = 46
        timerRow.frame = NSRect(x: 0, y: 0, width: pw, height: rowH)

        let inset: CGFloat = 6
        let chipH: CGFloat = 32

        durationLabel.sizeToFit()
        let dw = durationLabel.frame.width + 22
        durationChip.frame = NSRect(x: inset, y: (rowH - chipH) / 2, width: dw, height: chipH)
        durationLabel.frame.origin = CGPoint(x: 11, y: (chipH - durationLabel.frame.height) / 2)

        let taskX = inset + dw + 10
        let taskW = pw - taskX - inset - 32 - 10  // leave room for play button
        taskLabel.frame = NSRect(x: taskX, y: (rowH - 20) / 2, width: taskW, height: 20)

        let playS: CGFloat = 32
        playChip.frame = NSRect(x: pw - inset - playS, y: (rowH - playS) / 2, width: playS, height: playS)
        playIcon.frame = NSRect(x: (playS - 14) / 2, y: (playS - 14) / 2, width: 14, height: 14)
    }

    private func layoutFeatureCards(_ pw: CGFloat) {
        let cardY: CGFloat = 46 + 8
        let cardH: CGFloat = 48
        let gap: CGFloat = 8
        let cardW = (pw - gap) / 2

        focusPalCard.frame = NSRect(x: 0, y: cardY, width: cardW, height: cardH)
        focusPalLabel.sizeToFit()
        focusPalEmoji.sizeToFit()
        focusPalLabel.frame.origin = CGPoint(x: 14, y: (cardH - focusPalLabel.frame.height) / 2)
        focusPalEmoji.frame.origin = CGPoint(x: cardW - focusPalEmoji.frame.width - 14,
                                             y: (cardH - focusPalEmoji.frame.height) / 2)

        musicCard.frame = NSRect(x: cardW + gap, y: cardY, width: cardW, height: cardH)
        musicLabel.sizeToFit()
        musicLabel.frame.origin = CGPoint(x: 14, y: (cardH - musicLabel.frame.height) / 2)

        offLabel.sizeToFit()
        let offW = offLabel.frame.width + 14
        let offH: CGFloat = 20
        offChip.frame = NSRect(x: cardW - offW - 12, y: (cardH - offH) / 2, width: offW, height: offH)
        offLabel.frame = NSRect(x: 7, y: (offH - offLabel.frame.height) / 2,
                                width: offLabel.frame.width, height: offLabel.frame.height)
    }

    // MARK: - Bezel shape path

    /// Creates the notch shape with ear curves (like the JS reference).
    /// Shape: curved ears at top corners, flat top between them, rounded bottom corners.
    ///
    /// Based on JS SVG paths:
    /// - Left ear:  M24 0 L24 24 Q24 0 0 0 Z
    /// - Right ear: M0 0 L0 24 Q0 0 24 0 Z
    private func bezelPath(in rect: CGRect, morph: CGFloat) -> CGPath {
        _ = morph  // unused for now, but kept for animation compatibility
        let w = rect.width
        let h = rect.height
        
        // Ear size and bottom radius (matches JS: L=12 collapsed, L=24 expanded)
        let earSize: CGFloat = 12
        let bottomRadius: CGFloat = min(12, h / 2, w / 4)
        
        // Safety: if too small, just return a rounded rect
        guard w > earSize * 2 + 4, h > earSize + bottomRadius else {
            return CGPath(roundedRect: rect, cornerWidth: min(h/2, 12), cornerHeight: min(h/2, 12), transform: nil)
        }
        
        let path = CGMutablePath()
        
        // Start at outer top-left corner (0, 0)
        path.move(to: CGPoint(x: 0, y: 0))
        
        // Left ear curve: from (0,0) curving down to (earSize, earSize)
        // Matches JS: Q24,0 → control at top-right of ear
        path.addQuadCurve(
            to: CGPoint(x: earSize, y: earSize),
            control: CGPoint(x: earSize, y: 0)
        )
        
        // Left side going down
        path.addLine(to: CGPoint(x: earSize, y: h - bottomRadius))
        
        // Bottom-left corner
        path.addQuadCurve(
            to: CGPoint(x: earSize + bottomRadius, y: h),
            control: CGPoint(x: earSize, y: h)
        )
        
        // Bottom edge
        path.addLine(to: CGPoint(x: w - earSize - bottomRadius, y: h))
        
        // Bottom-right corner
        path.addQuadCurve(
            to: CGPoint(x: w - earSize, y: h - bottomRadius),
            control: CGPoint(x: w - earSize, y: h)
        )
        
        // Right side going up
        path.addLine(to: CGPoint(x: w - earSize, y: earSize))
        
        // Right ear curve: from (w-earSize, earSize) curving up to (w, 0)
        // Matches JS: Q0,0 → control at top-left of ear
        path.addQuadCurve(
            to: CGPoint(x: w, y: 0),
            control: CGPoint(x: w - earSize, y: 0)
        )
        
        // Close path (flat top edge from (w,0) back to (0,0))
        path.closeSubpath()
        
        return path
    }

    // MARK: - Hit testing & interaction

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)

        // Dot toggle color
        if dotView.frame.insetBy(dx: -5, dy: -5).contains(loc) {
            toggleDot()
            return
        }
        
        // Timer click - toggle play/pause
        if timerDisplay.frame.insetBy(dx: -5, dy: -5).contains(loc) {
            pomodoroTimer.toggle()
            updateTimerDisplay()
            return
        }

        // Task label - enable editing when clicked
        let taskInWindow = taskLabel.convert(taskLabel.bounds, to: self)
        if taskInWindow.contains(loc) {
            taskLabel.isEditable = true
            taskLabel.isSelectable = true
            window?.makeFirstResponder(taskLabel)
            return
        }
        
        // Click outside task label - end editing
        if taskLabel.isEditable {
            endTaskEditing()
        }

        // Play / pause chip
        let playInWindow = playChip.convert(playChip.bounds, to: self)
        if playInWindow.contains(loc) {
            pomodoroTimer.toggle()
            updatePlayIcon()
            return
        }

        super.mouseDown(with: event)
    }
    
    private func endTaskEditing() {
        taskLabel.isEditable = false
        taskLabel.isSelectable = false
        window?.makeFirstResponder(nil)
    }
    
    // NSTextFieldDelegate - handle Enter key
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline(_:)) {
            endTaskEditing()
            return true
        }
        return false
    }
    
    private func toggleDot() {
        dotIsActive.toggle()
        
        let newColor: NSColor = dotIsActive 
            ? NSColor(red: 0.91, green: 0.45, blue: 0.32, alpha: 1.0)  // burnt sienna
            : NSColor(white: 0.5, alpha: 1.0)  // dimmer gray
        
        // Animate the color change
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            dotView.layer?.backgroundColor = newColor.cgColor
        }
    }
    
    // MARK: - Hover zone detection
    
    /// Returns true if the given point (in screen coordinates) is over edge zones
    /// (left side including dot, right side including timer)
    func isOverEdgeElements(screenPoint: NSPoint) -> Bool {
        guard let window = window else { return false }
        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        let viewPoint = convert(windowPoint, from: nil)
        
        // Left edge zone: from left edge to right side of dot + padding
        let leftZone = NSRect(x: 0, y: 0, width: dotView.frame.maxX + 15, height: bounds.height)
        
        // Right edge zone: from left side of timer - padding to right edge
        let rightZone = NSRect(x: timerDisplay.frame.minX - 15, y: 0, 
                               width: bounds.width - timerDisplay.frame.minX + 15, height: bounds.height)
        
        return leftZone.contains(viewPoint) || rightZone.contains(viewPoint)
    }
    
    // MARK: - Timer hover tracking
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let existing = timerTrackingArea {
            removeTrackingArea(existing)
        }
        
        let timerArea = timerDisplay.frame.insetBy(dx: -5, dy: -5)
        timerTrackingArea = NSTrackingArea(
            rect: timerArea,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: ["element": "timer"]
        )
        addTrackingArea(timerTrackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        guard let info = event.trackingArea?.userInfo as? [String: String],
              info["element"] == "timer" else { return }
        timerHovered = true
        updateTimerDisplay()
    }
    
    override func mouseExited(with event: NSEvent) {
        guard let info = event.trackingArea?.userInfo as? [String: String],
              info["element"] == "timer" else { return }
        timerHovered = false
        updateTimerDisplay()
    }
    
    private func updateTimerDisplay() {
        if timerHovered {
            // Show play/pause icon
            let symbol = pomodoroTimer.state == .running ? "⏸" : "▶"
            timerDisplay.stringValue = symbol
        } else {
            // Show time
            timerDisplay.stringValue = pomodoroTimer.displayString
        }
        timerDisplay.sizeToFit()
        needsLayout = true
    }

    private func updatePlayIcon() {
        let name = pomodoroTimer.state == .running ? "pause.fill" : "play.fill"
        if let img = sfImage(name, size: 12, weight: .medium) {
            playIcon.image = img
        }
    }

    // MARK: - Show / Hide expanded content

    func showContent() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Constants.expandDuration
            expandedPanel.animator().alphaValue = 1
            gearIcon.animator().alphaValue = 1
        }
    }

    func hideContent(completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Constants.collapseDuration
            expandedPanel.animator().alphaValue = 0
            gearIcon.animator().alphaValue = 0
        }, completionHandler: completion)
    }

    // MARK: - Timer

    private func refreshTimerLabel() {
        updateTimerDisplay()
        updatePlayIcon()
    }

    // MARK: - Helpers

    private func makeLabel(_ text: String, size: CGFloat,
                           weight: NSFont.Weight = .regular,
                           color: NSColor = .white) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: size, weight: weight)
        l.textColor = color
        l.isBezeled = false
        l.drawsBackground = false
        l.isEditable = false
        l.isSelectable = false
        return l
    }

    private func roundedBox(_ color: NSColor, radius: CGFloat) -> NSView {
        let v = FlippedView()
        v.wantsLayer = true
        v.layer?.backgroundColor = color.cgColor
        v.layer?.cornerRadius = radius
        return v
    }

    private func sfImage(_ name: String, size: CGFloat, weight: NSFont.Weight) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }
}
