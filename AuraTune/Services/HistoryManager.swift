import Foundation
import SwiftUI
import Combine

struct HistoryEntry: Codable, Identifiable {
    let id: UUID
    let song: SongSuggestion
    let timestamp: Date
    let source: String // "daily", "discover", "mix"

    enum CodingKeys: String, CodingKey {
        case id
        case song
        case timestamp
        case source
    }
}

@MainActor
final class HistoryManager: ObservableObject {
    static let shared = HistoryManager()

    @Published private(set) var history: [HistoryEntry] = []

    private let storageKey = "songHistory"
    private let maxHistoryEntries = 100

    private init() {
        loadHistory()
    }

    func addEntry(_ song: SongSuggestion, source: String = "daily") {
        let entry = HistoryEntry(id: UUID(), song: song, timestamp: Date(), source: source)
        history.insert(entry, at: 0)

        // Keep only last 100 entries
        if history.count > maxHistoryEntries {
            history = Array(history.prefix(maxHistoryEntries))
        }

        persistHistory()
    }

    func removeEntry(at offsets: IndexSet) {
        history.remove(atOffsets: offsets)
        persistHistory()
    }

    func clearHistory() {
        history = []
        persistHistory()
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data)
        else {
            history = []
            return
        }
        history = decoded
    }

    private func persistHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
