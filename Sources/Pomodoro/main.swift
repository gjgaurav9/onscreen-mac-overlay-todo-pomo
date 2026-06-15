import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let engine = TimerEngine()
    var panel: OverlayPanel!

    private let panelSize = NSSize(width: 150, height: 150)
    private let margin: CGFloat = 24

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hosting = NSHostingView(rootView: TimerView(engine: engine))

        panel = OverlayPanel(contentRect: NSRect(origin: .zero, size: panelSize))
        panel.contentView = hosting
        panel.delegate = self

        positionPanel()
        panel.orderFrontRegardless()
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
