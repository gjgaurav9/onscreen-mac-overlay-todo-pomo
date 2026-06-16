import Foundation
import AppKit
import Combine

enum Phase {
    case focus
    case shortBreak
    case longBreak

    var label: String {
        switch self {
        case .focus: return "FOCUS"
        case .shortBreak: return "BREAK"
        case .longBreak: return "LONG BREAK"
        }
    }
}

/// The clock + state machine. Time is computed from an absolute `endDate` rather
/// than by decrementing a counter, so the display never drifts even if a tick is
/// late (app busy, machine asleep).
final class TimerEngine: ObservableObject {
    @Published private(set) var phase: Phase = .focus
    @Published private(set) var remaining: TimeInterval
    @Published private(set) var isRunning = false
    /// Focus sessions completed today — feeds the progress dots and the long-break cadence.
    @Published private(set) var completedFocusSessions = 0

    /// Whether Focus Lock is armed (a user toggle, persisted).
    @Published var focusLockEnabled: Bool = Settings.shared.focusLock {
        didSet { Settings.shared.focusLock = focusLockEnabled }
    }
    /// Set when the user deliberately unlocks mid-phase; suppresses the lock for the
    /// rest of the current focus phase. Resets when the next focus phase begins.
    @Published var lockSuspended = false

    private(set) var total: TimeInterval
    private var endDate: Date?
    private var ticker: Timer?
    private let settings = Settings.shared

    init() {
        total = settings.focusDuration
        remaining = settings.focusDuration
    }

    // MARK: - Derived display values

    /// Fraction of the phase still remaining (1 → full, 0 → done). Drives the ring.
    var fractionRemaining: Double {
        guard total > 0 else { return 0 }
        return max(0, min(1, remaining / total))
    }

    var timeString: String {
        let r = Int(ceil(remaining))
        let m = r / 60
        let s = r % 60
        if settings.showSeconds {
            return String(format: "%d:%02d", m, s)
        } else {
            // Round up to the nearest minute when seconds are hidden.
            let mins = Int(ceil(remaining / 60))
            return "\(mins)m"
        }
    }

    /// Sessions completed in the current cycle toward the next long break.
    var cycleProgress: Int { completedFocusSessions % settings.sessionsBeforeLongBreak }
    var cycleLength: Int { settings.sessionsBeforeLongBreak }

    /// True only in the final stretch of a FOCUS phase — the *only* time we let the
    /// UI go red. Persistent red reads as "alarm/error" and induces low-grade stress.
    var isUrgent: Bool {
        phase == .focus && isRunning && remaining <= 120 && remaining > 0
    }

    // MARK: - Controls

    func toggle() { isRunning ? pause() : start() }

    func start() {
        if remaining <= 0 { remaining = total }
        endDate = Date().addingTimeInterval(remaining)
        isRunning = true
        schedule()
    }

    func pause() {
        recomputeRemaining()
        isRunning = false
        endDate = nil
        ticker?.invalidate()
        ticker = nil
    }

    /// Reset the current phase back to full, stopped.
    func reset() {
        pause()
        remaining = total
    }

    /// Move to the next phase without counting the current one as completed.
    func skip() {
        advance(natural: false)
    }

    // MARK: - Engine internals

    private func schedule() {
        ticker?.invalidate()
        // 0.1s keeps the ring depleting smoothly without burning CPU.
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func tick() {
        recomputeRemaining()
        if remaining <= 0 {
            advance(natural: true)
        }
    }

    private func recomputeRemaining() {
        guard let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
    }

    private func advance(natural: Bool) {
        ticker?.invalidate()
        ticker = nil
        endDate = nil

        if natural { chime() }

        switch phase {
        case .focus:
            if natural { completedFocusSessions += 1 }
            let dueForLong = completedFocusSessions > 0
                && completedFocusSessions % settings.sessionsBeforeLongBreak == 0
            phase = (natural && dueForLong) ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            phase = .focus
        }

        configureForPhase()

        // Auto-start only on a natural completion. Breaks flow automatically;
        // returning to focus stays a deliberate, friction-light choice.
        let auto = (phase == .focus) ? settings.autoStartFocus : settings.autoStartBreaks
        if natural && auto {
            start()
        } else {
            isRunning = false
        }
    }

    private func configureForPhase() {
        switch phase {
        case .focus:
            total = settings.focusDuration
            lockSuspended = false   // each fresh focus phase re-arms the lock
        case .shortBreak: total = settings.shortBreakDuration
        case .longBreak: total = settings.longBreakDuration
        }
        remaining = total
    }

    private func chime() {
        guard settings.soundEnabled else { return }
        // A single soft, consistent "done" signal — not gamified or random.
        NSSound(named: NSSound.Name("Glass"))?.play()
    }
}
