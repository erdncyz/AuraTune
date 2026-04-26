import Foundation
import SwiftUI
import Combine

struct Mood: Identifiable, Equatable {
    let id = UUID()
    let nameKey: String   // localization key
    let nameTr: String
    let nameEn: String
    let emoji: String
    let color: Color
}

extension Mood {
    static let all: [Mood] = [
        Mood(nameKey: "mood_energetic",  nameTr: "Enerjik",   nameEn: "Energetic",  emoji: "⚡️", color: Color(hex: "FF9E66")),
        Mood(nameKey: "mood_calm",       nameTr: "Sakin",     nameEn: "Calm",       emoji: "🌊", color: Color(hex: "5AC8FA")),
        Mood(nameKey: "mood_focused",    nameTr: "Odaklı",    nameEn: "Focused",    emoji: "🎯", color: Color(hex: "8B5CF6")),
        Mood(nameKey: "mood_happy",      nameTr: "Mutlu",     nameEn: "Happy",      emoji: "😊", color: Color(hex: "FFD966")),
        Mood(nameKey: "mood_sad",        nameTr: "Hüzünlü",  nameEn: "Melancholic",emoji: "🌧", color: Color(hex: "6B7280")),
        Mood(nameKey: "mood_romantic",   nameTr: "Romantik",  nameEn: "Romantic",   emoji: "🌹", color: Color(hex: "FF2D55")),
        Mood(nameKey: "mood_motivated",  nameTr: "Motive",    nameEn: "Motivated",  emoji: "🚀", color: Color(hex: "34C759")),
        Mood(nameKey: "mood_nostalgic",  nameTr: "Nostaljik", nameEn: "Nostalgic",  emoji: "🎞️", color: Color(hex: "F4845F")),
    ]
}

@MainActor
class DiscoverViewModel: ObservableObject {
    @Published var selectedMood: Mood? = nil
    @Published var suggestion: SongSuggestion? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[DiscoverFlow] \(message)")
        #endif
    }

    private func enrichedSuggestionWithAIMessage(
        from suggestion: SongSuggestion,
        interfaceLanguage: String,
        mood: String
    ) async -> SongSuggestion {
        let responseLanguage = interfaceLanguage == "en" ? "English" : "Turkish"
        let message = await GeminiService.shared.generateSongCommentary(
            title: suggestion.title,
            artist: suggestion.artist,
            responseLanguage: responseLanguage,
            mood: mood
        )

        return SongSuggestion(title: suggestion.title, artist: suggestion.artist, message: message)
    }

    func fetchSuggestion(
        genres: [String],
        platform: String,
        interfaceLanguage: String,
        songLanguagePreference: SongLanguagePreference
    ) async {
        guard let mood = selectedMood else { return }
        isLoading = true
        suggestion = nil
        errorMessage = nil

        let moodLabel = interfaceLanguage == "en" ? mood.nameEn : mood.nameTr

        // Only add the mood name matching the song language preference to avoid polluting search queries
        let moodGenres: [String]
        switch songLanguagePreference {
        case .turkish:
            moodGenres = [mood.nameTr]
        case .english:
            moodGenres = [mood.nameEn]
        case .random:
            moodGenres = [mood.nameEn, mood.nameTr]
        }
        let sourceGenres = Array(Set(genres + moodGenres))
        debugLog("Starting discover suggestion. platform=\(platform), mood=\(moodLabel), langPref=\(songLanguagePreference.rawValue), genres=\(sourceGenres.count)")

        do {
            let result: SongSuggestion

            if platform == "Spotify" || platform == "YouTube Music" {
                do {
                    result = try await SpotifyService.shared.getDailySuggestion(
                        genres: sourceGenres,
                        songLanguagePreference: songLanguagePreference,
                        interfaceLanguage: interfaceLanguage,
                        excluding: HistoryManager.shared.history.map(\ .song)
                    )
                    debugLog("Discover suggestion selected from spotify (for \(platform)): \(result.stableKey)")
                } catch {
                    debugLog("Spotify failed (\(error.localizedDescription)), falling back to AI for discover")
                    result = try await GeminiService.shared.getSongSuggestionForMood(
                        mood: moodLabel,
                        genres: sourceGenres,
                        responseLanguage: interfaceLanguage == "en" ? "English" : "Turkish",
                        songLanguagePreference: songLanguagePreference
                    )
                    debugLog("Discover suggestion selected from gemini (spotify fallback): \(result.stableKey)")
                }
            } else {
                result = try await GeminiService.shared.getSongSuggestionForMood(
                    mood: moodLabel,
                    genres: sourceGenres,
                    responseLanguage: interfaceLanguage == "en" ? "English" : "Turkish",
                    songLanguagePreference: songLanguagePreference
                )
                debugLog("Discover suggestion selected from gemini primary: \(result.stableKey)")
            }

            let finalSuggestion = await enrichedSuggestionWithAIMessage(
                from: result,
                interfaceLanguage: interfaceLanguage,
                mood: moodLabel
            )

            self.suggestion = finalSuggestion
            HistoryManager.shared.addEntry(finalSuggestion, source: "discover")
        } catch {
            debugLog("Discover suggestion failed entirely. error=\(error.localizedDescription)")
            self.errorMessage = interfaceLanguage == "en"
                ? "Could not get suggestion: \(error.localizedDescription)"
                : "Öneri alınamadı: \(error.localizedDescription)"
        }
        isLoading = false
    }
}
