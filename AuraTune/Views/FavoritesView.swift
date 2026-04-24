import SwiftUI
import UIKit

struct FavoritesView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var historyManager: HistoryManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedTab: LibraryTab = .favorites

    private var isEnglish: Bool { languageManager.currentLanguage == "en" }

    enum LibraryTab {
        case favorites
        case history
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.auraSurface.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header with Segmented Control
                    VStack(spacing: 0) {
                        // Segmented Control with styled background
                        Picker("", selection: $selectedTab) {
                            Text(isEnglish ? "Liked Songs" : "Beğendiklerim")
                                .tag(LibraryTab.favorites)
                            Text(isEnglish ? "Past Recommendations" : "Geçmiş Öneriler")
                                .tag(LibraryTab.history)
                        }
                        .pickerStyle(.segmented)
                        .padding(14)
                    }
                    .background(
                        LinearGradient(
                            colors: [Color.auraPrimary.opacity(0.08), Color.auraTertiary.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.auraPrimary.opacity(0.2), lineWidth: 1)
                            .padding(12)
                    )

                    if selectedTab == .favorites {
                        favoritesSection
                    } else {
                        historySection
                    }
                }
            }
            .navigationTitle(isEnglish ? "Library" : "Kütüphanem")
        }
    }

    private var favoritesSection: some View {
        ZStack {
            if favoritesManager.favorites.isEmpty {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.auraPrimary.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: "heart.slash")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(.auraPrimary)
                    }
                    
                    VStack(spacing: 8) {
                        Text(isEnglish ? "No Liked Songs" : "Beğenilen Şarkı Yok")
                            .font(.title3.bold())
                            .foregroundColor(.auraOnSurface)
                        Text(isEnglish
                             ? "Heart songs from Home or Discover"
                             : "Ana sayfa veya Keşfet'ten şarkıları beğen")
                            .font(.subheadline)
                            .foregroundColor(.auraOnSurface.opacity(0.65))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.auraSurface)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isEnglish ? "Your liked songs" : "Beğendiğin şarkılar")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.auraOnSurface.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        LazyVStack(spacing: 12) {
                            ForEach(favoritesManager.favorites, id: \.stableKey) { song in
                                songCard(song: song, isFavorite: true)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }

    private var historySection: some View {
        ZStack {
            if historyManager.history.isEmpty {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.auraTertiary.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Image(systemName: "clock.badge.xmark")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(.auraTertiary)
                    }
                    
                    VStack(spacing: 8) {
                        Text(isEnglish ? "No History Yet" : "Geçmiş Yok")
                            .font(.title3.bold())
                            .foregroundColor(.auraOnSurface)
                        Text(isEnglish
                             ? "Your daily recommendations will appear here"
                             : "Günlük önerilerim burada görüntülenecek")
                            .font(.subheadline)
                            .foregroundColor(.auraOnSurface.opacity(0.65))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.auraSurface)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isEnglish ? "Recommendation history" : "Geçmiş öneriler")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.auraOnSurface.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        LazyVStack(spacing: 12) {
                            ForEach(historyManager.history, id: \.id) { entry in
                                historyCard(entry: entry, isFavorite: favoritesManager.isFavorite(entry.song))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }

    private func historyCard(entry: HistoryEntry, isFavorite: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.auraPrimary.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "music.note")
                    .foregroundColor(.auraPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.song.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.auraOnSurface)
                    .lineLimit(1)
                Text(entry.song.artist)
                    .font(.caption)
                    .foregroundColor(.auraOnSurface.opacity(0.65))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: {
                openMusicApp(title: entry.song.title, artist: entry.song.artist)
            }) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.auraPrimary)
            }

            Button(action: {
                if let index = historyManager.history.firstIndex(where: { $0.id == entry.id }) {
                    historyManager.removeEntry(at: IndexSet(integer: index))
                }
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.red.opacity(0.8))
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
    }

    private func songCard(song: SongSuggestion, isFavorite: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.auraPrimary.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "music.note")
                    .foregroundColor(.auraPrimary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.auraOnSurface)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.caption)
                    .foregroundColor(.auraOnSurface.opacity(0.65))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: {
                openMusicApp(title: song.title, artist: song.artist)
            }) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.auraPrimary)
            }

            Button(action: {
                favoritesManager.toggleFavorite(song)
            }) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isFavorite ? .red : .auraOnSurface.opacity(0.5))
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
    }


    private func openMusicApp(title: String, artist: String) {
        let query = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let platform = supabaseManager.userProfile?.platform ?? "Spotify"

        var urlString = ""
        if platform == "Spotify" {
            urlString = "spotify:search:\(query)"
        } else if platform == "Apple Music" {
            urlString = "music://search?term=\(query)"
        } else if platform == "YouTube Music" {
            urlString = "youtubemusic://search?q=\(query)"
        }

        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            var webString = "https://open.spotify.com/search/\(query)"
            if platform == "YouTube Music" { webString = "https://music.youtube.com/search?q=\(query)" }
            else if platform == "Apple Music" { webString = "https://music.apple.com/search?term=\(query)" }
            if let webURL = URL(string: webString) { UIApplication.shared.open(webURL) }
        }
    }
}
