import Foundation
import SwiftUI
import Combine

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var wakeUpTime: Date = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @Published var selectedGenres: Set<String> = []
    @Published var userName: String = ""
    @Published var selectedPlatform: String = "Spotify"
    
    @Published var isSaving = false
    
    let availableGenres = [
        "Pop", "Rock", "Lo-Fi", "Jazz", "Classical", "Hip-Hop", "Electronic", "Indie",
        "R&B", "Country", "Metal", "K-Pop", "Reggae", "Blues", "Soul", "Funk",
        "Punk", "Folk", "Disco", "Techno", "House", "Trance", "Dubstep",
        "Ambient", "Acoustic", "Latin", "Afrobeat",
        "Turkish Folk", "Turkish Classical", "Arabesque", "Anatolian Rock"
    ]
    let availablePlatforms = ["Spotify", "Apple Music", "YouTube Music"]
    
    func toggleGenre(_ genre: String) {
        if selectedGenres.contains(genre) {
            selectedGenres.remove(genre)
        } else {
            if selectedGenres.count < 3 {
                selectedGenres.insert(genre)
            }
        }
    }
    
    func completeOnboarding() async {
        isSaving = true
        let profile = Profile(
            name: userName,
            wakeUpTime: wakeUpTime,
            genres: Array(selectedGenres),
            platform: selectedPlatform
        )
        
        await SupabaseManager.shared.saveProfile(profile)
        isSaving = false
    }
}
