import AppKit
import QuartzCore

// MARK: - Flipped NSView helper (Y-down coordinate system)

private class FlippedView: NSView {
    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - NotchContentView

final class NotchContentView: NSView {

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
    private var catEmoji: NSTextField!
    private var timerDisplay: NSTextField!

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
        catEmoji = makeLabel("🐈", size: 13)
        addSubview(catEmoji)

        timerDisplay = makeLabel("25:00", size: 13, weight: .medium)
        timerDisplay.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
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
        buildFeatureCards()
    }

    private func buildTimerRow() {
        timerRow = roundedBox(Constants.sectionColor, radius: Constants.sectionRadius)
        expandedPanel.addSubview(timerRow)

        durationChip = roundedBox(Constants.chipColor, radius: Constants.chipRadius)
        durationLabel = makeLabel("25 min", size: 13, weight: .semibold)
        durationChip.addSubview(durationLabel)
        timerRow.addSubview(durationChip)

        taskLabel = makeLabel("Task (optional)", size: 13, color: Constants.dimText)
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
        let pad: CGFloat = 20

        // ── Top bar ──
        catEmoji.sizeToFit()
        timerDisplay.sizeToFit()
        catEmoji.frame.origin     = CGPoint(x: pad, y: (barH - catEmoji.frame.height) / 2)
        timerDisplay.frame.origin = CGPoint(x: w - timerDisplay.frame.width - pad,
                                            y: (barH - timerDisplay.frame.height) / 2)

        // ── Expanded panel ──
        let panelX: CGFloat = 12
        let panelY: CGFloat = barH + 6
        
        // Gear icon positioned at top-right of expanded area (not in top bar)
        gearIcon.frame = NSRect(x: w - 30, y: panelY - 20, width: 16, height: 16)
        let panelW = w - panelX * 2
        expandedPanel.frame = NSRect(x: panelX, y: panelY,
                                     width: panelW,
                                     height: bounds.height - panelY - 20)

        layoutTimerRow(panelW)
        layoutFeatureCards(panelW)
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

        taskLabel.sizeToFit()
        taskLabel.frame.origin = CGPoint(x: inset + dw + 10, y: (rowH - taskLabel.frame.height) / 2)

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

    /// Morphs from notch-like top profile to flat-top bezel with rounded bottom corners.
    private func bezelPath(in rect: CGRect, morph: CGFloat) -> CGPath {
        let progress = min(max(morph, 0), 1)
        let radius = min(Constants.bottomRadius, rect.height / 2, rect.width / 2)

        // 0.0: macOS-notch-like top (narrow + shoulders), 1.0: full-width flat top.
        let startInset = min(Constants.topInset, max(rect.width / 2 - 1, 0))
        let startShoulderDepth = min(Constants.curveHeight, max(rect.height - radius - 1, 0))
        let topInset = lerp(startInset, 0, progress)
        let shoulderDepth = lerp(startShoulderDepth, 0, progress)

        let minX = rect.minX
        let maxX = rect.maxX
        // Layer-backed NSView uses flipped geometry here (y-down), so top is minY.
        let topY = rect.minY
        let bottomY = rect.maxY

        let leftTopX = minX + topInset
        let rightTopX = maxX - topInset
        let shoulderY = topY + shoulderDepth

        let path = CGMutablePath()
        path.move(to: CGPoint(x: leftTopX, y: topY))
        path.addLine(to: CGPoint(x: rightTopX, y: topY))

        if shoulderDepth > 0.5 {
            path.addCurve(
                to: CGPoint(x: maxX, y: shoulderY),
                control1: CGPoint(x: rightTopX + topInset * 0.58, y: topY),
                control2: CGPoint(x: maxX, y: topY + shoulderDepth * 0.35)
            )
        } else {
            path.addLine(to: CGPoint(x: maxX, y: topY))
        }

        path.addLine(to: CGPoint(x: maxX, y: bottomY - radius))
        path.addQuadCurve(
            to: CGPoint(x: maxX - radius, y: bottomY),
            control: CGPoint(x: maxX, y: bottomY)
        )

        path.addLine(to: CGPoint(x: minX + radius, y: bottomY))
        path.addQuadCurve(
            to: CGPoint(x: minX, y: bottomY - radius),
            control: CGPoint(x: minX, y: bottomY)
        )

        path.addLine(to: CGPoint(x: minX, y: shoulderY))

        if shoulderDepth > 0.5 {
            path.addCurve(
                to: CGPoint(x: leftTopX, y: topY),
                control1: CGPoint(x: minX, y: topY + shoulderDepth * 0.35),
                control2: CGPoint(x: leftTopX - topInset * 0.58, y: topY)
            )
        } else {
            path.addLine(to: CGPoint(x: minX, y: topY))
            path.addLine(to: CGPoint(x: leftTopX, y: topY))
        }

        path.closeSubpath()
        return path
    }

    private func lerp(_ start: CGFloat, _ end: CGFloat, _ progress: CGFloat) -> CGFloat {
        start + (end - start) * progress
    }

    // MARK: - Hit testing & interaction

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)

        // Play / pause chip
        let playInWindow = playChip.convert(playChip.bounds, to: self)
        if playInWindow.contains(loc) {
            pomodoroTimer.toggle()
            updatePlayIcon()
            return
        }

        super.mouseDown(with: event)
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
        timerDisplay.stringValue = pomodoroTimer.displayString
        timerDisplay.sizeToFit()
        updatePlayIcon()
        needsLayout = true
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
