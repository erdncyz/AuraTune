import SwiftUI

struct AuthView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var viewModel = AuthViewModel()
    @FocusState private var focusedField: Field?
    @State private var showsPassword = false
    @State private var showsConfirmation = false

    private enum Field: Hashable {
        case name
        case email
        case password
        case confirmation
    }

    private var isEnglish: Bool { languageManager.currentLanguage == "en" }

    var body: some View {
        NavigationStack {
            AuraFixedHeaderLayout {
                AuraPageHeader(
                    eyebrow: languageManager.localized("auth.welcomeBack"),
                    title: "AuraTune",
                    subtitle: languageManager.localized("auth.subtitle"),
                    icon: "waveform",
                    accent: .auraSecondary
                )
            } content: {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        languageSelector
                        modeSelector
                        credentialsCard

                        if let message = viewModel.errorMessage {
                            authMessageCard(
                                text: message,
                                color: .auraDanger,
                                icon: "exclamationmark.triangle.fill"
                            )
                        }

                        if let message = viewModel.infoMessage {
                            authMessageCard(
                                text: message,
                                color: .auraSuccess,
                                icon: "checkmark.circle.fill"
                            )
                        }

                        submitButton

                        if viewModel.mode == .login {
                            Button {
                                focusedField = nil
                                Task { await viewModel.sendPasswordReset() }
                            } label: {
                                Text(LocalizedStringKey("auth.forgotPassword"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.auraPrimaryDark)
                                    .frame(minHeight: AuraMetrics.minimumTapTarget)
                            }
                        }
                    }
                    .padding(.horizontal, AuraMetrics.pagePadding)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                    .auraContentColumn()
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.light)
        .animation(.easeOut(duration: 0.2), value: viewModel.mode)
    }

    private var languageSelector: some View {
        HStack(spacing: 12) {
            AuraIconBadge(icon: "globe", tint: .auraTertiary)
            Text(isEnglish ? "Language" : "Dil")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.auraOnSurface)
            Spacer()
            Picker("", selection: $languageManager.currentLanguage) {
                Text("TR").tag("tr")
                Text("EN").tag("en")
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 112)
        }
        .padding(12)
        .background(Color.auraSurfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous)
                .stroke(Color.auraOutline, lineWidth: 1)
        }
    }

    private var modeSelector: some View {
        HStack(spacing: 4) {
            modeButton(title: "auth.mode.login", mode: .login)
            modeButton(title: "auth.mode.register", mode: .register)
        }
        .padding(4)
        .background(Color.auraOutline.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.controlRadius, style: .continuous))
    }

    private func modeButton(title: String, mode: AuthViewModel.Mode) -> some View {
        let isSelected = viewModel.mode == mode

        return Button {
            focusedField = nil
            viewModel.mode = mode
            viewModel.errorMessage = nil
            viewModel.infoMessage = nil
        } label: {
            Text(LocalizedStringKey(title))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.auraOnSurface : Color.auraTextSecondary)
                .frame(maxWidth: .infinity, minHeight: AuraMetrics.minimumTapTarget)
                .background(isSelected ? Color.auraSurfaceElevated : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .shadow(color: isSelected ? Color.auraDeepAccent.opacity(0.07) : .clear, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var credentialsCard: some View {
        AuraSectionCard(
            title: viewModel.mode == .login
                ? languageManager.localized("auth.mode.login")
                : languageManager.localized("auth.mode.register"),
            icon: viewModel.mode == .login ? "lock.open.fill" : "person.badge.plus",
            tint: .auraPrimary
        ) {
            VStack(spacing: 15) {
                if viewModel.mode == .register {
                    standardField(
                        title: languageManager.localized("auth.field.name"),
                        placeholder: languageManager.localized("auth.placeholder.name"),
                        icon: "person",
                        text: $viewModel.displayName,
                        field: .name,
                        contentType: .name,
                        keyboardType: .default
                    )
                }

                standardField(
                    title: languageManager.localized("auth.field.email"),
                    placeholder: languageManager.localized("auth.placeholder.email"),
                    icon: "envelope",
                    text: $viewModel.email,
                    field: .email,
                    contentType: .emailAddress,
                    keyboardType: .emailAddress
                )

                passwordField(
                    title: languageManager.localized("auth.field.password"),
                    placeholder: languageManager.localized("auth.placeholder.password"),
                    text: $viewModel.password,
                    field: .password,
                    isVisible: $showsPassword
                )

                if viewModel.mode == .register {
                    passwordField(
                        title: languageManager.localized("auth.field.confirmPassword"),
                        placeholder: languageManager.localized("auth.placeholder.confirmPassword"),
                        text: $viewModel.confirmPassword,
                        field: .confirmation,
                        isVisible: $showsConfirmation
                    )
                }
            }
        }
    }

    private func standardField(
        title: String,
        placeholder: String,
        icon: String,
        text: Binding<String>,
        field: Field,
        contentType: UITextContentType?,
        keyboardType: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.auraTextSecondary)

            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(focusedField == field ? Color.auraPrimary : Color.auraTextSecondary)
                    .frame(width: 20)
                TextField(placeholder, text: text)
                    .focused($focusedField, equals: field)
                    .textContentType(contentType)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(field == .name ? .words : .never)
                    .autocorrectionDisabled(true)
                    .submitLabel(.next)
                    .onSubmit { advanceFocus(after: field) }
            }
            .auraField(isFocused: focusedField == field)
        }
    }

    private func passwordField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        isVisible: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.auraTextSecondary)

            HStack(spacing: 10) {
                Image(systemName: "lock")
                    .foregroundStyle(focusedField == field ? Color.auraPrimary : Color.auraTextSecondary)
                    .frame(width: 20)

                Group {
                    if isVisible.wrappedValue {
                        TextField(placeholder, text: text)
                    } else {
                        SecureField(placeholder, text: text)
                    }
                }
                .focused($focusedField, equals: field)
                .textContentType(viewModel.mode == .register ? .newPassword : .password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(field == .confirmation || viewModel.mode == .login ? .done : .next)
                .onSubmit { advanceFocus(after: field) }

                Button {
                    isVisible.wrappedValue.toggle()
                } label: {
                    Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                        .foregroundStyle(Color.auraTextSecondary)
                        .frame(width: AuraMetrics.minimumTapTarget, height: AuraMetrics.minimumTapTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isVisible.wrappedValue
                    ? (isEnglish ? "Hide password" : "Şifreyi gizle")
                    : (isEnglish ? "Show password" : "Şifreyi göster"))
            }
            .auraField(isFocused: focusedField == field)
        }
    }

    private var submitButton: some View {
        Button {
            focusedField = nil
            Task { await viewModel.submit() }
        } label: {
            HStack(spacing: 9) {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: viewModel.mode == .login ? "arrow.right" : "person.crop.circle.badge.plus")
                }
                Text(viewModel.mode == .login
                    ? languageManager.localized("auth.submit.login")
                    : languageManager.localized("auth.submit.register"))
            }
        }
        .buttonStyle(M3FilledButton())
        .disabled(!viewModel.canSubmit || viewModel.isLoading)
    }

    private func authMessageCard(text: String, color: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
            Text(text)
                .font(.footnote.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(color)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous)
                .stroke(color.opacity(0.2), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func advanceFocus(after field: Field) {
        switch field {
        case .name:
            focusedField = .email
        case .email:
            focusedField = .password
        case .password where viewModel.mode == .register:
            focusedField = .confirmation
        case .password, .confirmation:
            focusedField = nil
            if viewModel.canSubmit {
                Task { await viewModel.submit() }
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(LanguageManager.shared)
}