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

    func localized(_ key: String) -> String {
        guard let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}
