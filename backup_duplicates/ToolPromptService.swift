import Foundation

class ToolPromptService {
    static let shared = ToolPromptService()
    
    private init() {}
    
    private func getPromptForTool(_ tool: String) -> String {
        switch tool {
        case "AI Bar Generator":
            return ToolPrompts.aiBarGenerator
        case "Alliterate It":
            return ToolPrompts.alliterateIt
        case "Chorus Creator":
            return ToolPrompts.chorusCreator
        case "Creative One-Liner":
            return ToolPrompts.creativeOneLiner
        case "Diss Track Generator":
            return ToolPrompts.dissTrackGenerator
        case "Double Entendre":
            return ToolPrompts.doubleEntendre
        case "Finisher":
            return ToolPrompts.finisher
        case "Flex-on-'em":
            return ToolPrompts.flexOnEm
        case "Imperfect Rhyme":
            return ToolPrompts.imperfectRhyme
        case "Industry Analyzer":
            return ToolPrompts.industryAnalyzer
        case "Quadruple Entendre":
            return ToolPrompts.quadrupleEntendre
        case "Rap Instagram Captions":
            return ToolPrompts.rapInstagramCaptions
        case "Rap Name Generator":
            return ToolPrompts.rapNameGenerator
        case "Shapeshift":
            return ToolPrompts.shapeshift
        case "Triple Entendre":
            return ToolPrompts.tripleEntendre
        case "Ultimate Come Up Song":
            return ToolPrompts.ultimateComeUpSong
        default:
            return "Generate creative lyrics about: {input}"
        }
    }
    
    private func getPrompt(for tool: String, input: String) -> String {
        let promptTemplate = getPromptForTool(tool)
        return promptTemplate.replacingOccurrences(of: "{input}", with: input)
    }
    
    func generateResponse(for tool: String, input: String) async throws -> String {
        let prompt = getPrompt(for: tool, input: input)
        let config = Config.toolConfigs[tool] ?? ToolConfig(
            model: Config.defaultModel,
            maxTokens: Config.defaultMaxTokens,
            temperature: Config.defaultTemperature
        )
        
        return try await OpenAIService.shared.generateCompletion(
            prompt: prompt,
            model: config.model,
            maxTokens: config.maxTokens,
            temperature: config.temperature
        )
    }
} 
