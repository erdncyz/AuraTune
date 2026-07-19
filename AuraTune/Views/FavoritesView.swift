import SwiftUI
import UIKit

struct FavoritesView: View {
    @EnvironmentObject var firebaseManager: FirebaseManager
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var historyManager: HistoryManager
    @State private var selectedTab: LibraryTab = .favorites
    @State private var showClearHistoryConfirmation = false

    private var isEnglish: Bool { languageManager.currentLanguage == "en" }

    private enum LibraryTab {
        case favorites
        case history
    }

    var body: some View {
        NavigationStack {
            AuraFixedHeaderLayout {
                AuraPageHeader(
                    eyebrow: isEnglish ? "Your collection" : "Koleksiyonun",
                    title: isEnglish ? "Library" : "Kütüphane",
                    subtitle: librarySummary,
                    icon: "heart.text.square.fill",
                    accent: .auraPrimary
                )
            } content: {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        segmentPicker

                        if selectedTab == .favorites {
                            favoritesContent
                        } else {
                            historyContent
                        }
                    }
                    .padding(.horizontal, AuraMetrics.pagePadding)
                    .padding(.top, 20)
                    .padding(.bottom, 36)
                    .auraContentColumn()
                }
            }
            .navigationBarHidden(true)
            .alert(isEnglish ? "Clear history?" : "Geçmiş temizlensin mi?", isPresented: $showClearHistoryConfirmation) {
                Button(isEnglish ? "Cancel" : "Vazgeç", role: .cancel) {}
                Button(isEnglish ? "Clear" : "Temizle", role: .destructive) {
                    historyManager.clearHistory()
                }
            } message: {
                Text(isEnglish
                    ? "All past recommendations will be removed."
                    : "Tüm geçmiş öneriler kaldırılacak.")
            }
        }
        .preferredColorScheme(.light)
    }

    private var librarySummary: String {
        if isEnglish {
            return "\(favoritesManager.favorites.count) liked · \(historyManager.history.count) in history"
        }
        return "\(favoritesManager.favorites.count) beğeni · \(historyManager.history.count) geçmiş öneri"
    }

    private var segmentPicker: some View {
        HStack(spacing: 4) {
            segmentButton(
                title: isEnglish ? "Liked" : "Beğenilenler",
                count: favoritesManager.favorites.count,
                icon: "heart.fill",
                tab: .favorites
            )
            segmentButton(
                title: isEnglish ? "History" : "Geçmiş",
                count: historyManager.history.count,
                icon: "clock.arrow.circlepath",
                tab: .history
            )
        }
        .padding(4)
        .background(Color.auraOutline.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.controlRadius, style: .continuous))
    }

    private func segmentButton(title: String, count: Int, icon: String, tab: LibraryTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.easeOut(duration: 0.18)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("\(count)")
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(isSelected ? Color.auraPrimary.opacity(0.12) : Color.auraOutline.opacity(0.6))
                    .clipShape(Capsule())
            }
            .foregroundStyle(isSelected ? Color.auraPrimaryDark : Color.auraTextSecondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(isSelected ? Color.auraSurfaceElevated : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .shadow(color: isSelected ? Color.auraDeepAccent.opacity(0.07) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var favoritesContent: some View {
        if favoritesManager.favorites.isEmpty {
            AuraEmptyState(
                icon: "heart",
                title: isEnglish ? "No liked songs yet" : "Henüz beğenilen şarkı yok",
                message: isEnglish
                    ? "Songs you heart from Home or Discover appear here."
                    : "Ana Sayfa veya Keşfet'te beğendiğin şarkılar burada görünür.",
                tint: .auraPrimary
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                collectionHeader(
                    title: isEnglish ? "Liked songs" : "Beğenilen şarkılar",
                    caption: isEnglish ? "Newest first" : "En yeni önce"
                )

                LazyVStack(spacing: 0) {
                    ForEach(Array(favoritesManager.favorites.enumerated()), id: \.element.stableKey) { index, song in
                        songRow(song: song, metadata: nil) {
                            favoritesManager.toggleFavorite(song)
                        }

                        if index < favoritesManager.favorites.count - 1 {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .auraCardSurface()
            }
        }
    }

    @ViewBuilder
    private var historyContent: some View {
        if historyManager.history.isEmpty {
            AuraEmptyState(
                icon: "clock.arrow.circlepath",
                title: isEnglish ? "No listening history" : "Henüz geçmiş yok",
                message: isEnglish
                    ? "Daily and mood-based recommendations appear here."
                    : "Günlük ve ruh haline göre öneriler burada görünür.",
                tint: .auraTertiary
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    collectionHeader(
                        title: isEnglish ? "Recommendation history" : "Öneri geçmişi",
                        caption: isEnglish ? "Across every discovery" : "Tüm keşiflerinden"
                    )
                    Spacer()
                    Button {
                        showClearHistoryConfirmation = true
                    } label: {
                        Text(isEnglish ? "Clear" : "Temizle")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.auraDanger)
                            .frame(minHeight: AuraMetrics.minimumTapTarget)
                    }
                }

                LazyVStack(spacing: 0) {
                    ForEach(Array(historyManager.history.enumerated()), id: \.element.id) { index, entry in
                        songRow(song: entry.song, metadata: historyMetadata(entry)) {
                            removeHistoryEntry(entry)
                        }

                        if index < historyManager.history.count - 1 {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .auraCardSurface()
            }
        }
    }

    private func collectionHeader(title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.auraTitle)
                .foregroundStyle(Color.auraOnSurface)
            Text(caption)
                .font(.caption)
                .foregroundStyle(Color.auraTextSecondary)
        }
    }

    private func songRow(song: SongSuggestion, metadata: String?, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            albumTile

            VStack(alignment: .leading, spacing: 3) {
                Text(song.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.auraOnSurface)
                    .lineLimit(1)
                Text(song.artist)
                    .font(.caption)
                    .foregroundStyle(Color.auraTextSecondary)
                    .lineLimit(1)
                if let metadata {
                    Text(metadata)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.auraTextSecondary.opacity(0.78))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 2)

            Button {
                openMusicApp(title: song.title, artist: song.artist)
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: AuraMetrics.minimumTapTarget, height: AuraMetrics.minimumTapTarget)
                    .background(Color.auraDeepAccent)
                    .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isEnglish ? "Play \(song.title)" : "\(song.title) parçasını çal")

            Menu {
                if metadata == nil {
                    Button(role: .destructive, action: onRemove) {
                        Label(isEnglish ? "Remove from liked" : "Beğenilenlerden çıkar", systemImage: "heart.slash")
                    }
                } else {
                    Button {
                        favoritesManager.toggleFavorite(song)
                    } label: {
                        Label(
                            favoritesManager.isFavorite(song)
                                ? (isEnglish ? "Remove from liked" : "Beğenilenlerden çıkar")
                                : (isEnglish ? "Add to liked" : "Beğenilenlere ekle"),
                            systemImage: favoritesManager.isFavorite(song) ? "heart.slash" : "heart"
                        )
                    }

                    Button(role: .destructive, action: onRemove) {
                        Label(isEnglish ? "Remove from history" : "Geçmişten kaldır", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.auraTextSecondary)
                    .frame(width: AuraMetrics.minimumTapTarget, height: AuraMetrics.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(isEnglish ? "More options" : "Diğer seçenekler")
        }
        .padding(.vertical, 10)
    }

    private var albumTile: some View {
        ZStack {
            Color.auraDeepAccent
            LinearGradient(
                colors: [Color.auraPrimary.opacity(0.82), Color.auraSecondary.opacity(0.42), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "waveform")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    private func historyMetadata(_ entry: HistoryEntry) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageManager.currentLanguage)
        formatter.dateStyle = Calendar.current.isDateInToday(entry.timestamp) ? .none : .short
        formatter.timeStyle = .short
        return "\(sourceLabel(entry.source)) · \(formatter.string(from: entry.timestamp))"
    }

    private func sourceLabel(_ source: String) -> String {
        switch source {
        case "discover": return isEnglish ? "Discover" : "Keşfet"
        case "mix": return "Daily Mix"
        default: return isEnglish ? "Daily pick" : "Günün önerisi"
        }
    }

    private func removeHistoryEntry(_ entry: HistoryEntry) {
        guard let index = historyManager.history.firstIndex(where: { $0.id == entry.id }) else { return }
        historyManager.removeEntry(at: IndexSet(integer: index))
    }

    private func openMusicApp(title: String, artist: String) {
        let platform = firebaseManager.userProfile?.platform ?? "Spotify"

        Task {
            let resolved = await MusicPlaybackResolver.shared.resolvePlaybackURLs(
                title: title,
                artist: artist,
                platform: platform
            )

            if let appURL = resolved.appURL, UIApplication.shared.canOpenURL(appURL) {
                UIApplication.shared.open(appURL, options: [:], completionHandler: nil)
                return
            }

            if let webURL = resolved.webURL {
                UIApplication.shared.open(webURL, options: [:], completionHandler: nil)
            }
        }
    }
}