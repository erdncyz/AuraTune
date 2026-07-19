import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    enum Mode {
        case login
        case register
    }

    @Published var mode: Mode = .login
    @Published var displayName: String = ""
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    var canSubmit: Bool {
        let hasCredentials = !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty

        switch mode {
        case .login:
            return hasCredentials
        case .register:
            return hasCredentials
                && !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && password.count >= 6
                && password == confirmPassword
        }
    }

    func submit() async {
        errorMessage = nil
        infoMessage = nil

        guard canSubmit else {
            errorMessage = localized("auth.error.invalidInput")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            switch mode {
            case .login:
                try await FirebaseManager.shared.login(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            case .register:
                try await FirebaseManager.shared.register(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password,
                    displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            clearSecrets()
        } catch {
            errorMessage = firebaseFriendlyError(error)
        }
    }

    func sendPasswordReset() async {
        errorMessage = nil
        infoMessage = nil

        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty else {
            errorMessage = localized("auth.error.resetEmailRequired")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await FirebaseManager.shared.sendPasswordReset(email: cleanEmail)
            infoMessage = localized("auth.info.resetSent")
        } catch {
            errorMessage = firebaseFriendlyError(error)
        }
    }

    private func clearSecrets() {
        password = ""
        confirmPassword = ""
    }

    private func localized(_ key: String) -> String {
        LanguageManager.shared.localized(key)
    }

    private func firebaseFriendlyError(_ error: Error) -> String {
        guard let authError = error as NSError? else {
            return localized("auth.error.unexpected")
        }

        if isSimulatorKeychainError(authError) {
            return localized("auth.error.simulatorKeychain")
        }

        switch authError.code {
        case 17008:
            return localized("auth.error.invalidEmail")
        case 17009:
            return localized("auth.error.wrongPassword")
        case 17011:
            return localized("auth.error.userNotFound")
        case 17007:
            return localized("auth.error.emailInUse")
        case 17026:
            return localized("auth.error.weakPassword")
        case 17020:
            return localized("auth.error.network")
        case 17014:
            return localized("auth.error.reauthRequired")
        default:
            return authError.localizedDescription
        }
    }

    private func isSimulatorKeychainError(_ error: NSError) -> Bool {
        if error.domain == NSOSStatusErrorDomain && error.code == -34018 {
            return true
        }

        if error.localizedDescription.localizedCaseInsensitiveContains("keychain") {
            return true
        }

        if let failureReason = error.userInfo[NSLocalizedFailureReasonErrorKey] as? String,
           failureReason.localizedCaseInsensitiveContains("keychain") {
            return true
        }

        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isSimulatorKeychainError(underlying)
        }

        return false
    }

}
