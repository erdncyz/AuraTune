import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var historyManager: HistoryManager
    @StateObject private var viewModel = HomeViewModel()
    @State private var isSettingsSheetPresented = false
    @State private var isLibrarySheetPresented = false
    @State private var isSystemSharePresented = false
    @State private var selectedShareSuggestion: SongSuggestion?
    @State private var shareItems: [Any] = []
    @State private var shareToast: ShareToast?
    @State private var posterSaveHandler = PosterSaveHandler()

    var isEnglish: Bool { languageManager.currentLanguage == "en" }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if isEnglish {
            switch hour {
            case 5..<12:  return "Good Morning \u{2600}\u{FE0F}"
            case 12..<17: return "Good Afternoon \u{26C5}"
            case 17..<21: return "Good Evening \u{2728}"
            default:      return "Good Night \u{1F319}"
            }
        } else {
            switch hour {
            case 5..<12:  return "G\u{00FC}nayd\u{0131}n \u{2600}\u{FE0F}"
            case 12..<17: return "\u{0130}yi \u{00D6}\u{011F}lenler \u{26C5}"
            case 17..<21: return "\u{0130}yi Ak\u{015F}amlar \u{2728}"
            default:      return "\u{0130}yi Geceler \u{1F319}"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.auraSurface.ignoresSafeArea()
                LinearGradient(
                    colors: [Color(hex: "994A1A"), Color.auraPrimary, Color(hex: "FFD966").opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                    .frame(height: 310)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)

                VStack(spacing: -8) {
                    heroHeader
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            if let suggestion = viewModel.dailySuggestion {
                                songCard(suggestion: suggestion)
                            } else {
                                emptyCard
                            }

                            dailyMixSection

                            if let error = viewModel.errorMessage {
                                errorCard(message: error)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 0)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.light)
        .onAppear {
            if viewModel.dailySuggestion == nil, !viewModel.isLoadingSuggestion {
                fetchSuggestion()
            } else {
                fetchDailyMixIfNeeded()
            }
        }
        .sheet(isPresented: $isLibrarySheetPresented) {
            FavoritesView()
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isSettingsSheetPresented) {
            SettingsView()
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedShareSuggestion) { suggestion in
            SongShareSheet(
                suggestion: suggestion,
                isEnglish: isEnglish,
                onWhatsApp: { shareToWhatsApp(suggestion) },
                onInstagram: { shareToInstagram(suggestion) },
                onSave: { savePoster(for: suggestion) }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $isSystemSharePresented) {
            ActivityView(activityItems: shareItems)
        }
        .overlay(alignment: .bottom) {
            if let shareToast {
                ShareToastView(toast: shareToast)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Hero Header
    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Decorative shapes
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 200, height: 200)
                .offset(x: 200, y: -20)
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 140, height: 140)
                .offset(x: 240, y: 40)
            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 80, height: 80)
                .offset(x: -20, y: -60)

            // Text content
            VStack(alignment: .leading, spacing: 6) {
                Text(greeting)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))

                let name = supabaseManager.userProfile?.name ?? ""
                Text(name.isEmpty ? "AuraTune" : name)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Quick Stats
                VStack(alignment: .leading, spacing: 8) {
                    // Row 1: Profile stats
                    HStack(spacing: 8) {
                        Button(action: { isSettingsSheetPresented = true }) {
                            statChip(
                                icon: "clock.fill",
                                color: Color(hex: "7C6AF7"),
                                label: isEnglish ? "Wake Up" : "Uyanma",
                                value: {
                                    let f = DateFormatter()
                                    f.timeStyle = .short
                                    return f.string(from: supabaseManager.userProfile?.wakeUpTime ?? Date())
                                }()
                            )
                        }
                        Button(action: { isSettingsSheetPresented = true }) {
                            statChip(
                                icon: "music.note.list",
                                color: Color(hex: "34C759"),
                                label: isEnglish ? "Genres" : "Tür",
                                value: "\(supabaseManager.userProfile?.genres.count ?? 0)"
                            )
                        }
                        Button(action: { isSettingsSheetPresented = true }) {
                            statChip(
                                icon: "headphones",
                                color: Color(hex: "F4845F"),
                                label: isEnglish ? "Platform" : "Platform",
                                value: {
                                    let p = supabaseManager.userProfile?.platform ?? "-"
                                    if p == "Apple Music" { return "Apple" }
                                    if p == "YouTube Music" { return "YouTube" }
                                    return p
                                }()
                            )
                        }
                    }
                    
                    // Row 2: Library stats (centered, tappable)
                    HStack(spacing: 8) {
                        Spacer()
                        Button(action: { isLibrarySheetPresented = true }) {
                            libraryChip(
                                icon: "heart.fill",
                                color: Color(hex: "FF2D55"),
                                label: isEnglish ? "Likes" : "Beğendiklerim",
                                value: "\(favoritesManager.favorites.count)"
                            )
                        }
                        Button(action: { isLibrarySheetPresented = true }) {
                            libraryChip(
                                icon: "clock.arrow.circlepath",
                                color: Color(hex: "5AC8FA"),
                                label: isEnglish ? "History" : "Geçmiş Öneriler",
                                value: "\(historyManager.history.count)"
                            )
                        }
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(height: 310)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Song Card
    private func songCard(suggestion: SongSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            // Card header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.auraPrimary.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.auraPrimary)
                }
                Text(isEnglish ? "Today's Pick" : "Günün Önerisi")
                    .font(.headline)
                    .foregroundColor(.auraOnSurface)
                Spacer()
                // Refresh button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        fetchSuggestion()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.auraOnSurface.opacity(0.4))
                        .rotationEffect(.degrees(viewModel.isLoadingSuggestion ? 360 : 0))
                        .animation(viewModel.isLoadingSuggestion ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoadingSuggestion)
                }

                Button(action: {
                    favoritesManager.toggleFavorite(suggestion)
                }) {
                    Image(systemName: favoritesManager.isFavorite(suggestion) ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(favoritesManager.isFavorite(suggestion) ? .red : .auraOnSurface.opacity(0.4))
                }

                Button(action: {
                    presentShareSheet(for: suggestion)
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.auraOnSurface.opacity(0.4))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().padding(.horizontal, 16)

            // Message
            Text(suggestion.message)
                .font(.body)
                .foregroundColor(.auraOnSurface.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

            // Song info block
            HStack(spacing: 14) {
                ZStack {
                    LinearGradient(
                        colors: [Color.auraPrimary, Color(hex: "F4845F")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    Image(systemName: "music.note")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.title3.bold())
                        .foregroundColor(.auraOnSurface)
                        .lineLimit(1)
                    Text(suggestion.artist)
                        .font(.subheadline)
                        .foregroundColor(.auraOnSurface.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            // Action Buttons
            HStack(spacing: 10) {
                Button(action: {
                    presentShareSheet(for: suggestion)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text(isEnglish ? "Share" : "Paylaş")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.auraPrimary)
                    .frame(width: 120)
                    .padding(.vertical, 14)
                    .background(Color.auraPrimary.opacity(0.11))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.auraPrimary.opacity(0.15), lineWidth: 1)
                    )
                }

                Button(action: {
                    openMusicApp(title: suggestion.title, artist: suggestion.artist)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text(isEnglish ? "Start Listening" : "Dinlemeye Başla")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.auraPrimary, Color(hex: "F4845F")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: Color.auraPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.auraOnSurface.opacity(0.07), lineWidth: 1)
        )
    }

    private var mixLoadingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.auraPrimary)
            mixHeader
            Text(isEnglish ? "Building your Daily Mix..." : "Daily Mix hazırlanıyor...")
                .font(.subheadline)
                .foregroundColor(.auraOnSurface.opacity(0.6))
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var dailyMixSection: some View {
        Group {
            if viewModel.isLoadingMix {
                mixLoadingCard
            } else if !viewModel.dailyMix.isEmpty {
                dailyMixCard(songs: viewModel.dailyMix)
            } else if let mixError = viewModel.mixErrorMessage {
                dailyMixPlaceholderCard(
                    message: mixError,
                    actionTitle: isEnglish ? "Try Again" : "Tekrar Dene",
                    action: { fetchDailyMixIfNeeded(force: true) }
                )
            } else if viewModel.dailySuggestion != nil {
                dailyMixPlaceholderCard(
                    message: isEnglish ? "Your Daily Mix is being prepared." : "Daily Mix'in hazırlanıyor.",
                    actionTitle: isEnglish ? "Refresh Mix" : "Mix'i Yenile",
                    action: { fetchDailyMixIfNeeded(force: true) }
                )
            } else {
                dailyMixPlaceholderCard(
                    message: isEnglish ? "Get today's song first, then your Daily Mix will appear here." : "Önce günün önerisini al, ardından Daily Mix burada görünecek.",
                    actionTitle: isEnglish ? "Get Today's Song" : "Günün Önerisini Al",
                    action: fetchSuggestion
                )
            }
        }
    }

    private var mixHeader: some View {
        HStack {
            Text(isEnglish ? "Daily Mix" : "Daily Mix")
                .font(.headline)
                .foregroundColor(.auraOnSurface)
            Spacer()
        }
    }

    private func dailyMixCard(songs: [SongSuggestion]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            mixHeader
                .overlay(alignment: .trailing) {
                Button(action: {
                    guard let profile = supabaseManager.userProfile,
                          let suggestion = viewModel.dailySuggestion else { return }
                    Task { await viewModel.fetchDailyMix(profile: profile, excluding: suggestion) }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text(isEnglish ? "Refresh" : "Yenile")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.auraPrimary)
                }
            }

            ForEach(Array(songs.enumerated()), id: \.offset) { index, song in
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .foregroundColor(.auraOnSurface.opacity(0.6))
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.auraOnSurface)
                            .lineLimit(1)
                        Text(song.artist)
                            .font(.caption)
                            .foregroundColor(.auraOnSurface.opacity(0.6))
                            .lineLimit(1)
                    }

                    Spacer()

                    Button(action: {
                        favoritesManager.toggleFavorite(song)
                    }) {
                        Image(systemName: favoritesManager.isFavorite(song) ? "heart.fill" : "heart")
                            .foregroundColor(favoritesManager.isFavorite(song) ? .red : .auraOnSurface.opacity(0.5))
                    }

                    Button(action: {
                        openMusicApp(title: song.title, artist: song.artist)
                    }) {
                        Image(systemName: "play.fill")
                            .foregroundColor(.auraPrimary)
                    }
                }
                .padding(.vertical, 6)

                if index < songs.count - 1 {
                    Divider()
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private func dailyMixPlaceholderCard(
        message: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            mixHeader

            Text(message)
                .font(.subheadline)
                .foregroundColor(.auraOnSurface.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)

            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                    Text(actionTitle)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.auraPrimary)
                .cornerRadius(14)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    // MARK: - Empty / Loading Card
    private var emptyCard: some View {
        VStack(spacing: 20) {
            if viewModel.isLoadingSuggestion {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.4)
                        .tint(.auraPrimary)
                    Text(isEnglish ? "Finding your perfect song..." : "Sana özel şarkı seçiliyor...")
                        .font(.subheadline)
                        .foregroundColor(.auraOnSurface.opacity(0.6))
                }
                .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.auraPrimary.opacity(0.1))
                            .frame(width: 72, height: 72)
                        Image(systemName: "sparkles")
                            .font(.system(size: 30))
                            .foregroundColor(.auraPrimary)
                    }
                    Text(isEnglish ? "No Song Yet" : "Henüz Şarkı Yok")
                        .font(.title3.bold())
                        .foregroundColor(.auraOnSurface)
                    Text(isEnglish
                         ? "Tap below to get your daily AI-powered music recommendation."
                         : "Günlük AI müzik önerini almak için aşağıya dokun.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.auraOnSurface.opacity(0.55))
                        .padding(.horizontal, 16)

                    Button(action: { fetchSuggestion() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars")
                            Text(isEnglish ? "Discover Now" : "Şimdi Keşfet")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color.auraPrimary, Color(hex: "F4845F")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color.auraPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    // MARK: - Error Card
    private func errorCard(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(.auraOnSurface.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button(action: { fetchSuggestion() }) {
                Text(isEnglish ? "Retry" : "Tekrar")
                    .font(.caption.bold())
                    .foregroundColor(.auraPrimary)
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Quick Stats Row (deprecated - moved to hero header)
    private var statsRow: some View {
        EmptyView()
    }

    private func libraryChip(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.85))
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.25))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        )
    }

    // MARK: - Unused function marker

    private func statChip(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.75))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.18))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
        )
    }

    // MARK: - Helpers
    private func fetchSuggestion() {
        guard let profile = supabaseManager.userProfile else { return }
        Task { await viewModel.fetchDailySuggestion(profile: profile) }
    }

    private func fetchDailyMixIfNeeded(force: Bool = false) {
        guard let profile = supabaseManager.userProfile,
              let suggestion = viewModel.dailySuggestion,
              !viewModel.isLoadingMix else { return }

        guard force || viewModel.dailyMix.isEmpty else { return }

        Task { await viewModel.fetchDailyMix(profile: profile, excluding: suggestion) }
    }

    private func presentShareSheet(for suggestion: SongSuggestion) {
        selectedShareSuggestion = suggestion
    }

    private func presentSystemShare(for suggestion: SongSuggestion) {
        let payload = shareCaption(for: suggestion)
        selectedShareSuggestion = nil
        shareItems = shareItems(for: suggestion, includeCaption: true, includeLink: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isSystemSharePresented = true
        }
    }

    private func shareToWhatsApp(_ suggestion: SongSuggestion) {
        selectedShareSuggestion = nil
        shareItems = shareItems(for: suggestion, includeCaption: true, includeLink: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isSystemSharePresented = true
        }
        showShareToast(
            message: isEnglish ? "Poster ready, choose WhatsApp" : "Poster hazır, WhatsApp'ı seçebilirsin",
            systemImage: "message.fill"
        )
    }

    private func shareToInstagram(_ suggestion: SongSuggestion) {
        selectedShareSuggestion = nil

        guard let image = renderedShareImage(for: suggestion),
              let imageData = image.pngData(),
              let url = URL(string: "instagram-stories://share") else {
            presentSystemShare(for: suggestion)
            return
        }

        UIPasteboard.general.string = shareCaption(for: suggestion)

        let pasteboardItems: [[String: Any]] = [[
            "com.instagram.sharedSticker.backgroundImage": imageData,
            "com.instagram.sharedSticker.backgroundTopColor": "#F4845F",
            "com.instagram.sharedSticker.backgroundBottomColor": "#7C6AF7"
        ]]
        UIPasteboard.general.setItems(pasteboardItems, options: [.expirationDate: Date().addingTimeInterval(300)])

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            showShareToast(
                message: isEnglish ? "Poster sent to Instagram Stories" : "Poster Instagram Stories için hazırlandı",
                systemImage: "camera.fill"
            )
        } else {
            presentSystemShare(for: suggestion)
        }
    }

    private func savePoster(for suggestion: SongSuggestion) {
        guard let image = renderedShareImage(for: suggestion) else {
            showShareToast(
                message: isEnglish ? "Poster could not be created" : "Poster oluşturulamadı",
                systemImage: "exclamationmark.triangle.fill"
            )
            return
        }

        selectedShareSuggestion = nil
        posterSaveHandler.onSuccess = {
            showShareToast(
                message: isEnglish ? "Poster saved to Photos" : "Poster Fotoğraflar'a kaydedildi",
                systemImage: "square.and.arrow.down.fill"
            )
        }
        posterSaveHandler.onFailure = {
            presentSystemShare(for: suggestion)
            showShareToast(
                message: isEnglish ? "Could not save, opening share options" : "Kaydetme başarısız, paylaşım seçenekleri açılıyor",
                systemImage: "exclamationmark.triangle.fill"
            )
        }
        UIImageWriteToSavedPhotosAlbum(image, posterSaveHandler, #selector(PosterSaveHandler.image(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    private func shareCaption(for suggestion: SongSuggestion) -> String {
        let intro = isEnglish
            ? "My AuraTune pick today: \(suggestion.title) — \(suggestion.artist)"
            : "Bugünkü AuraTune önerim: \(suggestion.title) — \(suggestion.artist)"
        let note = isEnglish ? "Listen here" : "Buradan dinle"

        if let url = musicWebURL(title: suggestion.title, artist: suggestion.artist) {
            return "\(intro)\n\n\(suggestion.message)\n\n\(note): \(url.absoluteString)"
        }

        return "\(intro)\n\n\(suggestion.message)"
    }

    private func shareItems(for suggestion: SongSuggestion, includeCaption: Bool, includeLink: Bool) -> [Any] {
        var items: [Any] = []

        if let image = renderedShareImage(for: suggestion) {
            items.append(image)
        }

        if includeCaption {
            let caption: String
            if includeLink {
                caption = shareCaption(for: suggestion)
            } else {
                caption = [
                    isEnglish ? "My AuraTune pick today:" : "Bugünkü AuraTune önerim:",
                    "\(suggestion.title) — \(suggestion.artist)",
                    suggestion.message
                ].joined(separator: "\n")
            }
            items.append(caption)
        }

        return items
    }

    private func renderedShareImage(for suggestion: SongSuggestion) -> UIImage? {
        let poster = SharePosterView(
            suggestion: suggestion,
            isEnglish: isEnglish,
            platformName: displayPlatformName,
            footerText: isEnglish ? "Curated by AuraTune" : "AuraTune ile seçildi"
        )

        let renderer = ImageRenderer(content: poster)
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1920)
        return renderer.uiImage
    }

    private var displayPlatformName: String {
        let platform = supabaseManager.userProfile?.platform ?? "Spotify"
        if platform == "Apple Music" {
            return "Apple Music"
        }
        if platform == "YouTube Music" {
            return "YouTube Music"
        }
        return "Spotify"
    }

    private func musicWebURL(title: String, artist: String) -> URL? {
        let query = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let platform = supabaseManager.userProfile?.platform ?? "Spotify"

        let urlString: String
        if platform == "YouTube Music" {
            urlString = "https://music.youtube.com/search?q=\(query)"
        } else if platform == "Apple Music" {
            urlString = "https://music.apple.com/search?term=\(query)"
        } else {
            urlString = "https://open.spotify.com/search/\(query)"
        }

        return URL(string: urlString)
    }

    private func showShareToast(message: String, systemImage: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            shareToast = ShareToast(message: message, systemImage: systemImage)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                shareToast = nil
            }
        }
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

