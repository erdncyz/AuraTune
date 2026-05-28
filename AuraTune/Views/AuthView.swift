import SwiftUI

struct AuthView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.auraSurface.ignoresSafeArea()

                LinearGradient(
                    colors: [Color(hex: "994A1A"), Color.auraPrimary, Color(hex: "F4B183")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 320)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea(edges: .top)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        header
                            .padding(.bottom, 4)

                        modeSelector

                        card {
                            VStack(spacing: 12) {
                                if viewModel.mode == .register {
                                    fieldTitle("auth.field.name")
                                    TextField(languageManager.localized("auth.placeholder.name"), text: $viewModel.displayName)
                                        .textInputAutocapitalization(.words)
                                        .autocorrectionDisabled(true)
                                        .textFieldStyle(.roundedBorder)
                                }

                                fieldTitle("auth.field.email")
                                TextField(languageManager.localized("auth.placeholder.email"), text: $viewModel.email)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .textFieldStyle(.roundedBorder)

                                fieldTitle("auth.field.password")
                                SecureField(languageManager.localized("auth.placeholder.password"), text: $viewModel.password)
                                    .textFieldStyle(.roundedBorder)

                                if viewModel.mode == .register {
                                    fieldTitle("auth.field.confirmPassword")
                                    SecureField(languageManager.localized("auth.placeholder.confirmPassword"), text: $viewModel.confirmPassword)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                        }

                        if let message = viewModel.errorMessage {
                            authMessageCard(text: message, color: Color(hex: "C0392B"), icon: "exclamationmark.triangle.fill")
                        }

                        if let message = viewModel.infoMessage {
                            authMessageCard(text: message, color: Color(hex: "1E824C"), icon: "checkmark.circle.fill")
                        }

                        submitButton

                        if viewModel.mode == .login {
                            Button(action: {
                                Task { await viewModel.sendPasswordReset() }
                            }) {
                                Text(LocalizedStringKey("auth.forgotPassword"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Color(hex: "994A1A"))
                            }
                        }

                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.auraPrimary)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.light)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey("auth.welcomeBack"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))

            Text("AuraTune")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(LocalizedStringKey("auth.subtitle"))
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }

    private var modeSelector: some View {
        HStack(spacing: 8) {
            modeChip(title: "auth.mode.login", mode: .login)
            modeChip(title: "auth.mode.register", mode: .register)
        }
    }

    private func modeChip(title: String, mode: AuthViewModel.Mode) -> some View {
        let isSelected = viewModel.mode == mode
        return Button(action: {
            viewModel.mode = mode
            viewModel.errorMessage = nil
            viewModel.infoMessage = nil
        }) {
            Text(LocalizedStringKey(title))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(isSelected ? .white : .auraOnSurface)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.auraPrimary : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? Color.auraPrimary : Color.auraOnSurface.opacity(0.12), lineWidth: 1)
                )
        }
    }

    private var submitButton: some View {
        Button(action: {
            Task { await viewModel.submit() }
        }) {
            Text(viewModel.mode == .login
                  ? languageManager.localized("auth.submit.login")
                  : languageManager.localized("auth.submit.register"))
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: [Color.auraPrimary, Color(hex: "F4845F")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.auraPrimary.opacity(0.35), radius: 10, x: 0, y: 6)
        }
        .disabled(!viewModel.canSubmit || viewModel.isLoading)
        .opacity((!viewModel.canSubmit || viewModel.isLoading) ? 0.6 : 1)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.auraOnSurface.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private func fieldTitle(_ text: String) -> some View {
        Text(LocalizedStringKey(text))
            .font(.caption.weight(.bold))
            .foregroundColor(.auraOnSurface.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func authMessageCard(text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text)
                .font(.footnote.weight(.semibold))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    AuthView()
        .environmentObject(LanguageManager.shared)
}
