//
//  LanguageManager.swift
//  Invoice
//
//  Language management for in-app language switching
//  Supports: English, Spanish, Russian
//

import Foundation
import SwiftUI

/// Manages app language selection and switching
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    // MARK: - Published Properties
    
    /// Current selected language
    @Published var currentLanguage: AppLanguage {
        didSet {
            saveLanguage()
            applyLanguage()
        }
    }
    
    // MARK: - Private Properties
    
    private let languageKey = "app_selected_language"
    
    // MARK: - Initialization
    
    private init() {
        // Load saved language or default to device language
        if let savedCode = UserDefaults.standard.string(forKey: languageKey),
           let savedLanguage = AppLanguage(rawValue: savedCode) {
            self.currentLanguage = savedLanguage
        } else {
            // Auto-detect device language
            self.currentLanguage = Self.detectDeviceLanguage()
        }
        
        // Apply language on init
        applyLanguage()
    }
    
    // MARK: - Public Methods
    
    /// Change the app language
    func changeLanguage(to language: AppLanguage) {
        currentLanguage = language
    }
    
    /// Get current locale for the selected language
    var currentLocale: Locale {
        return Locale(identifier: currentLanguage.code)
    }
    
    /// Get localized string
    func localizedString(_ key: String, comment: String = "") -> String {
        guard let path = Bundle.main.path(forResource: currentLanguage.code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: comment)
        }
        return NSLocalizedString(key, bundle: bundle, comment: comment)
    }
    
    // MARK: - Private Methods
    
    private func saveLanguage() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
        print("🌍 Language saved: \(currentLanguage.name)")
    }
    
    private func applyLanguage() {
        // Set user language preference for the app
        UserDefaults.standard.set([currentLanguage.code], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        
        print("🌍 Language applied: \(currentLanguage.name) (\(currentLanguage.code))")
        
        // Force immediate update
        DispatchQueue.main.async {
            // Trigger objectWillChange to refresh all views
            self.objectWillChange.send()
        }
        
        // Notify that language changed
        NotificationCenter.default.post(name: .languageChanged, object: nil)
    }
    
    private static func detectDeviceLanguage() -> AppLanguage {
        let deviceLanguage = Locale.preferredLanguages.first ?? "en"
        
        if deviceLanguage.starts(with: "es") {
            return .spanish
        } else if deviceLanguage.starts(with: "ru") {
            return .russian
        } else {
            return .english
        }
    }
}

// MARK: - AppLanguage Enum

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    case russian = "ru"
    
    var id: String { rawValue }
    
    /// Language code (e.g., "en", "es", "ru")
    var code: String { rawValue }
    
    /// Display name in that language
    var name: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .russian: return "Русский"
        }
    }
    
    /// Display name in English (for debugging)
    var englishName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .russian: return "Russian"
        }
    }
    
    /// Flag emoji
    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .russian: return "🇷🇺"
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
}

// MARK: - SwiftUI Environment Key

struct LocaleKey: EnvironmentKey {
    static let defaultValue: Locale = Locale.current
}

extension EnvironmentValues {
    var appLocale: Locale {
        get { self[LocaleKey.self] }
        set { self[LocaleKey.self] = newValue }
    }
}

// MARK: - View Extension for Easy Localization

extension View {
    /// Apply current app language to this view
    func withAppLanguage() -> some View {
        self.environment(\.locale, LanguageManager.shared.currentLocale)
    }
}
