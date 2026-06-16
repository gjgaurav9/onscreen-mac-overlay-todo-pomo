import SwiftUI

/// The overlay's face: a smoothly depleting ring with the time inside it.
/// Calm cool color at rest; warm/red only in the final stretch. Controls stay
/// hidden until you hover, so during deep work the widget is near-static and
/// non-magnetic (peripheral, per Calm Technology).
struct TimerView: View {
    @ObservedObject var engine: TimerEngine
    @State private var hovering = false

    private let size: CGFloat = 150
    private let ringWidth: CGFloat = 9

    var body: some View {
        ZStack {
            // Dark, low-luminance backdrop — easy on the eyes for an always-on element.
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )

            VStack(spacing: 8) {
                ringWithTime
                sessionDots
            }
            .padding(14)

            if hovering {
                controls
                    .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.15)) { hovering = h }
        }
        .contextMenu { contextMenu }
    }

    // MARK: - Ring + numeric

    private var ringWithTime: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: ringWidth)

            Circle()
                .trim(from: 0, to: engine.fractionRemaining)
                .stroke(accent, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.12), value: engine.fractionRemaining)
                .animation(.easeInOut(duration: 0.4), value: engine.phase)

            VStack(spacing: 1) {
                Text(engine.timeString)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                HStack(spacing: 3) {
                    if engine.focusLockEnabled {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(accent.opacity(0.9))
                    }
                    Text(engine.phase.label)
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(accent.opacity(0.9))
                }
                if !engine.isRunning {
                    Text("paused")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .frame(width: 96, height: 96)
    }

    /// Dots showing progress toward the next long break — a gentle accumulation cue.
    private var sessionDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<engine.cycleLength, id: \.self) { i in
                Circle()
                    .fill(i < engine.cycleProgress ? accent : Color.white.opacity(0.18))
                    .frame(width: 5, height: 5)
            }
        }
        .frame(height: 6)
    }

    // MARK: - Hover controls

    private var controls: some View {
        VStack {
            Spacer()
            HStack(spacing: 18) {
                iconButton(engine.isRunning ? "pause.fill" : "play.fill") { engine.toggle() }
                iconButton("arrow.counterclockwise") { engine.reset() }
                iconButton("forward.fill") { engine.skip() }
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 14)
            .background(
                Capsule().fill(Color.black.opacity(0.55))
            )
            .padding(.bottom, 10)
        }
    }

    private func iconButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Right-click menu

    @ViewBuilder
    private var contextMenu: some View {
        Button(engine.isRunning ? "Pause" : "Start") { engine.toggle() }
        Button("Reset phase") { engine.reset() }
        Button("Skip to next") { engine.skip() }
        Divider()
        Toggle("Focus Lock", isOn: $engine.focusLockEnabled)
        Divider()
        Button("Quit Pomodoro") { NSApplication.shared.terminate(nil) }
    }

    // MARK: - Color

    /// Cool/calm at rest, distinct hue for breaks, red only in the final stretch.
    private var accent: Color {
        if engine.isUrgent {
            // Last 2 min of focus: amber → red as the deadline closes in (goal gradient).
            let t = engine.remaining <= 60 ? 1.0 : 0.0
            return Color(red: 1.0, green: 0.55 - 0.35 * t, blue: 0.25 - 0.25 * t)
        }
        switch engine.phase {
        case .focus:
            return Color(red: 0.32, green: 0.74, blue: 0.90)   // calm teal/blue
        case .shortBreak:
            return Color(red: 0.40, green: 0.82, blue: 0.55)   // restful green
        case .longBreak:
            return Color(red: 0.55, green: 0.72, blue: 0.95)   // soft indigo
        }
    }
}
