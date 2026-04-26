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

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[HomeFlow] \(message)")
        #endif
    }

    private func loadCachedSuggestionIfToday() {
        guard let savedDate = UserDefaults.standard.object(forKey: cacheDateKey) as? Date,
              Calendar.current.isDateInToday(savedDate),
              let data = UserDefaults.standard.data(forKey: cacheKey),
              let suggestion = try? JSONDecoder().decode(SongSuggestion.self, from: data)
        else {
            debugLog("No valid daily cache for today")
            return
        }
        self.dailySuggestion = suggestion
        debugLog("Loaded daily suggestion from cache: \(suggestion.stableKey)")

        if let mixData = UserDefaults.standard.data(forKey: mixCacheKey),
           let mix = try? JSONDecoder().decode([SongSuggestion].self, from: mixData) {
            self.dailyMix = mix
            debugLog("Loaded daily mix from cache: count=\(mix.count)")
        }
    }

    private func cacheSuggestion(_ suggestion: SongSuggestion) {
        if let data = try? JSONEncoder().encode(suggestion) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: cacheDateKey)
            debugLog("Cached daily suggestion: \(suggestion.stableKey)")
        }
    }

    private func cacheDailyMix(_ mix: [SongSuggestion]) {
        if let data = try? JSONEncoder().encode(mix) {
            UserDefaults.standard.set(data, forKey: mixCacheKey)
            debugLog("Cached daily mix: count=\(mix.count)")
        }
    }

    private func recentExclusionPool(limit: Int = 40) -> [SongSuggestion] {
        let candidateSongs = HistoryManager.shared.history.map(\ .song) + FavoritesManager.shared.favorites
        var seenKeys = Set<String>()
        var uniqueSongs: [SongSuggestion] = []

        for song in candidateSongs {
            if seenKeys.insert(song.stableKey).inserted {
                uniqueSongs.append(song)
            }

            if uniqueSongs.count >= limit {
                break
            }
        }

        return uniqueSongs
    }

    private func enrichedSuggestionWithAIMessage(
        from suggestion: SongSuggestion,
        interfaceLanguage: String
    ) async -> SongSuggestion {
        let responseLanguage = interfaceLanguage == "en" ? "English" : "Turkish"
        let message = await GeminiService.shared.generateSongCommentary(
            title: suggestion.title,
            artist: suggestion.artist,
            responseLanguage: responseLanguage
        )

        return SongSuggestion(title: suggestion.title, artist: suggestion.artist, message: message)
    }

    // Fetch from Gemini via GeminiService
    func fetchDailySuggestion(profile: Profile, refreshMix: Bool = false) async {
        debugLog("Starting daily suggestion. platform=\(profile.platform), genres=\(profile.genres.count), songLanguage=\(profile.songLanguage.rawValue)")
        isLoadingSuggestion = true
        dailySuggestion = nil
        if refreshMix {
            dailyMix = []
            debugLog("Daily mix cleared because refreshMix=true")
        }
        errorMessage = nil
        mixErrorMessage = nil
        do {
            let exclusionPool = recentExclusionPool()
            debugLog("Daily exclusion pool built: count=\(exclusionPool.count)")
            let suggestion: SongSuggestion
            var suggestionSource = "gemini"

            if profile.platform == "Spotify" || profile.platform == "YouTube Music" {
                do {
                    suggestion = try await SpotifyService.shared.getDailySuggestion(
                        genres: profile.genres,
                        songLanguagePreference: profile.songLanguage,
                        interfaceLanguage: LanguageManager.shared.currentLanguage,
                        excluding: exclusionPool
                    )
                    suggestionSource = "spotify"
                    debugLog("Using Spotify API for \(profile.platform) suggestions (no quota limit)")
                } catch {
                    debugLog("Spotify failed (\(error.localizedDescription)), falling back to AI suggestion")
                    suggestion = try await GeminiService.shared.getSongSuggestion(
                        genres: profile.genres,
                        time: Date(),
                        responseLanguage: LanguageManager.shared.currentLanguageFullName,
                        songLanguagePreference: profile.songLanguage,
                        excluding: exclusionPool
                    )
                    suggestionSource = "gemini (spotify fallback)"
                }
            } else {
                suggestion = try await GeminiService.shared.getSongSuggestion(
                    genres: profile.genres,
                    time: Date(),
                    responseLanguage: LanguageManager.shared.currentLanguageFullName,
                    songLanguagePreference: profile.songLanguage,
                    excluding: exclusionPool
                )
            }

            debugLog("Daily suggestion selected from \(suggestionSource): \(suggestion.stableKey)")

            let finalSuggestion = await enrichedSuggestionWithAIMessage(
                from: suggestion,
                interfaceLanguage: LanguageManager.shared.currentLanguage
            )

            self.dailySuggestion = finalSuggestion
            cacheSuggestion(finalSuggestion)
            HistoryManager.shared.addEntry(finalSuggestion, source: "daily")
            debugLog("Daily suggestion added to history")

            // Schedule notification at the user's wake-up time
            NotificationManager.shared.scheduleMorningNotification(
                at: profile.wakeUpTime,
                suggestion: finalSuggestion,
                platform: profile.platform
            )

            if refreshMix || dailyMix.isEmpty {
                debugLog("Triggering daily mix build after daily suggestion")
                await fetchDailyMix(profile: profile, excluding: finalSuggestion)
            } else {
                debugLog("Keeping existing daily mix; skip rebuild after daily suggestion refresh")
            }
            
        } catch {
            debugLog("Daily suggestion failed entirely. error=\(error.localizedDescription)")
            self.errorMessage = "Öneri alınamadı: \(error.localizedDescription)"
        }
        isLoadingSuggestion = false
        debugLog("Daily suggestion flow finished")
    }

    func fetchDailyMix(profile: Profile, excluding suggestion: SongSuggestion) async {
        debugLog("Starting daily mix. platform=\(profile.platform), excludingMain=\(suggestion.stableKey)")
        isLoadingMix = true
        mixErrorMessage = nil
        do {
            let exclusionPool = recentExclusionPool(limit: 60)
            debugLog("Daily mix exclusion pool built: count=\(exclusionPool.count)")
            let mix: [SongSuggestion]
            var mixSource = "gemini"

            if profile.platform == "Spotify" || profile.platform == "YouTube Music" {
                do {
                    mix = try await SpotifyService.shared.getDailyMix(
                        genres: profile.genres,
                        songLanguagePreference: profile.songLanguage,
                        interfaceLanguage: LanguageManager.shared.currentLanguage,
                        excluding: [suggestion] + exclusionPool,
                        count: 5
                    )
                    mixSource = "spotify"
                    debugLog("Using Spotify API for \(profile.platform) daily mix (no quota limit)")
                } catch {
                    debugLog("Spotify mix failed (\(error.localizedDescription)), falling back to AI mix")
                    mix = try await GeminiService.shared.getDailyMix(
                        genres: profile.genres,
                        responseLanguage: LanguageManager.shared.currentLanguageFullName,
                        songLanguagePreference: profile.songLanguage,
                        excluding: suggestion,
                        excludingSongs: exclusionPool
                    )
                    mixSource = "gemini (spotify fallback)"
                }
            } else {
                mix = try await GeminiService.shared.getDailyMix(
                    genres: profile.genres,
                    responseLanguage: LanguageManager.shared.currentLanguageFullName,
                    songLanguagePreference: profile.songLanguage,
                    excluding: suggestion,
                    excludingSongs: exclusionPool
                )
            }

            debugLog("Daily mix built from \(mixSource): count=\(mix.count)")

            dailyMix = mix
            cacheDailyMix(mix)
        } catch {
            debugLog("Daily mix failed entirely. error=\(error.localizedDescription)")
            mixErrorMessage = LanguageManager.shared.currentLanguage == "en"
                ? "Could not build Daily Mix: \(error.localizedDescription)"
                : "Daily Mix oluşturulamadı: \(error.localizedDescription)"
        }
        isLoadingMix = false
        debugLog("Daily mix flow finished")
    }
}
