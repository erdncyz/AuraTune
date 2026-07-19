import Foundation
import SwiftUI
import Combine

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var wakeUpTime: Date = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @Published var selectedGenres: Set<String> = []
    @Published var userName: String = ""
    @Published var selectedPlatform: String = "Spotify"
    @Published var selectedSongLanguage: SongLanguagePreference = .random
    
    @Published var isSaving = false
    @Published var errorMessage: String?
    
    let availableGenres = [
        "Pop", "Rock", "Lo-Fi", "Jazz", "Classical", "Hip-Hop", "Electronic", "Indie",
        "R&B", "Country", "Metal", "K-Pop", "Reggae", "Blues", "Soul", "Funk",
        "Punk", "Folk", "Disco", "Techno", "House", "Trance", "Dubstep",
        "Ambient", "Acoustic", "Latin", "Afrobeat",
        "Turkish Folk", "Turkish Classical", "Arabesque", "Anatolian Rock"
    ]
    let availablePlatforms = ["Spotify", "Apple Music", "YouTube Music"]

    init() {
        if let suggestedName = FirebaseManager.shared.suggestedOnboardingName(),
           !suggestedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.userName = suggestedName
        }
    }
    
    func toggleGenre(_ genre: String) {
        if selectedGenres.contains(genre) {
            selectedGenres.remove(genre)
        } else {
            if selectedGenres.count < Profile.maxGenreSelection {
                selectedGenres.insert(genre)
            }
        }
    }
    
    func completeOnboarding() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let profile = Profile(
            name: userName,
            wakeUpTime: wakeUpTime,
            genres: Array(selectedGenres),
            platform: selectedPlatform,
            songLanguage: selectedSongLanguage
        )

        do {
            try await FirebaseManager.shared.saveProfile(profile)
            try? await FirebaseManager.shared.updateAuthDisplayName(userName)
        } catch {
            errorMessage = LanguageManager.shared.currentLanguage == "en"
                ? "Your profile could not be saved. Check your connection and try again."
                : "Profilin kaydedilemedi. Bağlantını kontrol edip tekrar dene."
        }
    }
}
