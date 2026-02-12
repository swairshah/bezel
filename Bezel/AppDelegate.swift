import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var notchWindow: NotchWindow!
    private var contentView: NotchContentView!
    private var animationController: AnimationController!
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var debounceTimer: Timer?
    private var isEnabled = true

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupNotchOverlay()
        setupMouseMonitoring()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor  { NSEvent.removeMonitor(m) }
    }

    // MARK: - Menu-bar icon

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Bezel") {
                button.image = img
            } else {
                button.title = "\u{25C6}"
            }
        }

        let menu = NSMenu()
        let toggle = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled(_:)), keyEquivalent: "e")
        toggle.target = self
        toggle.state = .on
        menu.addItem(toggle)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Bezel", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        isEnabled.toggle()
        sender.state = isEnabled ? .on : .off

        if isEnabled {
            notchWindow.orderFront(nil)
        } else {
            collapseNotch()
            notchWindow.orderOut(nil)
        }
    }

    // MARK: - Notch overlay

    private func setupNotchOverlay() {
        let info = NotchDetector.detect()

        notchWindow = NotchWindow(contentRect: .zero)
        contentView = NotchContentView()
        animationController = AnimationController(window: notchWindow, notchInfo: info)

        // Start with notch frame (will animate to collapsed)
        let notchFrame = animationController.notchFrame()
        notchWindow.setFrame(notchFrame, display: false)

        contentView.frame = notchWindow.contentView!.bounds
        contentView.autoresizingMask = [.width, .height]
        notchWindow.contentView?.addSubview(contentView)

        // Smooth open animation from notch to collapsed state
        animationController.animateOpen()
    }

    // MARK: - Mouse monitoring

    private func setupMouseMonitoring() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.handleMouseMoved()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved()
            return event
        }
    }

    private func handleMouseMoved() {
        guard isEnabled else { return }

        let mouse = NSEvent.mouseLocation

        // Use different hover zones depending on current state:
        //   collapsed → smaller zone around the bar
        //   expanded  → larger zone covering the full panel
        let reference = animationController.isExpanded
            ? animationController.expandedFrame()
            : animationController.collapsedFrame()
        let zone = reference.insetBy(dx: -Constants.hoverPadding,
                                     dy: -Constants.hoverPadding)
        let near = zone.contains(mouse)

        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.debounceInterval,
            repeats: false
        ) { [weak self] _ in
            guard let self else { return }
            near ? self.expandNotch() : self.collapseNotch()
        }
    }

    private func expandNotch() {
        notchWindow.ignoresMouseEvents = false
        contentView.showContent()
        animationController.expand()
    }

    private func collapseNotch() {
        notchWindow.ignoresMouseEvents = true
        contentView.hideContent()
        animationController.collapse()
    }

    // MARK: - Screen changes

    @objc private func screenDidChange() {
        let info = NotchDetector.detect()
        animationController.updateNotchInfo(info)
        notchWindow.setFrame(animationController.collapsedFrame(), display: true)
    }
}
