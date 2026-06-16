import AppKit
import SwiftUI

/// A borderless window that can still become key (the default for `.borderless` is
/// false) so the friction overlay can receive the hold-to-unlock gesture.
private final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Tier-1 Focus Lock: no system permissions. It cannot truly *prevent* an app switch
/// (only MDM-supervised Macs can), so instead it removes the switch's payoff — the
/// moment a non-allowed app comes forward it is hidden again and a full-screen
/// friction overlay appears, defaulting the user back to focus with a deliberate
/// hold-to-unlock escape.
final class FocusLockController {
    private(set) var active = false

    private let engine: TimerEngine
    /// Called when the user deliberately holds to unlock.
    var onUnlock: (() -> Void)?

    private var pinnedApp: NSRunningApplication?

    /// Communication apps that always pass, so the user never feels cut off from
    /// emergencies — the single biggest driver of lock-induced anxiety (FOMO/nomophobia).
    private let allowlist: Set<String> = [
        "com.apple.MobileSMS",   // Messages
        "com.apple.FaceTime",
        "com.apple.iCal",        // Calendar
        "com.apple.reminders",
    ]

    private var overlayWindows: [NSWindow] = []
    private var overlayVisible: Bool { !overlayWindows.isEmpty }

    init(engine: TimerEngine) {
        self.engine = engine
    }

    // MARK: - Lifecycle

    func engage(pinnedTo app: NSRunningApplication?) {
        guard !active else { return }
        active = true
        pinnedApp = app
    }

    func disengage() {
        guard active else { return }
        active = false
        pinnedApp = nil
        hideOverlay()
    }

    // MARK: - Enforcement (driven by the workspace activation observer in AppDelegate)

    func handleActivation(_ app: NSRunningApplication) {
        guard active else { return }
        guard !isAllowed(app) else { return }   // allowed app — leave the user be

        // Drift detected: pull the curtain and hide what they jumped to.
        app.hide()
        if !overlayVisible { showOverlay() }
    }

    private func isAllowed(_ app: NSRunningApplication) -> Bool {
        if app.processIdentifier == NSRunningApplication.current.processIdentifier { return true }
        if let bundle = app.bundleIdentifier {
            if bundle == pinnedApp?.bundleIdentifier { return true }
            if allowlist.contains(bundle) { return true }
        }
        return false
    }

    // MARK: - Overlay

    private func showOverlay() {
        // Deliberately bring our app forward so the overlay is interactive and the
        // distracting app loses focus. This is the one moment we steal focus.
        NSApp.activate(ignoringOtherApps: true)

        let name = pinnedApp?.localizedName
        let mainScreen = NSScreen.main

        for screen in NSScreen.screens {
            let isPrimary = (screen == mainScreen)
            let view = LockOverlayView(
                engine: engine,
                pinnedName: name,
                showControls: isPrimary,
                onReturn: { [weak self] in self?.returnToFocus() },
                onUnlock: { [weak self] in self?.unlock() }
            )
            let window = KeyableWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            window.contentView = NSHostingView(rootView: view)
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            overlayWindows.append(window)
        }
        overlayWindows.first?.makeKeyAndOrderFront(nil)
    }

    private func hideOverlay() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
    }

    private func returnToFocus() {
        hideOverlay()
        pinnedApp?.activate(options: [])
    }

    private func unlock() {
        hideOverlay()
        onUnlock?()   // AppDelegate flips engine.lockSuspended, which disengages us
    }
}
