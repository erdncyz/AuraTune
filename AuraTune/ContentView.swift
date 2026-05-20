//
//  ContentView.swift
//  AuraTune
//
//  Created by Erdinç Yılmaz on 23.04.2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var firebaseManager: FirebaseManager
    @StateObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        Group {
            if !firebaseManager.isInitialized {
                ZStack {
                    Color(hex: "994A1A").ignoresSafeArea()
                    Image(systemName: "music.note")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
            } else if firebaseManager.userProfile != nil {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .environment(\.locale, Locale(identifier: languageManager.currentLanguage))
        .environmentObject(languageManager)
        .task {
            await firebaseManager.initialize()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(FirebaseManager.shared)
        .environmentObject(FavoritesManager.shared)
}