private struct SongShareSheet: View {
    let suggestion: SongSuggestion
    let isEnglish: Bool
    let onWhatsApp: () -> Void
    let onInstagram: () -> Void
    let onSave: () -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Capsule()
                    .fill(Color.auraOnSurface.opacity(0.12))
                    .frame(width: 42, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text(isEnglish ? "Share Today's Pick" : "Günün Önerisini Paylaş")
                        .font(.title3.bold())
                        .foregroundColor(.auraOnSurface)
                    Text("\(suggestion.title) • \(suggestion.artist)")
                        .font(.subheadline)
                        .foregroundColor(.auraOnSurface.opacity(0.6))
                        .lineLimit(2)
                }

                SharePosterPreviewCard(suggestion: suggestion, isEnglish: isEnglish)

                LazyVGrid(columns: columns, spacing: 12) {
                    ShareActionCard(
                        title: "WhatsApp",
                        subtitle: isEnglish ? "Poster + caption" : "Poster + açıklama",
                        icon: "message.fill",
                        colors: [Color(hex: "25D366"), Color(hex: "128C7E")],
                        action: onWhatsApp
                    )
                    ShareActionCard(
                        title: "Instagram",
                        subtitle: isEnglish ? "Share to Stories" : "Story olarak paylaş",
                        icon: "camera.fill",
                        colors: [Color(hex: "F58529"), Color(hex: "DD2A7B")],
                        action: onInstagram
                    )
                    ShareActionCard(
                        title: isEnglish ? "Save Poster" : "Posteri Kaydet",
                        subtitle: isEnglish ? "Save to Photos" : "Fotoğraflar'a kaydet",
                        icon: "arrow.down.circle.fill",
                        colors: [Color(hex: "5AC8FA"), Color(hex: "007AFF")],
                        action: onSave
                    )
                }

