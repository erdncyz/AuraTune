import Foundation
import SwiftUI
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    @Published var dailySuggestion: SongSuggestion?
    @Published var isLoadingSuggestion = false
    @Published var errorMessage: String?
    
    // Fetch from Gemini via GeminiService
    func fetchDailySuggestion(profile: Profile) async {
        isLoadingSuggestion = true
        dailySuggestion = nil
        errorMessage = nil
        do {
            let suggestion = try await GeminiService.shared.getSongSuggestion(
                genres: profile.genres,
                time: Date(),
                language: LanguageManager.shared.currentLanguageFullName
            )
            self.dailySuggestion = suggestion
            
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
