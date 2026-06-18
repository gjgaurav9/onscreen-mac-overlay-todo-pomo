import SwiftUI

/// The overlay's face: a smoothly depleting ring with the time inside it, plus an
/// accordion task list that expands *below* the timer. The timer is always the main,
/// fixed element; the to-do list is an optional drawer — it never covers the screen
/// and never becomes a separate window.
struct TimerView: View {
    @ObservedObject var engine: TimerEngine
    @ObservedObject var todos: TodoStore
    /// Called when the user starts interacting with text (open drawer / focus field):
    /// the app activates so paste, Cmd-V, and dictation tools (Wispr Flow) target the
    /// task field. The passive timer never triggers this.
    var onBeginEditing: () -> Void = {}

    @State private var hovering = false
    @State private var showTodos = false
    @State private var newTask = ""
    @State private var dragging: TodoItem?
    @State private var minimized = false
    @State private var barHover = false
    @FocusState private var addFieldFocused: Bool

    private let width: CGFloat = 190
    private let ringWidth: CGFloat = 9

    var body: some View {
        Group {
            if minimized { minimizedBar } else { fullPanel }
        }
        .contextMenu { contextMenu }
    }

    private var fullPanel: some View {
        VStack(spacing: 0) {
            timerSection
            tasksBar
            if showTodos {
                todoDrawer
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(width: width)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .overlay(alignment: .topTrailing) {
            if hovering { minimizeButton }
        }
        .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { hovering = h } }
    }

    /// Collapsed form: a thin, phase-tinted line. Click to expand the full app; drag
    /// (on the body) to reposition. Stays calm and tiny when you're not using it.
    private var minimizedBar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
            Capsule()
                .fill(accent.opacity(barHover ? 1 : 0.85))
                .frame(width: barHover ? 72 : 60, height: 4)
        }
        .frame(width: 100, height: 16)
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.easeInOut(duration: 0.15)) { barHover = h } }
        .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { minimized = false } }
        .help("Click to expand")
    }

    private var minimizeButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showTodos = false
                minimized = true
            }
        } label: {
            Image(systemName: "minus")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.black.opacity(0.45)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(7)
        .help("Minimize")
    }

    // MARK: - Timer (the main, always-visible element)

    private var timerSection: some View {
        VStack(spacing: 8) {
            ringWithTime
                .overlay(alignment: .bottom) {
                    if hovering { controls.offset(y: 10) }
                }
            sessionDots
        }
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

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

    private var controls: some View {
        HStack(spacing: 18) {
            iconButton(engine.isRunning ? "pause.fill" : "play.fill") { engine.toggle() }
            iconButton("arrow.counterclockwise") { engine.reset() }
            iconButton("forward.fill") { engine.skip() }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 14)
        .background(Capsule().fill(Color.black.opacity(0.55)))
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

    // MARK: - Tasks accordion

    /// The always-present bar that toggles the drawer. Shows the current task when
    /// collapsed, so the thing you're meant to be doing stays glanceable.
    private var tasksBar: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { showTodos.toggle() }
            if showTodos {
                onBeginEditing()
                addFieldFocused = true
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Text(collapsedLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(todos.current == nil ? 0.4 : 0.85))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if todos.remainingCount > 0 {
                    Text("\(todos.remainingCount)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Image(systemName: showTodos ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
        }
    }

    private var collapsedLabel: String {
        todos.current?.title ?? "Add a task"
    }

    private var todoDrawer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                TextField("New task", text: $newTask)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .focused($addFieldFocused)
                    .onChange(of: addFieldFocused) { focused in
                        if focused { onBeginEditing() }
                    }
                    .onSubmit {
                        todos.add(newTask)
                        newTask = ""
                        addFieldFocused = true   // keep focus for rapid entry
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))

            if !todos.items.isEmpty {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(todos.items) { item in
                            TodoRow(item: item,
                                    accent: accent,
                                    items: $todos.items,
                                    dragging: $dragging,
                                    onToggle: { todos.toggle(item.id) },
                                    onDelete: { todos.remove(item.id) },
                                    onChoose: {
                                        todos.makeCurrent(item.id)
                                        withAnimation(.easeInOut(duration: 0.18)) { showTodos = false }
                                    })
                        }
                    }
                }
                .frame(maxHeight: 170)

                if todos.items.contains(where: { $0.done }) {
                    Button("Clear completed") { todos.clearCompleted() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 14)
    }

    // MARK: - Right-click menu

    @ViewBuilder
    private var contextMenu: some View {
        Button(minimized ? "Expand" : "Minimize") {
            withAnimation(.easeInOut(duration: 0.2)) {
                if !minimized { showTodos = false }
                minimized.toggle()
            }
        }
        Divider()
        Button(engine.isRunning ? "Pause" : "Start") { engine.toggle() }
        Button("Reset phase") { engine.reset() }
        Button("Skip to next") { engine.skip() }
        Divider()
        Toggle("Focus Lock", isOn: $engine.focusLockEnabled)
        Divider()
        Button("Quit Pomodoro") { NSApplication.shared.terminate(nil) }
    }

    // MARK: - Color

    private var accent: Color {
        if engine.isUrgent {
            let t = engine.remaining <= 60 ? 1.0 : 0.0
            return Color(red: 1.0, green: 0.55 - 0.35 * t, blue: 0.25 - 0.25 * t)
        }
        switch engine.phase {
        case .focus:     return Color(red: 0.32, green: 0.74, blue: 0.90)
        case .shortBreak: return Color(red: 0.40, green: 0.82, blue: 0.55)
        case .longBreak:  return Color(red: 0.55, green: 0.72, blue: 0.95)
        }
    }
}

/// One task row: checkbox + title, draggable to reorder, tap-to-choose, delete on hover.
private struct TodoRow: View {
    let item: TodoItem
    let accent: Color
    @Binding var items: [TodoItem]
    @Binding var dragging: TodoItem?
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onChoose: () -> Void

    @State private var hovering = false

    var body: some View {
        // Top-aligned so the checkbox and delete stay beside the first line when a
        // long task wraps into a tall block (otherwise they get centered far down it).
        HStack(alignment: .top, spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(item.done ? accent : Color.white.opacity(0.4))
            }
            .buttonStyle(.plain)

            // Tapping the title "chooses" this task (promotes it + collapses the drawer).
            // Truncated when idle; on hover it wraps to show the full text.
            Text(item.title)
                .font(.system(size: 12))
                .foregroundStyle(item.done ? Color.white.opacity(0.35) : Color.white.opacity(0.9))
                .strikethrough(item.done, color: .white.opacity(0.35))
                .lineLimit(hovering ? nil : 1)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: onChoose)

            if hovering {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.25))
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(rowHighlight)))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onDrag {
            dragging = item
            return NSItemProvider(object: item.id.uuidString as NSString)
        }
        .onDrop(of: ["public.text"],
                delegate: TodoDropDelegate(item: item, items: $items, dragging: $dragging))
    }

    private var rowHighlight: Double {
        if dragging?.id == item.id { return 0.12 }
        return hovering ? 0.05 : 0
    }
}

/// Reorders the list as a dragged row passes over others. Mutating `items` (a binding
/// to the store's array) persists automatically via the store's didSet.
private struct TodoDropDelegate: DropDelegate {
    let item: TodoItem
    @Binding var items: [TodoItem]
    @Binding var dragging: TodoItem?

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging.id != item.id,
              let from = items.firstIndex(where: { $0.id == dragging.id }),
              let to = items.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}
