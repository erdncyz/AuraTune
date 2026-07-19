import Foundation
import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

extension Notification.Name {
    static let firebaseAuthUserDidChange = Notification.Name("firebaseAuthUserDidChange")
}

enum FirebaseManagerError: LocalizedError {
    case unauthenticated

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return "The authentication session is unavailable."
        }
    }
}

/// Firebase Manager to handle auth and Firestore database interactions
class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    @Published var currentUser: FirebaseAuth.User?
    @Published var userProfile: Profile?
    @Published var isInitialized: Bool = false
    
    private let db = Firestore.firestore()
    private var authListener: AuthStateDidChangeListenerHandle?
    
    private init() {}
    
    deinit {
        if let listener = authListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    /// Auth and DB Initialization
    func initialize() async {
        // Set up auth state listener
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                NotificationCenter.default.post(
                    name: .firebaseAuthUserDidChange,
                    object: nil,
                    userInfo: ["userID": user?.uid as Any]
                )
                if let user, !user.isAnonymous {
                    await self?.fetchProfile()
                } else {
                    self?.userProfile = nil
                }
            }
        }
        
        // If we have an authenticated user from previous session, continue.
        if let user = Auth.auth().currentUser, !user.isAnonymous {
            self.currentUser = user
            await fetchProfile()
        } else {
            self.currentUser = nil
            self.userProfile = nil
        }
        
        DispatchQueue.main.async {
            self.isInitialized = true
        }
    }

    func register(email: String, password: String, displayName: String?) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        if let displayName, !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try await updateAuthDisplayName(displayName)
        }
        DispatchQueue.main.async {
            self.currentUser = result.user
        }
        await fetchProfile()
    }

    func login(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        DispatchQueue.main.async {
            self.currentUser = result.user
        }
        await fetchProfile()
    }

    func signOut() throws {
        do {
            NotificationManager.shared.cancelDailyMusicNotification(
                forUserID: currentUser?.uid
            )
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                self.currentUser = nil
                self.userProfile = nil
                NotificationCenter.default.post(
                    name: .firebaseAuthUserDidChange,
                    object: nil,
                    userInfo: ["userID": NSNull()]
                )
            }
        } catch {
            throw error
        }
    }

    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    func updateAuthDisplayName(_ name: String) async throws {
        guard let user = Auth.auth().currentUser else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let request = user.createProfileChangeRequest()
        request.displayName = trimmedName
        try await request.commitChanges()
    }

    func suggestedOnboardingName() -> String? {
        if let profileName = userProfile?.name.trimmingCharacters(in: .whitespacesAndNewlines), !profileName.isEmpty {
            return profileName
        }

        if let displayName = currentUser?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !displayName.isEmpty {
            return displayName
        }

        if let email = currentUser?.email,
           let localPart = email.split(separator: "@").first {
            let cleaned = localPart.replacingOccurrences(of: ".", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                return cleaned.capitalized
            }
        }

        return nil
    }

    func deleteCurrentAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }
        let userId = user.uid

        try await db.collection("profiles").document(userId).delete()
        try await user.delete()
        NotificationManager.shared.cancelDailyMusicNotification(forUserID: userId)

        DispatchQueue.main.async {
            self.currentUser = nil
            self.userProfile = nil
        }
    }

    /// Optional fallback guest mode if needed by product flows.
    func signInAnonymously() async {
        do {
            let authResult = try await Auth.auth().signInAnonymously()
            DispatchQueue.main.async {
                self.currentUser = authResult.user
            }
        } catch {
            print("Failed to sign in anonymously: \(error)")
        }
    }
    
    /// Fetches the current user's profile from Firestore
    func fetchProfile() async {
        guard let userId = currentUser?.uid else { return }
        do {
            let document = try await db.collection("profiles").document(userId).getDocument()
            
            if document.exists, let data = document.data() {
                let profile = try Firestore.Decoder().decode(Profile.self, from: data)
                DispatchQueue.main.async {
                    self.userProfile = profile
                    NotificationManager.shared.ensureDailyMusicNotification(for: profile)
                }
            } else {
                DispatchQueue.main.async {
                    self.userProfile = nil
                }
            }
        } catch {
            print("Failed to fetch profile: \(error)")
        }
    }
    
    /// Updates or creates user profile in Firestore
    func saveProfile(_ profile: Profile) async throws {
        guard let userId = currentUser?.uid else {
            throw FirebaseManagerError.unauthenticated
        }
        var updatedProfile = profile
        if updatedProfile.id == nil {
            updatedProfile.id = UUID(uuidString: userId)
        }

        let data = try Firestore.Encoder().encode(updatedProfile)
        try await db.collection("profiles").document(userId).setData(data, merge: true)
        userProfile = updatedProfile
        NotificationManager.shared.ensureDailyMusicNotification(for: updatedProfile)
    }
}
