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

    func fetchSuggestion(genres: [String], language: String) async {
        guard let mood = selectedMood else { return }
        isLoading = true
        suggestion = nil
        errorMessage = nil

        let moodLabel = language == "en" ? mood.nameEn : mood.nameTr

        do {
            let result = try await GeminiService.shared.getSongSuggestionForMood(
                mood: moodLabel,
                genres: genres,
                language: language == "en" ? "English" : "Turkish"
            )
            self.suggestion = result
        } catch {
            self.errorMessage = language == "en"
                ? "Could not get suggestion: \(error.localizedDescription)"
                : "Öneri alınamadı: \(error.localizedDescription)"
        }
        isLoading = false
    }
}
