import Foundation
import SwiftUI
import Combine
import Supabase

/// Global Supabase Client
let supabase = SupabaseClient(
  supabaseURL: URL(string: "https://uzlovyfnknacramiiirt.supabase.co")!,
  supabaseKey: "sb_publishable_gMSwMRSy_siUIcEwDLj6rQ_l-Kj71X7"
)

/// Supabase Manager to handle auth and DB interactions
class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    @Published var currentUser: User?
    @Published var userProfile: Profile?
    @Published var isInitialized: Bool = false
    
    private init() {}
    
    /// Auth and DB Initialization
    func initialize() async {
        do {
            let session = try await supabase.auth.session
            self.currentUser = session.user
            await fetchProfile()
        } catch {
            print("No active session, attempting anonymous sign in...")
            do {
                let response = try await supabase.auth.signInAnonymously()
                self.currentUser = response.user
            } catch {
                print("Failed to sign in anonymously: \(error)")
            }
        }
        DispatchQueue.main.async {
            self.isInitialized = true
        }
    }
    
    /// Fetches the current user's profile
    func fetchProfile() async {
        guard let userId = currentUser?.id else { return }
        do {
            let profile: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            DispatchQueue.main.async {
                self.userProfile = profile
            }
        } catch {
            print("Failed to fetch profile: \(error)")
        }
    }
    
    /// Updates or inserts user profile
    func saveProfile(_ profile: Profile) async {
        guard let userId = currentUser?.id else { return }
        var updatedProfile = profile
        updatedProfile.id = userId
        
        do {
            try await supabase
                .from("profiles")
                .upsert(updatedProfile)
                .execute()
            
            DispatchQueue.main.async {
                self.userProfile = updatedProfile
            }
        } catch {
            print("Failed to save profile: \(error)")
        }
    }
}
