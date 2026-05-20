import Foundation
import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

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
                if user != nil {
                    await self?.fetchProfile()
                } else {
                    // Sign in anonymously if no user
                    await self?.signInAnonymously()
                }
            }
        }
        
        // If user already exists, fetch profile
        if let user = Auth.auth().currentUser {
            self.currentUser = user
            await fetchProfile()
        } else {
            await signInAnonymously()
        }
        
        DispatchQueue.main.async {
            self.isInitialized = true
        }
    }
    
    /// Sign in anonymously
    private func signInAnonymously() async {
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
    func saveProfile(_ profile: Profile) async {
        guard let userId = currentUser?.uid else { return }
        var updatedProfile = profile
        updatedProfile.id = UUID(uuidString: userId) ?? UUID()
        
        do {
            try db.collection("profiles").document(userId).setData(from: updatedProfile, merge: true)
            
            DispatchQueue.main.async {
                self.userProfile = updatedProfile
            }
        } catch {
            print("Failed to save profile: \(error)")
        }
    }
}
