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

    // Can become key so the to-do text field can receive typing. Because this is a
    // .nonactivatingPanel, becoming key does NOT activate our app — the app you're
    // working in stays the active application; only keystrokes route here while the
    // field is focused. It never becomes main.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
