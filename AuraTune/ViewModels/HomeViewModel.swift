import Foundation
import SwiftUI
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    @Published var dailySuggestion: SongSuggestion?
    @Published var dailyMix: [SongSuggestion] = []
    @Published var isLoadingSuggestion = false
    @Published var isLoadingMix = false
    @Published var errorMessage: String?
    @Published var mixErrorMessage: String?

    private let cacheKey = "dailySuggestion"
    private let mixCacheKey = "dailyMix"
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

        if let mixData = UserDefaults.standard.data(forKey: mixCacheKey),
           let mix = try? JSONDecoder().decode([SongSuggestion].self, from: mixData) {
            self.dailyMix = mix
        }
    }

    private func cacheSuggestion(_ suggestion: SongSuggestion) {
        if let data = try? JSONEncoder().encode(suggestion) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheDateKey)
        }
    }

    private func cacheDailyMix(_ mix: [SongSuggestion]) {
        if let data = try? JSONEncoder().encode(mix) {
            UserDefaults.standard.set(data, forKey: mixCacheKey)
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
            HistoryManager.shared.addEntry(suggestion, source: "daily")

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

    func fetchDailyMix(profile: Profile, excluding suggestion: SongSuggestion) async {
        isLoadingMix = true
        mixErrorMessage = nil
        do {
            let mix = try await GeminiService.shared.getDailyMix(
                genres: profile.genres,
                responseLanguage: LanguageManager.shared.currentLanguageFullName,
                songLanguagePreference: profile.songLanguage,
                excluding: suggestion
            )
            dailyMix = mix
            cacheDailyMix(mix)
        } catch {
            mixErrorMessage = LanguageManager.shared.currentLanguage == "en"
                ? "Could not build Daily Mix: \(error.localizedDescription)"
                : "Daily Mix oluşturulamadı: \(error.localizedDescription)"
        }
        isLoadingMix = false
    }
}
