import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let engine = TimerEngine()
    var panel: OverlayPanel!
    private lazy var lockController = FocusLockController(engine: engine)

    /// The most recent real (non-self) foreground app — what we pin the lock to.
    private var lastForegroundApp: NSRunningApplication?
    private var cancellables = Set<AnyCancellable>()

    private let panelSize = NSSize(width: 150, height: 150)
    private let margin: CGFloat = 24

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hosting = NSHostingView(rootView: TimerView(engine: engine))

        panel = OverlayPanel(contentRect: NSRect(origin: .zero, size: panelSize))
        panel.contentView = hosting
        panel.delegate = self

        positionPanel()
        panel.orderFrontRegardless()

        setupFocusLock()
    }

    // MARK: - Focus Lock wiring

    private func setupFocusLock() {
        lastForegroundApp = NSWorkspace.shared.frontmostApplication
        lockController.onUnlock = { [weak self] in self?.engine.lockSuspended = true }

        // One always-on observer: tracks the foreground app and, while locked,
        // feeds activations to the controller for enforcement.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let self,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }
            if app.processIdentifier != NSRunningApplication.current.processIdentifier {
                self.lastForegroundApp = app
            }
            self.lockController.handleActivation(app)
        }

        // The lock is engaged exactly when: armed + in a running focus phase + not
        // deliberately suspended this phase.
        engine.$focusLockEnabled
            .combineLatest(engine.$lockSuspended, engine.$phase, engine.$isRunning)
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled, suspended, phase, running in
                self?.syncLock(shouldLock: enabled && running && phase == .focus && !suspended)
            }
            .store(in: &cancellables)
    }

    private func syncLock(shouldLock: Bool) {
        if shouldLock && !lockController.active {
            lockController.engage(pinnedTo: lastForegroundApp)
        } else if !shouldLock && lockController.active {
            lockController.disengage()
        }
    }

    /// Restore the saved position, or default to the top-right corner below the menu bar.
    private func positionPanel() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame

        let origin: NSPoint
        if let saved = Settings.shared.panelOrigin,
           visible.contains(NSPoint(x: saved.x + panelSize.width / 2,
                                    y: saved.y + panelSize.height / 2)) {
            origin = NSPoint(x: saved.x, y: saved.y)
        } else {
            origin = NSPoint(x: visible.maxX - panelSize.width - margin,
                             y: visible.maxY - panelSize.height - margin)
        }
        panel.setFrameOrigin(origin)
    }

    func windowDidMove(_ notification: Notification) {
        Settings.shared.panelOrigin = panel.frame.origin
    }
}

let app = NSApplication.shared
// .accessory: no Dock icon, no menu-bar app name — it's a pure overlay.
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
