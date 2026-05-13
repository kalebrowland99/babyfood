import Foundation

/// Optional local overrides. Prefer Xcode scheme environment variables or `Invoice-Info.plist` keys
/// so secrets are not committed. See `AppConfiguration`.
enum APIKeys {
    /// Optional: set for local dev only. Prefer `OPENAI_API_KEY` in the Run scheme or `AppConfiguration`.
    static let openAI = ""

    /// Optional override for support email. Prefer `SupportEmail` in `Invoice-Info.plist` or `SUPPORT_EMAIL` env.
    static let supportEmail = ""

    static let serpAPI = ProcessInfo.processInfo.environment["SERP_API_KEY"] ?? ""

    static let googleMaps = ProcessInfo.processInfo.environment["GOOGLE_MAPS_API_KEY"] ?? ""

    static let mixpanel = ProcessInfo.processInfo.environment["MIXPANEL_TOKEN"] ?? ""

    static let facebookAppID = ProcessInfo.processInfo.environment["FACEBOOK_APP_ID"] ?? ""
    static let facebookClientToken = ProcessInfo.processInfo.environment["FACEBOOK_CLIENT_TOKEN"] ?? ""
    static let facebookDisplayName = "Little Bites"
}

// MARK: - App-wide configuration (Firebase plist + OpenAI + support)

enum AppConfiguration {
    /// Resolution order: `OPENAI_API_KEY` env → UserDefaults `openai_api_key` → `OpenAI_API_KEY` in Info.plist → `APIKeys.openAI`
    static var openAIKey: String {
        if let e = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines), !e.isEmpty {
            return e
        }
        if let u = UserDefaults.standard.string(forKey: "openai_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty {
            return u
        }
        if let dict = Bundle.main.infoDictionary,
           let s = dict["OpenAI_API_KEY"] as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        return APIKeys.openAI.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Resolution order: `SUPPORT_EMAIL` env → `SupportEmail` in Info.plist → `APIKeys.supportEmail`
    static var supportEmail: String {
        if let e = ProcessInfo.processInfo.environment["SUPPORT_EMAIL"]?.trimmingCharacters(in: .whitespacesAndNewlines), !e.isEmpty {
            return e
        }
        if let dict = Bundle.main.infoDictionary,
           let s = dict["SupportEmail"] as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty, t != "YOUR_GMAIL@gmail.com" { return t }
        }
        let fromKeys = APIKeys.supportEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fromKeys.isEmpty { return fromKeys }
        return "YOUR_GMAIL@gmail.com"
    }

    static var hasOpenAIKey: Bool { !openAIKey.isEmpty }
}
