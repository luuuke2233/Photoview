import SwiftUI

enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    @MainActor
    func displayName(_ localization: LocalizationManager) -> String {
        switch self {
        case .system:
            return localization.tr("跟随系统", "Follow System")
        case .light:
            return localization.tr("浅色", "Light")
        case .dark:
            return localization.tr("深色", "Dark")
        }
    }
}

@MainActor
class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()
    
    @Published var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
        }
    }
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: saved) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .system
        }
    }
    
    var colorScheme: ColorScheme? {
        currentTheme.colorScheme
    }
}
