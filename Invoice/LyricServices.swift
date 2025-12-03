import Foundation

// This file serves as the main entry point for the LyricServices module
struct LyricServices {
    static let shared = LyricServices()
    
    private init() {}
    
    // Expose the main services
    var promptService: ToolPromptService {
        return ToolPromptService.shared
    }
    
    var openAI: OpenAIService {
        return OpenAIService.shared
    }
}
