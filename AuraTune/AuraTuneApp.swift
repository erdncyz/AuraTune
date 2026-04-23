//
//  AuraTuneApp.swift
//  AuraTune
//
//  Created by Erdinç Yılmaz on 23.04.2026.
//

import SwiftUI
import UIKit

@main
struct AuraTuneApp: App {
    
    init() {
        // Setup Local Notifications
        NotificationManager.shared.requestAuthorization()

        // Force tab bar background to match app surface color (krem)
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(red: 0xFD/255.0,
                                                green: 0xF8/255.0,
                                                blue: 0xF5/255.0,
                                                alpha: 1.0)
        tabAppearance.shadowColor = .clear
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(SupabaseManager.shared)
        }
    }
}
