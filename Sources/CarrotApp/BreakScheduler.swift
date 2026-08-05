import Foundation
import Combine

enum TimeDisplayFormat: String, CaseIterable, Identifiable {
    /// Always shows minutes and seconds, e.g. "9:42".
    case full
    /// Shows whole minutes only, e.g. "9m", once under 2 minutes remaining falls
    /// back to the full "M:SS" form so the final countdown still reads precisely.
    case compact

    var id: String { rawValue }

    var label: String {
        switch self {
        case .full: return "Full (9:42)"
        case .compact: return "Compact (9m)"
        }
    }
}

enum AlertSound: String, CaseIterable, Identifiable {
    case basso = "Basso"
    case glass = "Glass"
    case hero = "Hero"
    case ping = "Ping"
    case pop = "Pop"
    case purr = "Purr"
    case sosumi = "Sosumi"
    case submarine = "Submarine"

    var id: String { rawValue }

    var label: String { rawValue }
}

@MainActor
final class BreakScheduler: ObservableObject {
    @Published private(set) var isPaused = false
    @Published private(set) var isOnBreak = false
    @Published private(set) var breakFinished = false
    @Published private(set) var secondsRemaining: Int
    @Published private(set) var pausedSeconds = 0

    @Published var workIntervalMinutes: Int {
        didSet {
            UserDefaults.standard.set(workIntervalMinutes, forKey: Keys.workInterval)
            resetIfIdle()
        }
    }

    @Published var breakDurationSeconds: Int {
        didSet { UserDefaults.standard.set(breakDurationSeconds, forKey: Keys.breakDuration) }
    }

    @Published var timeDisplayFormat: TimeDisplayFormat {
        didSet { UserDefaults.standard.set(timeDisplayFormat.rawValue, forKey: Keys.timeDisplayFormat) }
    }

    @Published var alertSoundEnabled: Bool {
        didSet { UserDefaults.standard.set(alertSoundEnabled, forKey: Keys.alertSoundEnabled) }
    }

    @Published var alertSound: AlertSound {
        didSet { UserDefaults.standard.set(alertSound.rawValue, forKey: Keys.alertSound) }
    }

    @Published var alertVolume: Double {
        didSet { UserDefaults.standard.set(alertVolume, forKey: Keys.alertVolume) }
    }

    /// Called with `true` when a break starts and `false` when it ends (including skip/snooze).
    var onBreakStateChange: ((Bool) -> Void)?

    /// Called once when the break countdown naturally reaches zero.
    var onBreakFinished: (() -> Void)?

    private var timer: Timer?
    private let snoozeMinutes = 5

    /// Reasons the timer is currently frozen due to system state rather than the
    /// user's own pause toggle. Tracked as a set (rather than one bool) because
    /// display sleep and the screensaver start/stop independently of each other.
    enum IdleReason {
        case displayAsleep
        case screenSaverActive
    }
    private var idleReasons: Set<IdleReason> = []

    func systemDidBecomeIdle(_ reason: IdleReason) {
        idleReasons.insert(reason)
    }

    func systemDidBecomeActive(_ reason: IdleReason) {
        idleReasons.remove(reason)
    }

    private enum Keys {
        static let workInterval = "workIntervalMinutes"
        static let breakDuration = "breakDurationSeconds"
        static let timeDisplayFormat = "timeDisplayFormat"
        static let alertSoundEnabled = "alertSoundEnabled"
        static let alertSound = "alertSound"
        static let alertVolume = "alertVolume"
    }

    init() {
        let defaults = UserDefaults.standard
        let savedInterval = defaults.object(forKey: Keys.workInterval) as? Int ?? 20
        let savedDuration = defaults.object(forKey: Keys.breakDuration) as? Int ?? 20
        let savedFormat = defaults.string(forKey: Keys.timeDisplayFormat).flatMap(TimeDisplayFormat.init) ?? .full
        let savedAlertSound = defaults.string(forKey: Keys.alertSound).flatMap(AlertSound.init) ?? .glass
        workIntervalMinutes = savedInterval
        breakDurationSeconds = savedDuration
        timeDisplayFormat = savedFormat
        alertSoundEnabled = defaults.object(forKey: Keys.alertSoundEnabled) as? Bool ?? true
        alertSound = savedAlertSound
        alertVolume = defaults.object(forKey: Keys.alertVolume) as? Double ?? 1.0
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
        guard !isPaused else {
            pausedSeconds += 1
            return
        }
        guard idleReasons.isEmpty else { return }
        if isOnBreak {
            guard !breakFinished else { return }
            secondsRemaining -= 1
            if secondsRemaining <= 0 {
                secondsRemaining = 0
                breakFinished = true
                onBreakFinished?()
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
        pausedSeconds = 0
    }

    /// Restarts the current countdown (work interval or break) from the beginning and unpauses.
    func restart() {
        if isOnBreak {
            breakFinished = false
            secondsRemaining = breakDurationSeconds
        } else {
            secondsRemaining = workIntervalMinutes * 60
        }
        isPaused = false
        pausedSeconds = 0
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
        if timeDisplayFormat == .compact && secondsRemaining >= 120 {
            return "\((secondsRemaining + 59) / 60)m"
        }
        return Self.fullTimeString(secondsRemaining)
    }

    var pausedTimeString: String {
        Self.fullTimeString(pausedSeconds)
    }

    private static func fullTimeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
