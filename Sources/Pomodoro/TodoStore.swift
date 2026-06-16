import Foundation
import Combine

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var done: Bool

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.done = false
    }
}

/// A tiny persisted task list. Kept deliberately minimal: a focus tool's own task list
/// should support single-tasking (one clear "current" task), not become a second
/// distraction to manage.
final class TodoStore: ObservableObject {
    @Published var items: [TodoItem] = [] { didSet { save() } }

    private let key = "todoItems"

    init() { load() }

    /// Promote a task to the top so it becomes the "current" one.
    func makeCurrent(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items.remove(at: i)
        items.insert(item, at: 0)
    }

    /// The first unfinished task — the one to actually work on this session.
    var current: TodoItem? { items.first { !$0.done } }
    var remainingCount: Int { items.filter { !$0.done }.count }

    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(TodoItem(title: trimmed))
        save()
    }

    func toggle(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].done.toggle()
        save()
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func clearCompleted() {
        items.removeAll { $0.done }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else { return }
        items = decoded
    }
}
