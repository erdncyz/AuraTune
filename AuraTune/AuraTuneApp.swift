//
//  AuraTuneApp.swift
//  AuraTune
//
//  Created by Erdinç Yılmaz on 23.04.2026.
//

import SwiftUI

@main
struct AuraTuneApp: App {
    
    init() {
        // Setup Local Notifications
        NotificationManager.shared.requestAuthorization()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(SupabaseManager.shared)
        }
    }
}
