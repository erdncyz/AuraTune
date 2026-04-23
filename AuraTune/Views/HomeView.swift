import SwiftUI

struct HomeView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var viewModel = HomeViewModel()

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
                Color.auraSurface
                // Hero gradient start color extends behind status bar and pull-down area
                Color(hex: "994A1A")
                    .frame(height: 250)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // ── Hero Header ──────────────────────────────────
                        heroHeader

                        // ── Body Cards ───────────────────────────────────
                        VStack(spacing: 16) {
                            if let suggestion = viewModel.dailySuggestion {
                                songCard(suggestion: suggestion)
                            } else {
                                emptyCard
                            }

                            if let error = viewModel.errorMessage {
                                errorCard(message: error)
                            }

                            // Quick Stats Row
                            statsRow
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarHidden(true)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar(.visible, for: .tabBar)
            .toolbarBackground(Color.auraSurface, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .preferredColorScheme(.dark)
        }
        .preferredColorScheme(.light)
        .onAppear {
            if viewModel.dailySuggestion == nil && !viewModel.isLoadingSuggestion {
                fetchSuggestion()
            }
        }
    }

    // MARK: - Hero Header
    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient
            LinearGradient(
                colors: [Color(hex: "994A1A"), Color.auraPrimary, Color(hex: "FFD966").opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)
            .frame(height: 250)

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

                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.caption)
                    let platform = supabaseManager.userProfile?.platform ?? ""
                    Text(platform.isEmpty
                         ? (isEnglish ? "Set up your profile" : "Profilini tamamla")
                         : platform)
                        .font(.caption.weight(.medium))
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
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

            // Play Button
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

    // MARK: - Quick Stats Row
    private var statsRow: some View {
        HStack(spacing: 12) {
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
            statChip(
                icon: "music.note.list",
                color: Color(hex: "34C759"),
                label: isEnglish ? "Genres" : "Türler",
                value: "\(supabaseManager.userProfile?.genres.count ?? 0)"
            )
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

    private func statChip(icon: String, color: Color, label: String, value: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(.auraOnSurface)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundColor(.auraOnSurface.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
    }

    // MARK: - Helpers
    private func fetchSuggestion() {
        guard let profile = supabaseManager.userProfile else { return }
        Task { await viewModel.fetchDailySuggestion(profile: profile) }
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
