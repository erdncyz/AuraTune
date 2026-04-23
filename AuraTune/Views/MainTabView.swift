import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        ZStack {
            Color.auraSurface.ignoresSafeArea()
            TabView {
                HomeView()
                    .tabItem {
                        Label(LocalizedStringKey("Anasayfa"), systemImage: "house.fill")
                    }

                DiscoverView()
                    .tabItem {
                        Label(LocalizedStringKey("Keşfet"), systemImage: "safari.fill")
                    }

                SettingsView()
                    .tabItem {
                        Label(LocalizedStringKey("Profil"), systemImage: "person.circle.fill")
                    }
            }
            .tint(.auraPrimary)
        }
    }
}
