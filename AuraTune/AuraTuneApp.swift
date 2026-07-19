//
//  AuraTuneApp.swift
//  AuraTune
//
//  Created by Erdinç Yılmaz on 23.04.2026.
//

import SwiftUI
import UIKit
import FirebaseCore

@main
struct AuraTuneApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var favoritesManager = FavoritesManager.shared
    @StateObject private var historyManager = HistoryManager.shared
    @StateObject private var remindersManager = RemindersManager.shared
    
    init() {
        // Configure Firebase
        FirebaseApp.configure()
        _ = NotificationManager.shared
        
        // Keep system tab bars aligned with the app when presented in sheets.
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(red: 0xF5/255.0,
                            green: 0xF3/255.0,
                            blue: 0xF0/255.0,
                                                alpha: 1.0)
        tabAppearance.shadowColor = UIColor.black.withAlphaComponent(0.08)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(FirebaseManager.shared)
                .environmentObject(favoritesManager)
                .environmentObject(historyManager)
                .environmentObject(remindersManager)
                .preferredColorScheme(.light)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active || phase == .background {
                        remindersManager.refreshAllReminderSchedules()
                        if let profile = FirebaseManager.shared.userProfile {
                            NotificationManager.shared.ensureDailyMusicNotification(for: profile)
                        }
                    }
                }
        }
    }
}
