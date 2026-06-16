import SwiftUI

/// The friction interstitial shown the instant the user drifts to a non-allowed app.
/// It interrupts the *impulse* (the reflex Cmd-Tab loses its payoff) while keeping a
/// deliberate, always-available escape — the design the evidence favors over a hard,
/// no-exit lock (which provokes reactance, anxiety, and abandonment).
struct LockOverlayView: View {
    @ObservedObject var engine: TimerEngine
    /// Name of the app the user is pinned to (e.g. "Cursor"), if known.
    let pinnedName: String?
    /// Only the primary screen shows the buttons; others just dim.
    let showControls: Bool
    let onReturn: () -> Void
    let onUnlock: () -> Void

    @State private var holdProgress: CGFloat = 0
    @State private var isPressing = false

    private let holdSeconds: Double = 3

    var body: some View {
        ZStack {
            Color.black.opacity(0.80).ignoresSafeArea()

            if showControls {
                VStack(spacing: 22) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(Color(red: 0.32, green: 0.74, blue: 0.90))

                    VStack(spacing: 8) {
                        Text("Stay with it")
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("\(engine.timeString) left in this focus session.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                        if let name = pinnedName {
                            Text("You chose to stay in \(name).")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }

                    Button(action: onReturn) {
                        Text(pinnedName.map { "Return to \($0)" } ?? "Return to focus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 260, height: 46)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(red: 0.32, green: 0.74, blue: 0.90))
                            )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)

                    holdToUnlock

                    Text("Locks the reflex, not you. Force-quit (⌥⌘⎋) and the lock screen always work.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 6)
                }
                .padding(40)
            }
        }
    }

    /// Hold-to-unlock: a deliberate ~3s press disengages the lock for the rest of this
    /// phase. Effortful enough to break the impulse, never punitive or impossible.
    private var holdToUnlock: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(.white.opacity(0.10))
            GeometryReader { geo in
                Capsule()
                    .fill(.white.opacity(0.22))
                    .frame(width: geo.size.width * holdProgress)
            }
            Text(isPressing ? "Keep holding…" : "Hold to unlock")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity)
        }
        .frame(width: 260, height: 40)
        .clipShape(Capsule())
        .contentShape(Capsule())
        .onLongPressGesture(minimumDuration: holdSeconds, maximumDistance: 60, perform: {
            holdProgress = 0
            isPressing = false
            onUnlock()
        }, onPressingChanged: { pressing in
            isPressing = pressing
            withAnimation(.linear(duration: pressing ? holdSeconds : 0.25)) {
                holdProgress = pressing ? 1 : 0
            }
        })
    }
}
