import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var historyManager: HistoryManager
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var showSavedBadge = false
    @State private var showAbout = false
    @State private var isLibrarySheetPresented = false

    var isEnglish: Bool { languageManager.currentLanguage == "en" }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.auraSurface.ignoresSafeArea()
                LinearGradient(
                    colors: [Color(hex: "994A1A"), Color.auraPrimary, Color(hex: "F4845F").opacity(0.8)],
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
                            // Language
                            sectionCard(icon: "globe", iconColor: Color(hex: "7C6AF7"),
                                        title: isEnglish ? "Language" : "Dil") {
                                HStack {
                                    Text(isEnglish ? "App Language" : "Uygulama Dili")
                                        .font(.subheadline)
                                        .foregroundColor(.auraOnSurface.opacity(0.7))
                                    Spacer()
                                    Picker("", selection: $languageManager.currentLanguage) {
                                        Text("TR").tag("tr")
                                        Text("EN").tag("en")
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 110)
                                }
                            }
                            .padding(.top, 8)

                            sectionCard(icon: "music.mic", iconColor: Color(hex: "5AC8FA"),
                                        title: isEnglish ? "Song Language" : "Şarkı Dili") {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(isEnglish
                                         ? "Choose the language of recommended songs"
                                         : "Önerilen şarkıların dilini seç")
                                        .font(.subheadline)
                                        .foregroundColor(.auraOnSurface.opacity(0.7))

                                    HStack(spacing: 10) {
                                        ForEach(SongLanguagePreference.allCases) { option in
                                            let isSelected = viewModel.selectedSongLanguage == option
                                            Button(action: { viewModel.selectedSongLanguage = option }) {
                                                Text(option.title(isEnglish: isEnglish))
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundColor(isSelected ? .white : .auraOnSurface)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 12)
                                                    .background(isSelected ? Color.auraPrimary : Color.auraSurface)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                            .stroke(isSelected ? Color.auraPrimary : Color.auraOnSurface.opacity(0.1), lineWidth: 1)
                                                    )
                                            }
                                        }
                                    }
                                }
                            }

                            // Name
                            sectionCard(icon: "person.fill", iconColor: Color(hex: "F4845F"),
                                        title: isEnglish ? "Your Name" : "Adın") {
                                TextField(isEnglish ? "e.g. Alex" : "Örn: Aysu",
                                          text: $viewModel.userName)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(Color.auraSurface)
                                    .cornerRadius(12)
                                    .font(.body)
                                    .foregroundColor(.auraOnSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.auraOnSurface.opacity(0.12), lineWidth: 1)
                                    )
                            }

                            // Wake up time
                            sectionCard(icon: "alarm.fill", iconColor: Color(hex: "FF9E66"),
                                        title: isEnglish ? "Wake Up Time" : "Uyanma Saatin") {
                                HStack {
                                    Text(isEnglish ? "Wake Up Time" : "Uyanma Saati")
                                        .font(.subheadline)
                                        .foregroundColor(.auraOnSurface.opacity(0.7))
                                    Spacer()
                                    DatePicker("", selection: $viewModel.wakeUpTime,
                                               displayedComponents: .hourAndMinute)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .tint(.auraPrimary)
                                }
                            }

                            // Genres
                            sectionCard(icon: "music.note.list", iconColor: Color(hex: "34C759"),
                                        title: isEnglish
                                            ? "Favorite Genres (Max \(Profile.maxGenreSelection))"
                                            : "Sevdiğin Türler (Maks \(Profile.maxGenreSelection))") {
                                ScrollView(.horizontal, showsIndicators: true) {
                                    LazyHGrid(
                                        rows: [GridItem(.fixed(36)), GridItem(.fixed(36))],
                                        spacing: 10
                                    ) {
                                        ForEach(viewModel.availableGenres, id: \.self) { genre in
                                            let isSelected = viewModel.selectedGenres.contains(genre)
                                            Button(action: {
                                                withAnimation(.spring(response: 0.3)) {
                                                    viewModel.toggleGenre(genre)
                                                }
                                            }) {
                                                Text(LocalizedStringKey(genre))
                                                    .font(.caption.weight(.semibold))
                                                    .padding(.vertical, 7)
                                                    .padding(.horizontal, 14)
                                                    .background(isSelected
                                                        ? Color.auraPrimary
                                                        : Color.auraSurface)
                                                    .foregroundColor(isSelected
                                                        ? .white
                                                        : Color.auraOnSurface.opacity(0.8))
                                                    .clipShape(Capsule())
                                                    .overlay(
                                                        Capsule()
                                                            .stroke(isSelected
                                                                ? Color.auraPrimary
                                                                : Color.auraOnSurface.opacity(0.2),
                                                                    lineWidth: 1)
                                                    )
                                                    .scaleEffect(isSelected ? 1.04 : 1.0)
                                            }
                                        }
                                    }
                                    .padding(.bottom, 10)
                                    .padding(.horizontal, 2)
                                }
                                .frame(height: 96)
                            }

                            // Platform
                            sectionCard(icon: "headphones", iconColor: Color(hex: "FF2D55"),
                                        title: isEnglish ? "Music Platform" : "Müzik Uygulaması") {
                                VStack(spacing: 10) {
                                    ForEach(viewModel.availablePlatforms, id: \.self) { platform in
                                        let isSelected = viewModel.selectedPlatform == platform
                                        Button(action: { viewModel.selectedPlatform = platform }) {
                                            HStack(spacing: 12) {
                                                Image(systemName: platformIcon(platform))
                                                    .font(.system(size: 18, weight: .semibold))
                                                    .foregroundColor(isSelected ? .white : .auraOnSurface.opacity(0.6))
                                                    .frame(width: 32, height: 32)
                                                    .background(isSelected ? Color.auraPrimary : Color.auraSurface)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                                Text(platform)
                                                    .font(.subheadline.weight(.medium))
                                                    .foregroundColor(.auraOnSurface)
                                                Spacer()
                                                if isSelected {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.auraPrimary)
                                                        .font(.system(size: 20))
                                                }
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 12)
                                            .background(isSelected
                                                ? Color.auraPrimary.opacity(0.08)
                                                : Color.auraSurface)
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(isSelected
                                                        ? Color.auraPrimary.opacity(0.4)
                                                        : Color.auraOnSurface.opacity(0.1),
                                                            lineWidth: 1)
                                            )
                                        }
                                    }
                                }
                            }

                            // About
                            Button(action: { showAbout = true }) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color(hex: "5AC8FA").opacity(0.15))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: "info.circle.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(Color(hex: "5AC8FA"))
                                    }
                                    Text(isEnglish ? "About AuraTune" : "AuraTune Hakkında")
                                        .font(.headline)
                                        .foregroundColor(.auraOnSurface)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.auraOnSurface.opacity(0.35))
                                }
                                .padding(16)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color.auraOnSurface.opacity(0.07), lineWidth: 1)
                                )
                            }

                            // Save Button removed — now a floating bar below
                            Color.clear.frame(height: 100)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 0)
                    }
                }

                // Floating Save Bar
                if viewModel.hasChanges {
                    VStack {
                        Spacer()
                        Button(action: {
                            Task {
                                await viewModel.saveSettings()
                                withAnimation { showSavedBadge = true }
                                try? await Task.sleep(nanoseconds: 2_000_000_000)
                                withAnimation { showSavedBadge = false }
                            }
                        }) {
                            HStack(spacing: 10) {
                                if viewModel.isSaving {
                                    ProgressView().tint(.white)
                                    Text(isEnglish ? "Saving..." : "Kaydediliyor...")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                } else if showSavedBadge {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.headline)
                                    Text(isEnglish ? "Saved!" : "Kaydedildi!")
                                        .font(.headline)
                                } else {
                                    Image(systemName: "square.and.arrow.down.fill")
                                        .font(.headline)
                                    Text(isEnglish ? "Save Changes" : "Değişiklikleri Kaydet")
                                        .font(.headline)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.auraPrimary, Color(hex: "F4845F")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(18)
                            .shadow(color: Color.auraPrimary.opacity(0.4), radius: 16, x: 0, y: 8)
                        }
                        .disabled(viewModel.userName.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSaving)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationBarHidden(true)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.hasChanges)
            .onChange(of: viewModel.userName) { _ in viewModel.checkChanges() }
            .onChange(of: viewModel.wakeUpTime) { _ in viewModel.checkChanges() }
            .onChange(of: viewModel.selectedGenres) { _ in viewModel.checkChanges() }
            .onChange(of: viewModel.selectedPlatform) { _ in viewModel.checkChanges() }
            .onChange(of: viewModel.selectedSongLanguage) { _ in viewModel.checkChanges() }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .sheet(isPresented: $isLibrarySheetPresented) {
                FavoritesView()
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                if let profile = supabaseManager.userProfile {
                    viewModel.loadProfile(profile)
                }
            }
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Hero Header
    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Decorative circles
            Circle()
                .fill(Color.white.opacity(0.06))
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

            VStack(alignment: .leading, spacing: 6) {
                Text(isEnglish ? "Profile" : "Profil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))

                Text(viewModel.userName.isEmpty ? "AuraTune" : viewModel.userName)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Stat pills (non-tappable)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        statPill(
                            icon: "clock.fill",
                            color: Color(hex: "7C6AF7"),
                            label: isEnglish ? "Wake Up" : "Uyanma",
                            value: {
                                let f = DateFormatter()
                                f.timeStyle = .short
                                return f.string(from: supabaseManager.userProfile?.wakeUpTime ?? Date())
                            }()
                        )
                        statPill(
                            icon: "music.note.list",
                            color: Color(hex: "34C759"),
                            label: isEnglish ? "Genres" : "Tür",
                            value: "\(viewModel.selectedGenres.count)"
                        )
                        statPill(
                            icon: "headphones",
                            color: Color(hex: "F4845F"),
                            label: isEnglish ? "Platform" : "Platform",
                            value: {
                                let p = viewModel.selectedPlatform
                                if p == "Apple Music" { return "Apple" }
                                if p == "YouTube Music" { return "YouTube" }
                                return p.isEmpty ? "-" : p
                            }()
                        )
                    }

                    // Row 2: Library (centered, tappable)
                    HStack(spacing: 8) {
                        Spacer()
                        Button(action: { isLibrarySheetPresented = true }) {
                            libraryPill(
                                icon: "heart.fill",
                                color: Color(hex: "FF2D55"),
                                label: isEnglish ? "Likes" : "Beğendiklerim",
                                value: "\(favoritesManager.favorites.count)"
                            )
                        }
                        Button(action: { isLibrarySheetPresented = true }) {
                            libraryPill(
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

    private func statPill(icon: String, color: Color, label: String, value: String) -> some View {
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

    private func libraryPill(icon: String, color: Color, label: String, value: String) -> some View {
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

    // MARK: - Section Card Builder
    @ViewBuilder
    private func sectionCard<Content: View>(
        icon: String,
        iconColor: Color,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                Text(title)
                    .font(.headline)
                    .foregroundColor(.auraOnSurface)
            }

            content()
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.auraOnSurface.opacity(0.07), lineWidth: 1)
        )
    }

    // MARK: - Platform Icon
    private func platformIcon(_ platform: String) -> String {
        switch platform {
        case "Spotify": return "music.note"
        case "Apple Music": return "applelogo"
        case "YouTube Music": return "play.rectangle.fill"
        default: return "headphones"
        }
    }
}
