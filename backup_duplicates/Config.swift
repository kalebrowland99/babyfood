import Foundation

enum Config {
    static let openAIApiKey: String = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    
    // Add more configuration values here as needed
    static let defaultModel = "gpt-4-turbo-preview"
    static let defaultMaxTokens = 500
    static let defaultTemperature = 0.7
} 