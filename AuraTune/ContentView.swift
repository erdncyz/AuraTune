//
//  ContentView.swift
//  AuraTune
//
//  Created by Erdinç Yılmaz on 23.04.2026.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject var firebaseManager: FirebaseManager
    @StateObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        Group {
            if !firebaseManager.isInitialized {
                ZStack {
                    Color.auraDeepAccent.ignoresSafeArea()

                    VStack(spacing: 18) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous)
                                .fill(Color.auraPrimary.opacity(0.16))
                            RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous)
                                .stroke(Color.auraPrimary.opacity(0.35), lineWidth: 1)
                            Image(systemName: "waveform")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(Color.auraPrimary)
                        }
                        .frame(width: 68, height: 68)

                        Text("AuraTune")
                            .font(.system(size: 30, weight: .bold, design: .serif))
                            .foregroundStyle(.white)

                        ProgressView()
                            .tint(.white.opacity(0.75))
                            .padding(.top, 4)
                    }
                }
                .accessibilityLabel(languageManager.currentLanguage == "en" ? "AuraTune is loading" : "AuraTune yükleniyor")
            } else if firebaseManager.currentUser == nil || firebaseManager.currentUser?.isAnonymous == true {
                AuthView()
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
