import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @EnvironmentObject var languageManager: LanguageManager
    @FocusState private var isNameFocused: Bool

    private var isEnglish: Bool { languageManager.currentLanguage == "en" }
    private var canComplete: Bool {
        !viewModel.selectedGenres.isEmpty
            && !viewModel.userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.isSaving
    }

    private let genreColumns = [
        GridItem(.adaptive(minimum: 92), spacing: 8, alignment: .leading)
    ]

    var body: some View {
        NavigationStack {
            AuraFixedHeaderLayout {
                AuraPageHeader(
                    eyebrow: isEnglish ? "Make it yours" : "Sana özel",
                    title: isEnglish ? "Tune your profile" : "Profilini ayarla",
                    subtitle: isEnglish
                        ? "A few choices shape every recommendation."
                        : "Birkaç seçim, tüm önerilerini sana göre şekillendirir.",
                    icon: "slider.horizontal.3",
                    accent: .auraSecondary
                )
            } content: {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AuraMetrics.sectionSpacing) {
                        preferenceSection
                        personalSection
                        genreSection
                        platformSection

                        if let errorMessage = viewModel.errorMessage {
                            onboardingError(errorMessage)
                        }
                    }
                    .padding(.horizontal, AuraMetrics.pagePadding)
                    .padding(.top, 22)
                    .padding(.bottom, 28)
                    .auraContentColumn()
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                completionBar
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.light)
    }

    private var preferenceSection: some View {
        AuraSectionCard(
            title: isEnglish ? "Language preferences" : "Dil tercihleri",
            subtitle: isEnglish ? "For the app and the music you hear" : "Uygulama ve dinleyeceğin müzikler için",
            icon: "globe",
            tint: .auraTertiary
        ) {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Text(isEnglish ? "App language" : "Uygulama dili")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.auraOnSurface)
                    Spacer()
                    Picker("", selection: $languageManager.currentLanguage) {
                        Text("TR").tag("tr")
                        Text("EN").tag("en")
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 116)
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text(isEnglish ? "Song language" : "Şarkı dili")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.auraTextSecondary)

                    HStack(spacing: 8) {
                        ForEach(SongLanguagePreference.allCases) { option in
                            selectionButton(
                                title: option.title(isEnglish: isEnglish),
                                isSelected: viewModel.selectedSongLanguage == option
                            ) {
                                viewModel.selectedSongLanguage = option
                            }
                        }
                    }
                }
            }
        }
    }

    private var personalSection: some View {
        AuraSectionCard(
            title: isEnglish ? "Your rhythm" : "Senin ritmin",
            subtitle: isEnglish ? "How we address you and start your day" : "Sana nasıl hitap edelim ve günün ne zaman başlasın",
            icon: "person.fill",
            tint: .auraPrimary
        ) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(isEnglish ? "Your name" : "Adın")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.auraTextSecondary)
                    HStack(spacing: 10) {
                        Image(systemName: "person")
                            .foregroundStyle(isNameFocused ? Color.auraPrimary : Color.auraTextSecondary)
                            .frame(width: 20)
                        TextField(isEnglish ? "e.g. Alex" : "Örn: Aysu", text: $viewModel.userName)
                            .focused($isNameFocused)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .onSubmit { isNameFocused = false }
                    }
                    .auraField(isFocused: isNameFocused)
                }

                Divider()

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(isEnglish ? "Wake-up time" : "Uyanma saati")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.auraOnSurface)
                        Text(isEnglish ? "Used for your daily pick" : "Günlük önerin için kullanılır")
                            .font(.caption)
                            .foregroundStyle(Color.auraTextSecondary)
                    }
                    Spacer()
                    DatePicker("", selection: $viewModel.wakeUpTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(.auraPrimary)
                }
            }
        }
    }

    private var genreSection: some View {
        AuraSectionCard(
            title: isEnglish ? "Favorite genres" : "Sevdiğin türler",
            subtitle: isEnglish
                ? "Selected \(viewModel.selectedGenres.count) of \(Profile.maxGenreSelection)"
                : "\(Profile.maxGenreSelection) türden \(viewModel.selectedGenres.count) seçildi",
            icon: "music.note.list",
            tint: .auraSuccess
        ) {
            LazyVGrid(columns: genreColumns, spacing: 8) {
                ForEach(viewModel.availableGenres, id: \.self) { genre in
                    let isSelected = viewModel.selectedGenres.contains(genre)
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            viewModel.toggleGenre(genre)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.caption2.weight(.bold))
                            }
                            Text(LocalizedStringKey(genre))
                                .font(.caption.weight(.semibold))
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(isSelected ? Color.white : Color.auraOnSurface)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 7)
                        .background(isSelected ? Color.auraSuccess : Color.auraSurface)
                        .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous)
                                .stroke(isSelected ? Color.auraSuccess : Color.auraOutline, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private var platformSection: some View {
        AuraSectionCard(
            title: isEnglish ? "Listening service" : "Müzik uygulaması",
            subtitle: isEnglish ? "Songs open directly in this app" : "Şarkılar doğrudan bu uygulamada açılır",
            icon: "headphones",
            tint: .auraSecondary
        ) {
            VStack(spacing: 8) {
                ForEach(viewModel.availablePlatforms, id: \.self) { platform in
                    let isSelected = viewModel.selectedPlatform == platform
                    Button {
                        viewModel.selectedPlatform = platform
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: platformIcon(platform))
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.white : Color.auraTextSecondary)
                                .frame(width: 36, height: 36)
                                .background(isSelected ? Color.auraDeepAccent : Color.auraSurface)
                                .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))

                            Text(platform)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.auraOnSurface)
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(isSelected ? Color.auraPrimary : Color.auraOutline)
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 56)
                        .background(isSelected ? Color.auraPrimary.opacity(0.07) : Color.auraSurface)
                        .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous)
                                .stroke(isSelected ? Color.auraPrimary.opacity(0.35) : Color.auraOutline, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private func selectionButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
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

    private var completionBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                isNameFocused = false
                Task { await viewModel.completeOnboarding() }
            } label: {
                HStack(spacing: 9) {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isEnglish ? "Complete setup" : "Kurulumu tamamla")
                }
            }
            .buttonStyle(M3FilledButton())
            .disabled(!canComplete)
            .padding(.horizontal, AuraMetrics.pagePadding)
            .padding(.vertical, 12)
            .auraContentColumn()
        }
        .background(.ultraThinMaterial)
    }

    private func onboardingError(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
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

    private func platformIcon(_ platform: String) -> String {
        switch platform {
        case "Spotify": return "music.note"
        case "Apple Music": return "applelogo"
        case "YouTube Music": return "play.rectangle.fill"
        default: return "headphones"
        }
    }
}