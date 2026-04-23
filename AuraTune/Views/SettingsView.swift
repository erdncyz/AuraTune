import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var showSavedBadge = false

    var isEnglish: Bool { languageManager.currentLanguage == "en" }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.auraSurface
                // Hero gradient start color extends behind status bar and pull-down area
                Color(hex: "994A1A")
                    .frame(height: 240)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // ── Hero Banner ──────────────────────────────────
                        heroHeader

                        // ── Content Cards ────────────────────────────────
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
                                DatePicker("", selection: $viewModel.wakeUpTime,
                                           displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .frame(height: 130)
                                    .clipped()
                            }

                            // Genres
                            sectionCard(icon: "music.note.list", iconColor: Color(hex: "34C759"),
                                        title: isEnglish ? "Favorite Genres (Max 3)" : "Sevdiğin Türler (Maks 3)") {
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
                                        title: isEnglish ? "Music Platform" : "Favori Müzik Uygulaман") {
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

                            // Save Button
                            Button(action: {
                                Task {
                                    await viewModel.saveSettings()
                                    withAnimation { showSavedBadge = true }
                                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                                    withAnimation { showSavedBadge = false }
                                }
                            }) {
                                HStack(spacing: 8) {
                                    if viewModel.isSaving {
                                        ProgressView().tint(.white)
                                    } else if showSavedBadge {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text(isEnglish ? "Saved!" : "Kaydedildi!")
                                    } else {
                                        Image(systemName: "square.and.arrow.down.fill")
                                        Text(isEnglish ? "Save Changes" : "Değişiklikleri Kaydet")
                                    }
                                }
                                .font(.headline)
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
                                .shadow(color: Color.auraPrimary.opacity(0.35), radius: 12, x: 0, y: 6)
                            }
                            .disabled(viewModel.selectedGenres.isEmpty
                                || viewModel.userName.trimmingCharacters(in: .whitespaces).isEmpty
                                || viewModel.isSaving)
                            .opacity(viewModel.selectedGenres.isEmpty
                                || viewModel.userName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                            .padding(.top, 4)
                            .padding(.bottom, 32)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                    }
                }
            }
            .navigationBarHidden(true)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
            .toolbar(.visible, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
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
        ZStack(alignment: .bottom) {
            // Gradient background
            LinearGradient(
                colors: [Color(hex: "994A1A"), Color.auraPrimary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)
            .frame(height: 240)

            // Decorative circles
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 180, height: 180)
                .offset(x: 120, y: -30)
            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 120, height: 120)
                .offset(x: -100, y: 20)

            // Avatar + Name
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 76, height: 76)
                    Text(viewModel.userName.prefix(1).uppercased().isEmpty
                         ? "?" : String(viewModel.userName.prefix(1).uppercased()))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)

                Text(viewModel.userName.isEmpty
                     ? (isEnglish ? "Your Profile" : "Profilin")
                     : viewModel.userName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if !viewModel.selectedPlatform.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "headphones")
                            .font(.caption)
                        Text(viewModel.selectedPlatform)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            .padding(.bottom, 24)
        }
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