                Text(isEnglish
                     ? "AuraTune creates a vertical share poster so your song recommendation stands out in stories and chats."
                     : "AuraTune, önerini story ve mesajlarda dikkat çekmesi için dikey bir poster olarak hazırlar.")
                    .font(.footnote)
                    .foregroundColor(.auraOnSurface.opacity(0.55))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.white)
    }
}

private struct SharePosterPreviewCard: View {
    let suggestion: SongSuggestion
    let isEnglish: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(hex: "2B1A43"), Color(hex: "A14BFF"), Color(hex: "FF8A5B")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 180, height: 180)
                .offset(x: 110, y: -50)

            VStack(alignment: .leading, spacing: 8) {
                Text(isEnglish ? "Share Poster" : "Paylaşım Posteri")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.75))
                Text(suggestion.title)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .lineLimit(2)
                Text(suggestion.artist)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.78))
                    .lineLimit(1)
            }
            .padding(18)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}

@MainActor
private final class PosterSaveHandler: NSObject {
    var onSuccess: (() -> Void)?
    var onFailure: (() -> Void)?

    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeMutableRawPointer?) {
        if error == nil {
            onSuccess?()
        } else {
            onFailure?()
        }
    }
}

private struct ShareActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let colors: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(width: 42, height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.auraOnSurface)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.auraOnSurface.opacity(0.6))
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
            .padding(14)
            .background(Color(hex: "FFF7F2"))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.auraOnSurface.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ShareToast: Equatable {
    let message: String
    let systemImage: String
}

