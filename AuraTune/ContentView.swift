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
    
    var body: some View {
        Group {
            if !supabaseManager.isInitialized {
                ZStack {
                    Color(hex: "994A1A").ignoresSafeArea()
                    Image(systemName: "music.note")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
            } else if supabaseManager.userProfile != nil {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .environment(\.locale, Locale(identifier: languageManager.currentLanguage))
        .environmentObject(languageManager)
        .task {
            await supabaseManager.initialize()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SupabaseManager.shared)
}
