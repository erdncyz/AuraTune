//
//  ContentView.swift
//  AuraTune
//
//  Created by Erdinç Yılmaz on 23.04.2026.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @StateObject private var languageManager = LanguageManager.shared
    @State private var isInitialized = false
    
    var body: some View {
        Group {
            if !isInitialized {
                Color.auraSurface.ignoresSafeArea()
                    .overlay(ProgressView().scaleEffect(1.5).tint(.auraPrimary))
            } else if supabaseManager.userProfile == nil {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .environment(\.locale, Locale(identifier: languageManager.currentLanguage))
        .environmentObject(languageManager)
        .task {
            // First time initialization
            if !isInitialized {
                await supabaseManager.initialize()
                isInitialized = true
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SupabaseManager.shared)
}