private struct ShareToastView: View {
    let toast: ShareToast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)

            Text(toast.message)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color(hex: "2F2A42"), Color(hex: "4B3E65")],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
    }
}

private struct SharePosterView: View {
    let suggestion: SongSuggestion
    let isEnglish: Bool
    let platformName: String
    let footerText: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1C1035"), Color(hex: "6A2CF6"), Color(hex: "FF8A5B")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 520, height: 520)
                .offset(x: 260, y: -500)

            Circle()
                .fill(Color(hex: "FFD966").opacity(0.18))
                .frame(width: 360, height: 360)
                .offset(x: -240, y: 520)

            VStack(alignment: .leading, spacing: 32) {
                HStack {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(isEnglish ? "Today on repeat" : "Bugünün seçimi")
                            .font(.system(size: 40, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.82))
                        Text("AuraTune")
                            .font(.system(size: 72, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 28) {
                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 136, height: 136)
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.system(size: 58, weight: .bold))
                                    .foregroundColor(.white)
                            }

                        VStack(alignment: .leading, spacing: 10) {
                            Text(suggestion.title)
                                .font(.system(size: 66, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(3)
                                .minimumScaleFactor(0.75)
                            Text(suggestion.artist)
                                .font(.system(size: 36, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(2)
                        }
                    }

                    Text(suggestion.message)
                        .font(.system(size: 42, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.92))
                        .lineSpacing(8)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 12) {
                        posterChip(title: platformName, icon: "headphones")
                        posterChip(title: isEnglish ? "AI Curated" : "AI Seçimi", icon: "sparkles")
                    }
                }
                .padding(40)
                .background(Color.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))

                Spacer(minLength: 0)

                HStack {
                    Text(footerText)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.82))
                    Spacer()
                    Text(isEnglish ? "auratune.app" : "auratune.app")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 68)
            .padding(.vertical, 92)
        }
        .frame(width: 1080, height: 1920)
    }

    private func posterChip(title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.12))
        .clipShape(Capsule())
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}
