import Foundation
import Combine

@MainActor
final class BreakScheduler: ObservableObject {
    @Published private(set) var isPaused = false
    @Published private(set) var isOnBreak = false
    @Published private(set) var breakFinished = false
    @Published private(set) var secondsRemaining: Int

    @Published var workIntervalMinutes: Int {
        didSet {
            UserDefaults.standard.set(workIntervalMinutes, forKey: Keys.workInterval)
            resetIfIdle()
        }
    }

    @Published var breakDurationSeconds: Int {
        didSet { UserDefaults.standard.set(breakDurationSeconds, forKey: Keys.breakDuration) }
    }

    /// Called with `true` when a break starts and `false` when it ends (including skip/snooze).
    var onBreakStateChange: ((Bool) -> Void)?

    private var timer: Timer?
    private let snoozeMinutes = 5

    private enum Keys {
        static let workInterval = "workIntervalMinutes"
        static let breakDuration = "breakDurationSeconds"
    }

    init() {
        let defaults = UserDefaults.standard
        let savedInterval = defaults.object(forKey: Keys.workInterval) as? Int ?? 20
        let savedDuration = defaults.object(forKey: Keys.breakDuration) as? Int ?? 20
        workIntervalMinutes = savedInterval
        breakDurationSeconds = savedDuration
        secondsRemaining = savedInterval * 60
    }

    func start() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard !isPaused else { return }
        if isOnBreak {
            guard !breakFinished else { return }
            secondsRemaining -= 1
            if secondsRemaining <= 0 {
                secondsRemaining = 0
                breakFinished = true
            }
        } else {
            guard secondsRemaining > 0 else {
                startBreak()
                return
            }
            secondsRemaining -= 1
        }
    }

    private func startBreak() {
        isOnBreak = true
        breakFinished = false
        secondsRemaining = breakDurationSeconds
        onBreakStateChange?(true)
    }

    private func endBreak() {
        isOnBreak = false
        breakFinished = false
        secondsRemaining = workIntervalMinutes * 60
        onBreakStateChange?(false)
    }

    /// Ends the break early, whether it's still counting down or already finished and waiting to be dismissed.
    func skipBreak() {
        guard isOnBreak else { return }
        endBreak()
    }

    func snoozeBreak() {
        guard isOnBreak else { return }
        isOnBreak = false
        breakFinished = false
        secondsRemaining = snoozeMinutes * 60
        onBreakStateChange?(false)
    }

    func togglePause() {
        isPaused.toggle()
    }

    func startBreakNow() {
        guard !isOnBreak else { return }
        startBreak()
    }

    private func resetIfIdle() {
        guard !isOnBreak else { return }
        secondsRemaining = workIntervalMinutes * 60
    }

    var timeString: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%d:%02d", m, s)
    }
}
