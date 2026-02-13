import Foundation

final class PomodoroTimer {

    enum State { case idle, running, paused }

    private(set) var state: State = .idle
    private(set) var remainingSeconds: Int
    private(set) var durationMinutes: Int = 25
    private var timer: Timer?

    var onChange: (() -> Void)?

    var displayString: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
    
    var durationString: String {
        return "\(durationMinutes) min"
    }

    init(minutes: Int = 25) {
        durationMinutes = minutes
        remainingSeconds = minutes * 60
    }
    
    func setDuration(minutes: Int) {
        durationMinutes = minutes
        if state == .idle {
            remainingSeconds = minutes * 60
        }
        onChange?()
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
                self.stop()
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

    func stop() {
        state = .idle
        timer?.invalidate()
        timer = nil
        remainingSeconds = durationMinutes * 60
        onChange?()
    }

    deinit { timer?.invalidate() }
}
