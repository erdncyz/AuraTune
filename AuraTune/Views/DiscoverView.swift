import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @StateObject private var viewModel = DiscoverViewModel()
    @State private var selectedSongLanguageOverride: SongLanguagePreference? = nil

    var isEnglish: Bool { languageManager.currentLanguage == "en" }
    var selectedSongLanguage: SongLanguagePreference {
        selectedSongLanguageOverride ?? supabaseManager.userProfile?.songLanguage ?? .random
    }

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.auraSurface.ignoresSafeArea()

                // Hero gradient
                LinearGradient(
                    colors: [Color(hex: "1E1B4B"), Color(hex: "4C3F8A"), Color.auraTertiary.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 260)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea(edges: .top)

                VStack(spacing: 0) {
                    heroHeader
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            songLanguageSection
                            moodPickerSection
                            fetchButton
                            if let suggestion = viewModel.suggestion {
                                resultCard(suggestion: suggestion)
                            }
                            if let error = viewModel.errorMessage {
                                errorCard(message: error)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .preferredColorScheme(.light)
        }
    }

    // MARK: - Hero
    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Decorative circles
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 180, height: 180)
                .offset(x: 220, y: -10)
            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 120, height: 120)
                .offset(x: 260, y: 60)

            VStack(alignment: .leading, spacing: 6) {
                Text(isEnglish ? "Discover" : "Keşfet")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                Text(isEnglish
                     ? "Pick a mood, get the perfect song"
                     : "Ruh halini seç, sana özel şarkıyı bul")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
            }
            .padding(.leading, 20)
            .padding(.bottom, 28)
        }
        .frame(height: 260)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Song Language
    private var songLanguageSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "5AC8FA").opacity(0.14))
                        .frame(width: 34, height: 34)
                    Image(systemName: "music.mic")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "5AC8FA"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(isEnglish ? "Song Language" : "Şarkı Dili")
                        .font(.headline)
                        .foregroundColor(.auraOnSurface)
                    Text(isEnglish
                         ? "Choose the language for this discovery"
                         : "Bu öneri için şarkı dilini seç")
                        .font(.caption)
                        .foregroundColor(.auraOnSurface.opacity(0.65))
                }
            }

            HStack(spacing: 10) {
                ForEach(SongLanguagePreference.allCases) { option in
                    let isSelected = selectedSongLanguage == option
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSongLanguageOverride = option
                            viewModel.suggestion = nil
                            viewModel.errorMessage = nil
                        }
                    }) {
                        Text(option.title(isEnglish: isEnglish))
                            .font(.caption.weight(.semibold))
                            .foregroundColor(isSelected ? .white : .auraOnSurface)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isSelected ? Color.auraTertiary : Color.auraSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(isSelected ? Color.auraTertiary : Color.auraOnSurface.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    // MARK: - Mood Picker
    private var moodPickerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isEnglish ? "How are you feeling?" : "Nasıl hissediyorsun?")
                .font(.headline)
                .foregroundColor(.auraOnSurface)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Mood.all) { mood in
                    moodChip(mood)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private func moodChip(_ mood: Mood) -> some View {
        let isSelected = viewModel.selectedMood == mood
        let label = isEnglish ? mood.nameEn : mood.nameTr

        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.selectedMood = isSelected ? nil : mood
                viewModel.suggestion = nil
                viewModel.errorMessage = nil
            }
        }) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isSelected ? mood.color : mood.color.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Text(mood.emoji)
                        .font(.system(size: 22))
                }
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(isSelected ? mood.color : .auraOnSurface.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .scaleEffect(isSelected ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Fetch Button
    private var fetchButton: some View {
        Button(action: {
            let profile = supabaseManager.userProfile
            Task {
                await viewModel.fetchSuggestion(
                    genres: profile?.genres ?? [],
                    interfaceLanguage: languageManager.currentLanguage,
                    songLanguagePreference: selectedSongLanguage
                )
            }
        }) {
            HStack(spacing: 8) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "wand.and.stars")
                }
                Text(isEnglish ? "Find My Song" : "Şarkımı Bul")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Group {
                    if viewModel.selectedMood != nil && !viewModel.isLoading {
                        LinearGradient(
                            colors: [Color(hex: "4C3F8A"), Color.auraTertiary],
                            startPoint: .leading, endPoint: .trailing
                        )
                    } else {
                        LinearGradient(
                            colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.4)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    }
                }
            )
            .cornerRadius(16)
            .shadow(
                color: viewModel.selectedMood != nil ? Color.auraTertiary.opacity(0.35) : .clear,
                radius: 10, x: 0, y: 4
            )
        }
        .disabled(viewModel.selectedMood == nil || viewModel.isLoading)
        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedMood)
    }

    // MARK: - Result Card
    private func resultCard(suggestion: SongSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Mood badge
            if let mood = viewModel.selectedMood {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Text(mood.emoji)
                        Text(isEnglish ? mood.nameEn : mood.nameTr)
                            .font(.caption.bold())
                            .foregroundColor(mood.color)
                    }

                    Text(selectedSongLanguage.title(isEnglish: isEnglish))
                        .font(.caption.bold())
                        .foregroundColor(.auraTertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    LinearGradient(
                        colors: [mood.color.opacity(0.12), Color.auraTertiary.opacity(0.12)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }

            // Message
            Text(suggestion.message)
                .font(.body)
                .foregroundColor(.auraOnSurface.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 14)

            Divider().padding(.horizontal, 16)

            // Song info
            HStack(spacing: 14) {
                ZStack {
                    LinearGradient(
                        colors: [Color(hex: "4C3F8A"), Color.auraTertiary],
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
            .padding(.top, 14)
            .padding(.bottom, 14)

            // Play Button
            HStack(spacing: 10) {
                Button(action: {
                    favoritesManager.toggleFavorite(suggestion)
                }) {
                    Image(systemName: favoritesManager.isFavorite(suggestion) ? "heart.fill" : "heart")
                        .foregroundColor(favoritesManager.isFavorite(suggestion) ? .red : .auraOnSurface.opacity(0.6))
                        .frame(width: 44, height: 44)
                        .background(Color.auraSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                            colors: [Color(hex: "4C3F8A"), Color.auraTertiary],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: Color.auraTertiary.opacity(0.3), radius: 8, x: 0, y: 4)
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
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
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
            Button(action: {
                let profile = supabaseManager.userProfile
                Task {
                    await viewModel.fetchSuggestion(
                        genres: profile?.genres ?? [],
                        interfaceLanguage: languageManager.currentLanguage,
                        songLanguagePreference: selectedSongLanguage
                    )
                }
            }) {
                Text(isEnglish ? "Retry" : "Tekrar")
                    .font(.caption.bold())
                    .foregroundColor(.auraTertiary)
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Open Music App
    private func openMusicApp(title: String, artist: String) {
        let platform = supabaseManager.userProfile?.platform ?? "Spotify"
        let query = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString: String
        switch platform {
        case "Spotify":       urlString = "spotify:search:\(query)"
        case "Apple Music":   urlString = "music://music.apple.com/search?term=\(query)"
        case "YouTube Music": urlString = "https://music.youtube.com/search?q=\(query)"
        default:              urlString = "spotify:search:\(query)"
        }
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}
