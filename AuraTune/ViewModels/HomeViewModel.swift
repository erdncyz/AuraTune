import Foundation
import SwiftUI
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    @Published var dailySuggestion: SongSuggestion?
    @Published var isLoadingSuggestion = false
    @Published var errorMessage: String?

    private let cacheKey = "dailySuggestion"
    private let cacheDateKey = "dailySuggestionDate"

    init() {
        loadCachedSuggestionIfToday()
    }

    private func loadCachedSuggestionIfToday() {
        guard let savedDate = UserDefaults.standard.object(forKey: cacheDateKey) as? Date,
              Calendar.current.isDateInToday(savedDate),
              let data = UserDefaults.standard.data(forKey: cacheKey),
              let suggestion = try? JSONDecoder().decode(SongSuggestion.self, from: data)
        else { return }
        self.dailySuggestion = suggestion
    }

    private func cacheSuggestion(_ suggestion: SongSuggestion) {
        if let data = try? JSONEncoder().encode(suggestion) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheDateKey)
        }
    }

    // Fetch from Gemini via GeminiService
    func fetchDailySuggestion(profile: Profile) async {
        isLoadingSuggestion = true
        dailySuggestion = nil
        errorMessage = nil
        do {
            let suggestion = try await GeminiService.shared.getSongSuggestion(
                genres: profile.genres,
                time: Date(),
                responseLanguage: LanguageManager.shared.currentLanguageFullName,
                songLanguagePreference: profile.songLanguage
            )
            self.dailySuggestion = suggestion
            cacheSuggestion(suggestion)

            // Schedule notification at the user's wake-up time
            NotificationManager.shared.scheduleMorningNotification(
                at: profile.wakeUpTime,
                suggestion: suggestion,
                platform: profile.platform
            )
            
        } catch {
            self.errorMessage = "Öneri alınamadı: \(error.localizedDescription)"
        }
        isLoadingSuggestion = false
    }
}
