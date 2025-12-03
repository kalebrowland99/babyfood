import Foundation

enum APIKeys {
    static let openAI = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    static let serpAPI = ProcessInfo.processInfo.environment["SERP_API_KEY"] ?? ""
    
    // Google Maps API Key - REPLACE WITH YOUR NEW RESTRICTED KEY FROM GOOGLE CLOUD CONSOLE
    static let googleMaps = ProcessInfo.processInfo.environment["GOOGLE_MAPS_API_KEY"] ?? ""
    
    // Mixpanel API Key - Get from: https://mixpanel.com > Project Settings > Project Token
    static let mixpanel = ProcessInfo.processInfo.environment["MIXPANEL_TOKEN"] ?? ""
    
    // Facebook SDK Configuration - REAL FACEBOOK CREDENTIALS
    // Get these from: https://developers.facebook.com > Your App > Settings > Basic
    static let facebookAppID = ProcessInfo.processInfo.environment["FACEBOOK_APP_ID"] ?? ""
    static let facebookClientToken = ProcessInfo.processInfo.environment["FACEBOOK_CLIENT_TOKEN"] ?? ""
    static let facebookDisplayName = "Invoice"
}
