import Foundation
import SwiftUI
import Combine

@MainActor
final class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()

    @Published private(set) var favorites: [SongSuggestion] = []

    private let storageKey = "favoriteSongs"

    private init() {
        loadFavorites()
    }

    func toggleFavorite(_ song: SongSuggestion) {
        if let index = favorites.firstIndex(where: { $0.stableKey == song.stableKey }) {
            favorites.remove(at: index)
        } else {
            favorites.insert(song, at: 0)
        }
        persistFavorites()
    }

    func isFavorite(_ song: SongSuggestion) -> Bool {
        favorites.contains(where: { $0.stableKey == song.stableKey })
    }

    func removeFavorite(at offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        persistFavorites()
    }

    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SongSuggestion].self, from: data)
        else {
            favorites = []
            return
        }
        favorites = decoded
    }

    private func persistFavorites() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
