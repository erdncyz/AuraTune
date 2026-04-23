import SwiftUI
import Combine

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @AppStorage("appLanguage") var currentLanguage: String = "tr" {
        didSet {
            objectWillChange.send()
        }
    }
    
    // Quick helper for Gemini prompt translation
    var currentLanguageFullName: String {
        return currentLanguage == "tr" ? "Turkish" : "English"
    }
}
