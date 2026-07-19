import SwiftUI
import UIKit

struct DiscoverView: View {
    @EnvironmentObject var firebaseManager: FirebaseManager
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @StateObject private var viewModel = DiscoverViewModel()
    @State private var selectedSongLanguageOverride: SongLanguagePreference?

    private var isEnglish: Bool { languageManager.currentLanguage == "en" }
    private var selectedSongLanguage: SongLanguagePreference {
        selectedSongLanguageOverride ?? firebaseManager.userProfile?.songLanguage ?? .random
    }

    private let moodColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            AuraFixedHeaderLayout {
                AuraPageHeader(
                    eyebrow: isEnglish ? "Mood to music" : "Ruh halinden müziğe",
                    title: isEnglish ? "Discover" : "Keşfet",
                    subtitle: isEnglish
                        ? "Choose how you feel. We'll find the track."
                        : "Nasıl hissettiğini seç, sana uygun parçayı bulalım.",
                    icon: "safari.fill",
                    accent: .auraTertiary
                )
            } content: {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AuraMetrics.sectionSpacing) {
                        languageSection
                        moodSection
                        fetchButton

                        if let suggestion = viewModel.suggestion {
                            resultCard(suggestion)
                        }

                        if let error = viewModel.errorMessage {
                            errorPanel(message: error)
                        }
                    }
                    .padding(.horizontal, AuraMetrics.pagePadding)
                    .padding(.top, 22)
                    .padding(.bottom, 36)
                    .auraContentColumn()
                }
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.light)
        .animation(.easeOut(duration: 0.22), value: viewModel.suggestion)
    }

    private var languageSection: some View {
        AuraSectionCard(
            title: isEnglish ? "Song language" : "Şarkı dili",
            subtitle: isEnglish ? "Only for this discovery" : "Yalnızca bu keşif için",
            icon: "music.mic",
            tint: .auraTertiary
        ) {
            HStack(spacing: 8) {
                ForEach(SongLanguagePreference.allCases) { option in
                    let isSelected = selectedSongLanguage == option
                    Button {
                        selectedSongLanguageOverride = option
                        clearResult()
                    } label: {
                        Text(option.title(isEnglish: isEnglish))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isSelected ? Color.white : Color.auraOnSurface)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(isSelected ? Color.auraTertiary : Color.auraSurface)
                            .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous)
                                    .stroke(isSelected ? Color.auraTertiary : Color.auraOutline, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isEnglish ? "HOW DO YOU FEEL?" : "NASIL HİSSEDİYORSUN?")
                    .font(.caption2.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(Color.auraPrimary)
                Text(isEnglish ? "Set the tone" : "Modunu seç")
                    .font(.auraTitle)
                    .foregroundStyle(Color.auraOnSurface)
            }

            LazyVGrid(columns: moodColumns, spacing: 10) {
                ForEach(Mood.all) { mood in
                    moodButton(mood)
                }
            }
        }
    }

    private func moodButton(_ mood: Mood) -> some View {
        let isSelected = viewModel.selectedMood == mood
        let label = isEnglish ? mood.nameEn : mood.nameTr

        return Button {
            withAnimation(.easeOut(duration: 0.18)) {
                viewModel.selectedMood = isSelected ? nil : mood
                clearResult()
            }
        } label: {
            HStack(spacing: 10) {
                Text(mood.emoji)
                    .font(.system(size: 19))
                    .frame(width: 36, height: 36)
                    .background(isSelected ? Color.white.opacity(0.18) : mood.color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))

                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.auraOnSurface)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(isSelected ? mood.color : Color.auraSurfaceVariant)
            .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous)
                    .stroke(isSelected ? mood.color : Color.auraOutline, lineWidth: 1)
            }
            .shadow(color: isSelected ? mood.color.opacity(0.16) : .clear, radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var fetchButton: some View {
        Button(action: fetchSuggestion) {
            HStack(spacing: 9) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(viewModel.isLoading
                    ? (isEnglish ? "Finding your track..." : "Şarkın bulunuyor...")
                    : (isEnglish ? "Find my song" : "Şarkımı bul"))
            }
        }
        .buttonStyle(M3FilledButton())
        .disabled(viewModel.selectedMood == nil || viewModel.isLoading)
    }

    private func resultCard(_ suggestion: SongSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                if let mood = viewModel.selectedMood {
                    Label(isEnglish ? mood.nameEn : mood.nameTr, systemImage: "circle.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(mood.color)
                }
                Text("•")
                    .foregroundStyle(Color.auraOutline)
                Text(selectedSongLanguage.title(isEnglish: isEnglish))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.auraTextSecondary)
                Spacer()
            }

            HStack(spacing: 16) {
                albumTile

                VStack(alignment: .leading, spacing: 5) {
                    Text(suggestion.title)
                        .font(.auraTitle)
                        .foregroundStyle(Color.auraOnSurface)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                    Text(suggestion.artist)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.auraTextSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            Text(suggestion.message)
                .font(.subheadline)
                .foregroundStyle(Color.auraTextSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    favoritesManager.toggleFavorite(suggestion)
                } label: {
                    Image(systemName: favoritesManager.isFavorite(suggestion) ? "heart.fill" : "heart")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(favoritesManager.isFavorite(suggestion) ? Color.auraDanger : Color.auraTextSecondary)
                        .frame(width: 52, height: 52)
                        .background(Color.auraSurface)
                        .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.controlRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AuraMetrics.controlRadius, style: .continuous)
                                .stroke(Color.auraOutline, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(favoritesManager.isFavorite(suggestion)
                    ? (isEnglish ? "Remove from favorites" : "Favorilerden çıkar")
                    : (isEnglish ? "Add to favorites" : "Favorilere ekle"))

                Button {
                    openMusicApp(title: suggestion.title, artist: suggestion.artist)
                } label: {
                    Label(isEnglish ? "Start listening" : "Dinlemeye başla", systemImage: "play.fill")
                }
                .buttonStyle(M3FilledButton())
            }
        }
        .auraCardSurface()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var albumTile: some View {
        ZStack {
            Color.auraDeepAccent
            LinearGradient(
                colors: [Color.auraTertiary.opacity(0.9), Color.auraPrimary.opacity(0.48), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "waveform")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 82, height: 82)
        .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    private func errorPanel(message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button(isEnglish ? "Retry" : "Tekrar", action: fetchSuggestion)
                .font(.footnote.weight(.bold))
        }
        .foregroundStyle(Color.auraDanger)
        .padding(14)
        .background(Color.auraDanger.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous)
                .stroke(Color.auraDanger.opacity(0.2), lineWidth: 1)
        }
    }

    private func clearResult() {
        viewModel.suggestion = nil
        viewModel.errorMessage = nil
    }

    private func fetchSuggestion() {
        let profile = firebaseManager.userProfile
        Task {
            await viewModel.fetchSuggestion(
                genres: profile?.genres ?? [],
                platform: profile?.platform ?? "Spotify",
                interfaceLanguage: languageManager.currentLanguage,
                songLanguagePreference: selectedSongLanguage
            )
        }
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