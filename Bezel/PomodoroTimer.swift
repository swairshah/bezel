import Foundation

final class PomodoroTimer {

    enum State { case idle, running, paused }

    private(set) var state: State = .idle
    private(set) var remainingSeconds: Int
    private var timer: Timer?

    var onChange: (() -> Void)?

    var displayString: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    init(minutes: Int = 25) {
        remainingSeconds = minutes * 60
    }

    func toggle() {
        switch state {
        case .idle, .paused: start()
        case .running:       pause()
        }
    }

    func start() {
        state = .running
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.remainingSeconds > 0 {
                self.remainingSeconds -= 1
                self.onChange?()
            } else {
                self.reset()
            }
        }
        onChange?()
    }

    func pause() {
        state = .paused
        timer?.invalidate()
        timer = nil
        onChange?()
    }

    func reset() {
        state = .idle
        timer?.invalidate()
        timer = nil
        remainingSeconds = 25 * 60
        onChange?()
    }

    deinit { timer?.invalidate() }
}
