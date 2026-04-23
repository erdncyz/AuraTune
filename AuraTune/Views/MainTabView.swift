import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label(LocalizedStringKey("Anasayfa"), systemImage: "house.fill")
                }
            
            NotificationsView()
                .tabItem {
                    Label(LocalizedStringKey("Bildirimler"), systemImage: "bell.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label(LocalizedStringKey("Profil"), systemImage: "person.circle.fill")
                }
        }
        .tint(.auraPrimary)
    }
}
