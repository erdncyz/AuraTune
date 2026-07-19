import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject var firebaseManager: FirebaseManager
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var historyManager: HistoryManager
    @StateObject private var viewModel = HomeViewModel()

    private var isEnglish: Bool { languageManager.currentLanguage == "en" }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if isEnglish {
            switch hour {
            case 5..<12: return "Good morning"
            case 12..<17: return "Good afternoon"
            case 17..<21: return "Good evening"
            default: return "Good night"
            }
        }

        switch hour {
        case 5..<12: return "Günaydın"
        case 12..<17: return "İyi öğlenler"
        case 17..<21: return "İyi akşamlar"
        default: return "İyi geceler"
        }
    }

    private var displayName: String {
        let name = firebaseManager.userProfile?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "AuraTune" : name
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageManager.currentLanguage)
        formatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM")
        return formatter.string(from: Date())
    }

    var body: some View {
        NavigationStack {
            AuraFixedHeaderLayout {
                AuraPageHeader(
                    eyebrow: formattedDate,
                    title: displayName,
                    subtitle: greeting,
                    icon: "waveform",
                    accent: .auraSecondary
                )
            } content: {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: AuraMetrics.sectionSpacing) {
                        profileSnapshot

                        Group {
                            if let suggestion = viewModel.dailySuggestion {
                                featuredSong(suggestion)
                            } else {
                                suggestionPlaceholder
                            }
                        }

                        dailyMixSection

                        if let error = viewModel.errorMessage {
                            errorPanel(message: error, retry: fetchSuggestion)
                        }
                    }
                    .padding(.horizontal, AuraMetrics.pagePadding)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                    .auraContentColumn()
                }
                .refreshable {
                    guard let profile = firebaseManager.userProfile else { return }
                    await viewModel.fetchDailySuggestion(profile: profile, refreshMix: false)
                }
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.light)
        .onAppear {
            if let profile = firebaseManager.userProfile {
                NotificationManager.shared.ensureDailyMusicNotification(
                    for: profile,
                    suggestion: viewModel.dailySuggestion
                )
            }

            if viewModel.dailySuggestion == nil, !viewModel.isLoadingSuggestion {
                fetchSuggestion()
            } else {
                fetchDailyMixIfNeeded()
            }
        }
    }

    private var profileSnapshot: some View {
        HStack(spacing: 0) {
            snapshotItem(
                icon: "alarm.fill",
                value: timeString(firebaseManager.userProfile?.wakeUpTime ?? Date()),
                label: isEnglish ? "Wake up" : "Uyanma",
                tint: .auraPrimary
            )

            snapshotDivider

            snapshotItem(
                icon: "music.note.list",
                value: "\(firebaseManager.userProfile?.genres.count ?? 0)",
                label: isEnglish ? "Genres" : "Tür",
                tint: .auraSuccess
            )

            snapshotDivider

            snapshotItem(
                icon: "headphones",
                value: platformShortName,
                label: isEnglish ? "Service" : "Platform",
                tint: .auraTertiary
            )
        }
        .padding(.vertical, 14)
        .background(Color.auraSurfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous)
                .stroke(Color.auraOutline.opacity(0.8), lineWidth: 1)
        }
    }

    private var snapshotDivider: some View {
        Rectangle()
            .fill(Color.auraOutline)
            .frame(width: 1, height: 38)
    }

    private func snapshotItem(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.auraOnSurface)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.auraTextSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func featuredSong(_ suggestion: SongSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(isEnglish ? "TODAY'S PICK" : "GÜNÜN ÖNERİSİ")
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(Color.auraPrimary)
                    Text(isEnglish ? "Selected for your day" : "Günün için seçildi")
                        .font(.caption)
                        .foregroundStyle(Color.auraTextSecondary)
                }

                Spacer()

                iconButton(
                    icon: "arrow.clockwise",
                    label: isEnglish ? "Refresh suggestion" : "Öneriyi yenile",
                    tint: .auraTextSecondary,
                    isRotating: viewModel.isLoadingSuggestion,
                    action: fetchSuggestion
                )

                iconButton(
                    icon: favoritesManager.isFavorite(suggestion) ? "heart.fill" : "heart",
                    label: favoritesManager.isFavorite(suggestion)
                        ? (isEnglish ? "Remove from favorites" : "Favorilerden çıkar")
                        : (isEnglish ? "Add to favorites" : "Favorilere ekle"),
                    tint: favoritesManager.isFavorite(suggestion) ? .auraDanger : .auraTextSecondary,
                    action: { favoritesManager.toggleFavorite(suggestion) }
                )
            }

            HStack(spacing: 16) {
                albumTile(tint: .auraPrimary, size: 82)

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

            Button {
                openMusicApp(title: suggestion.title, artist: suggestion.artist)
            } label: {
                Label(isEnglish ? "Start listening" : "Dinlemeye başla", systemImage: "play.fill")
            }
            .buttonStyle(M3FilledButton())
        }
        .auraCardSurface()
    }

    private func iconButton(
        icon: String,
        label: String,
        tint: Color,
        isRotating: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: AuraMetrics.minimumTapTarget, height: AuraMetrics.minimumTapTarget)
                .background(Color.auraSurface)
                .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .animation(isRotating ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRotating)
        }
        .buttonStyle(.plain)
        .disabled(isRotating)
        .accessibilityLabel(label)
    }

    private func albumTile(tint: Color, size: CGFloat) -> some View {
        ZStack {
            Color.auraDeepAccent
            LinearGradient(
                colors: [tint.opacity(0.85), Color.auraSecondary.opacity(0.5), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "waveform")
                .font(.system(size: size * 0.3, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    private var suggestionPlaceholder: some View {
        VStack(spacing: 18) {
            if viewModel.isLoadingSuggestion {
                ProgressView()
                    .controlSize(.large)
                    .tint(.auraPrimary)
                Text(isEnglish ? "Finding today's track" : "Günün şarkısı seçiliyor")
                    .font(.auraSectionTitle)
                    .foregroundStyle(Color.auraOnSurface)
                Text(isEnglish ? "This can take a moment." : "Bu işlem kısa bir süre alabilir.")
                    .font(.subheadline)
                    .foregroundStyle(Color.auraTextSecondary)
            } else {
                AuraEmptyState(
                    icon: "sparkles",
                    title: isEnglish ? "Your daily pick awaits" : "Günlük önerin hazır değil",
                    message: isEnglish
                        ? "Generate a song shaped by your profile."
                        : "Profiline göre seçilen şarkını oluştur.",
                    tint: .auraPrimary
                )
                .padding(.vertical, -20)

                Button(action: fetchSuggestion) {
                    Label(isEnglish ? "Find my song" : "Şarkımı bul", systemImage: "sparkles")
                }
                .buttonStyle(M3FilledButton())
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .auraCardSurface()
    }

    @ViewBuilder
    private var dailyMixSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("DAILY MIX")
                        .font(.caption2.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(Color.auraTertiary)
                    Text(isEnglish ? "More for your queue" : "Sıran için daha fazlası")
                        .font(.auraTitle)
                        .foregroundStyle(Color.auraOnSurface)
                }
                Spacer()

                if !viewModel.dailyMix.isEmpty {
                    Button {
                        refreshMix()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.auraTertiary)
                            .frame(width: AuraMetrics.minimumTapTarget, height: AuraMetrics.minimumTapTarget)
                    }
                    .accessibilityLabel(isEnglish ? "Refresh mix" : "Mix'i yenile")
                }
            }

            if viewModel.isLoadingMix {
                mixLoadingView
            } else if !viewModel.dailyMix.isEmpty {
                mixList(viewModel.dailyMix)
            } else if let error = viewModel.mixErrorMessage {
                mixPlaceholder(message: error, buttonTitle: isEnglish ? "Try again" : "Tekrar dene", action: refreshMix)
            } else if viewModel.dailySuggestion != nil {
                mixPlaceholder(
                    message: isEnglish ? "Your mix is ready to be built." : "Mix'in oluşturulmaya hazır.",
                    buttonTitle: isEnglish ? "Build mix" : "Mix oluştur",
                    action: fetchDailyMixIfNeeded
                )
            } else {
                mixPlaceholder(
                    message: isEnglish ? "Your mix will appear after today's pick." : "Mix'in günün önerisinden sonra burada görünecek.",
                    buttonTitle: isEnglish ? "Find today's track" : "Günün şarkısını bul",
                    action: fetchSuggestion
                )
            }
        }
    }

    private var mixLoadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.auraTertiary)
            Text(isEnglish ? "Building your mix..." : "Mix'in hazırlanıyor...")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.auraTextSecondary)
            Spacer()
        }
        .auraCardSurface()
    }

    private func mixList(_ songs: [SongSuggestion]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(songs.enumerated()), id: \.offset) { index, song in
                HStack(spacing: 11) {
                    Text(String(format: "%02d", index + 1))
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .foregroundStyle(Color.auraTextSecondary)
                        .frame(width: 22)

                    albumTile(tint: index.isMultiple(of: 2) ? .auraTertiary : .auraPrimary, size: 42)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(song.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.auraOnSurface)
                            .lineLimit(1)
                        Text(song.artist)
                            .font(.caption)
                            .foregroundStyle(Color.auraTextSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 2)

                    Button {
                        favoritesManager.toggleFavorite(song)
                    } label: {
                        Image(systemName: favoritesManager.isFavorite(song) ? "heart.fill" : "heart")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(favoritesManager.isFavorite(song) ? Color.auraDanger : Color.auraTextSecondary)
                            .frame(width: AuraMetrics.minimumTapTarget, height: AuraMetrics.minimumTapTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isEnglish ? "Toggle favorite" : "Favoriyi değiştir")

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
                }
                .padding(.vertical, 10)

                if index < songs.count - 1 {
                    Divider()
                }
            }
        }
        .auraCardSurface()
    }

    private func mixPlaceholder(message: String, buttonTitle: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.auraTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: action) {
                Label(buttonTitle, systemImage: "music.note.list")
            }
            .buttonStyle(M3TonalButton())
        }
        .auraCardSurface()
    }

    private func errorPanel(message: String, retry: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button(isEnglish ? "Retry" : "Tekrar", action: retry)
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

    private var platformShortName: String {
        switch firebaseManager.userProfile?.platform {
        case "Apple Music": return "Apple"
        case "YouTube Music": return "YouTube"
        case let platform?: return platform
        case nil: return "-"
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageManager.currentLanguage)
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func fetchSuggestion() {
        guard let profile = firebaseManager.userProfile else { return }
        Task { await viewModel.fetchDailySuggestion(profile: profile, refreshMix: false) }
    }

    private func fetchDailyMixIfNeeded() {
        guard let profile = firebaseManager.userProfile,
              let suggestion = viewModel.dailySuggestion,
              !viewModel.isLoadingMix,
              viewModel.dailyMix.isEmpty else { return }

        Task { await viewModel.fetchDailyMix(profile: profile, excluding: suggestion) }
    }

    private func refreshMix() {
        guard let profile = firebaseManager.userProfile,
              let suggestion = viewModel.dailySuggestion,
              !viewModel.isLoadingMix else { return }

        Task { await viewModel.fetchDailyMix(profile: profile, excluding: suggestion) }
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