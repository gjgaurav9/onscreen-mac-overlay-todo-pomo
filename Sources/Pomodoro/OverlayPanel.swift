import AppKit

/// A borderless, non-activating panel that floats above every other window — and
/// across every Space and fullscreen app. Non-activating means clicking it never
/// pulls focus away from the browser / Cursor / whatever you're actually working in.
final class OverlayPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        // Appear on all Spaces, stay put when switching, and ride over fullscreen apps.
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovableByWindowBackground = true   // drag from anywhere on the body
        hidesOnDeactivate = false
        worksWhenModal = true
    }

    // Let the panel receive clicks (for the hover controls) without ever becoming
    // the key/main window, so the underlying app keeps its focus and cursor.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
