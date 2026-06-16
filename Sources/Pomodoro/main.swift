import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let engine = TimerEngine()
    let todos = TodoStore()
    var panel: OverlayPanel!
    private lazy var lockController = FocusLockController(engine: engine)

    /// The most recent real (non-self) foreground app — what we pin the lock to.
    private var lastForegroundApp: NSRunningApplication?
    private var cancellables = Set<AnyCancellable>()

    /// Top-left anchor of the panel. The accordion grows downward, so we keep the
    /// timer's top edge fixed rather than its bottom.
    private var anchorTopLeft: NSPoint?
    private let margin: CGFloat = 24

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A hosting controller with .preferredContentSize makes the borderless panel
        // resize to fit the SwiftUI content as the to-do drawer opens and closes.
        let controller = NSHostingController(rootView: TimerView(engine: engine, todos: todos))
        controller.sizingOptions = [.preferredContentSize]

        panel = OverlayPanel(contentRect: NSRect(x: 0, y: 0, width: 190, height: 190))
        panel.contentViewController = controller
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

    /// Restore the saved top-left, or default to the top-right corner below the menu bar.
    private func positionPanel() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size

        let topLeft: NSPoint
        if let saved = Settings.shared.panelOrigin,
           visible.contains(NSPoint(x: saved.x + 10, y: saved.y - 10)) {
            topLeft = NSPoint(x: saved.x, y: saved.y)
        } else {
            topLeft = NSPoint(x: visible.maxX - size.width - margin, y: visible.maxY - margin)
        }
        anchorTopLeft = topLeft
        panel.setFrameTopLeftPoint(topLeft)
    }

    func windowDidMove(_ notification: Notification) {
        let topLeft = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
        anchorTopLeft = topLeft
        Settings.shared.panelOrigin = topLeft
    }

    /// When the drawer opens/closes the panel resizes; keep the top edge pinned so it
    /// grows downward instead of shifting the timer.
    func windowDidResize(_ notification: Notification) {
        guard let topLeft = anchorTopLeft else { return }
        if panel.frame.minX != topLeft.x || panel.frame.maxY != topLeft.y {
            panel.setFrameTopLeftPoint(topLeft)
        }
    }
}

let app = NSApplication.shared
// .accessory: no Dock icon, no menu-bar app name — it's a pure overlay.
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
