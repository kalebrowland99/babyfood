import Foundation

enum Config {
    // MARK: - OpenAI Configuration
    static let openAIApiKey: String = APIKeys.openAI
    static let defaultModel = "gpt-4-turbo-preview"
    static let defaultMaxTokens = 500
    static let defaultTemperature = 0.7
    
    // MARK: - SerpAPI Configuration
    static let serpAPIKey: String = APIKeys.serpAPI
    
    // MARK: - Tool-specific Configurations
    static let toolConfigs: [String: ToolConfig] = [
        "AI Bar Generator": ToolConfig(
            model: "gpt-4-turbo-preview",
            maxTokens: 300,
            temperature: 0.8
        ),
        "Alliterate It": ToolConfig(
            model: "gpt-4-turbo-preview",
            maxTokens: 150,
            temperature: 0.7
        ),
        "Chorus Creator": ToolConfig(
            model: "gpt-4-turbo-preview",
            maxTokens: 400, 
            temperature: 0.8
        ),
        "Creative One-Liner": ToolConfig(
            model: "gpt-4-turbo-preview",
            maxTokens: 200,
            temperature: 0.9
        ),
        "Diss Track Generator": ToolConfig(
            model: "gpt-4-turbo-preview",
            maxTokens: 500,
            temperature: 0.8
        ),
        "Double Entendre": ToolConfig(
            model: "gpt-4-turbo-preview",
            maxTokens: 200,
            temperature: 0.9
        ),
        "Finisher": ToolConfig(
            model: "gpt-4-turbo-preview",
            maxTokens: 500,
            temperature: 0.7
        ),
        "Flex-on-'em": ToolConfig(
            model: "gpt-4-turbo-preview",
            maxTokens: 400,
            temperature: 0.8
        ),
        "Imperfect Rhyme": ToolConfig(
            model: "gpt-4-turbo-preview",
            maxTokens: 150,
            temperature: 0.7
        ),
        "Industry Analyzer": ToolConfig(
            model: "gpt-4-turbo-preview",
            maxTokens: 600,
            temperature: 0.3
        ),
        "Quadruple Entendre": ToolConfig(
            model: "gpt-4-turbo-preview",
            maxTokens: 300,
            temperature: 0.9
        ),
        "Rap Instagram Captions": ToolConfig(
            model: "gpt-4-turbo-preview",
            maxTokens: 200,
            temperature: 0.8
        ),
        "Rap Name Generator": ToolConfig(
            model: "gpt-4-turbo-preview",
            maxTokens: 100,
            temperature: 0.9
        ),
        "Shapeshift": ToolConfig(
            model: "gpt-4-turbo-preview",
            maxTokens: 150,
            temperature: 0.7
        ),
        "Triple Entendre": ToolConfig(
            model: "gpt-4-turbo-preview",
            maxTokens: 250,
            temperature: 0.9
        ),
        "Ultimate Come Up Song": ToolConfig(
            model: "gpt-4-turbo-preview",
            maxTokens: 500,
            temperature: 0.8
        )
    ]
}

struct ToolConfig {
    let model: String
    let maxTokens: Int
    let temperature: Double
} 
