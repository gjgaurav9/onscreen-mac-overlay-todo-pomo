import Foundation

/// Durable user preferences. Intervals are deliberately configurable: the famous
/// 25/5 split is a personal heuristic from Cirillo's kitchen timer, not an
/// empirically derived optimum — so we expose it rather than hard-code it.
final class Settings {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let focus = "focusDuration"
        static let shortBreak = "shortBreakDuration"
        static let longBreak = "longBreakDuration"
        static let sessionsBeforeLongBreak = "sessionsBeforeLongBreak"
        static let autoStartBreaks = "autoStartBreaks"
        static let autoStartFocus = "autoStartFocus"
        static let soundEnabled = "soundEnabled"
        static let showSeconds = "showSeconds"
        static let focusLock = "focusLock"
        static let panelOriginX = "panelOriginX"
        static let panelOriginY = "panelOriginY"
    }

    private init() {
        // First-run defaults.
        defaults.register(defaults: [
            Key.focus: 25 * 60,
            Key.shortBreak: 5 * 60,
            Key.longBreak: 15 * 60,
            Key.sessionsBeforeLongBreak: 4,
            Key.autoStartBreaks: true,   // breaks should feel automatic, not a chore to start
            Key.autoStartFocus: false,   // returning to work stays a deliberate choice
            Key.soundEnabled: true,
            Key.showSeconds: true,
        ])
    }

    var focusDuration: TimeInterval {
        get { defaults.double(forKey: Key.focus) }
        set { defaults.set(newValue, forKey: Key.focus) }
    }
    var shortBreakDuration: TimeInterval {
        get { defaults.double(forKey: Key.shortBreak) }
        set { defaults.set(newValue, forKey: Key.shortBreak) }
    }
    var longBreakDuration: TimeInterval {
        get { defaults.double(forKey: Key.longBreak) }
        set { defaults.set(newValue, forKey: Key.longBreak) }
    }
    var sessionsBeforeLongBreak: Int {
        get { max(1, defaults.integer(forKey: Key.sessionsBeforeLongBreak)) }
        set { defaults.set(newValue, forKey: Key.sessionsBeforeLongBreak) }
    }
    var autoStartBreaks: Bool {
        get { defaults.bool(forKey: Key.autoStartBreaks) }
        set { defaults.set(newValue, forKey: Key.autoStartBreaks) }
    }
    var autoStartFocus: Bool {
        get { defaults.bool(forKey: Key.autoStartFocus) }
        set { defaults.set(newValue, forKey: Key.autoStartFocus) }
    }
    var soundEnabled: Bool {
        get { defaults.bool(forKey: Key.soundEnabled) }
        set { defaults.set(newValue, forKey: Key.soundEnabled) }
    }
    var showSeconds: Bool {
        get { defaults.bool(forKey: Key.showSeconds) }
        set { defaults.set(newValue, forKey: Key.showSeconds) }
    }
    /// "Focus Lock": during a running focus phase, impede switching to other apps.
    /// Off by default — it's an invasive, opt-in commitment device.
    var focusLock: Bool {
        get { defaults.bool(forKey: Key.focusLock) }
        set { defaults.set(newValue, forKey: Key.focusLock) }
    }

    /// Saved top-left origin of the overlay, or nil if never moved.
    var panelOrigin: CGPoint? {
        get {
            guard defaults.object(forKey: Key.panelOriginX) != nil else { return nil }
            return CGPoint(x: defaults.double(forKey: Key.panelOriginX),
                           y: defaults.double(forKey: Key.panelOriginY))
        }
        set {
            guard let p = newValue else { return }
            defaults.set(p.x, forKey: Key.panelOriginX)
            defaults.set(p.y, forKey: Key.panelOriginY)
        }
    }
}
