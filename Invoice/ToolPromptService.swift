import Foundation

class ToolPromptService {
    static let shared = ToolPromptService()
    
    private init() {}
    
    // Tool-specific prompts
    private let prompts: [String: String] = [
        "AI Bar Generator": """
            You are a professional lyricist. Generate 4 bars that rhyme based on the following theme or topic:
            {input}
            
            Make it creative, using metaphors and wordplay. Keep it relevant to modern music trends.
            Format the response as 4 separate lines.
            """,
        
        "Alliterate It": """
            Transform the following line into an alliteration, where multiple consecutive words start with the same sound:
            {input}
            
            Make it poetic and meaningful while maintaining the original sentiment.
            """,
        
        "Chorus Creator": """
            Create a catchy chorus based on the following theme or concept:
            {input}
            
            The chorus should be:
            - 4-8 lines long
            - Memorable and easy to sing along
            - Include repetition where appropriate
            - Match the emotional tone of the theme
            """,
        
        "Creative One-Liner": """
            Generate a creative metaphor or simile related to:
            {input}
            
            Make it:
            - Original and unexpected
            - Deep and meaningful
            - Suitable for song lyrics
            - Avoid clichés
            """,
        
        "Diss Track Generator": """
            Generate clever diss lyrics about:
            {input}
            
            Make them:
            - Witty and sharp
            - Use wordplay and double meanings
            - Reference current events or culture
            - Avoid excessive profanity or harmful content
            """,
        
        "Double Entendre": """
            Create a double entendre (phrase with two meanings) about:
            {input}
            
            Requirements:
            - Both meanings should be clear but clever
            - One meaning should be literal, the other metaphorical
            - Keep it clean and radio-friendly
            - Explain both meanings after the phrase
            """,
        
        "Finisher": """
            Complete these lyrics in the same style and theme:
            {input}
            
            Analyze the:
            - Rhyme scheme
            - Theme and tone
            - Flow and rhythm
            - Maintain consistency
            """,
        
        "Flex-on-'em": """
            Generate boastful lyrics about these accomplishments:
            {input}
            
            Make them:
            - Confident but not arrogant
            - Use creative metaphors
            - Reference luxury or success
            - Keep it authentic
            """,
        
        "Imperfect Rhyme": """
            Create a pair of lines using imperfect rhyme (assonance/consonance) with these words:
            {input}
            
            Make it:
            - Poetic and meaningful
            - Use near-rhymes effectively
            - Maintain flow and rhythm
            """,
        
        "Industry Analyzer": """
            Analyze this song's commercial potential:
            {input}
            
            Consider:
            - Radio-friendliness
            - Current market trends
            - Target audience
            - Potential improvements
            - Similar successful songs
            """,
        
        "Quadruple Entendre": """
            Create a phrase with four distinct meanings related to:
            {input}
            
            Requirements:
            - Each meaning should be clear when explained
            - Meanings should be interconnected
            - Use clever wordplay
            - Explain all four meanings
            """,
        
        "Rap Instagram Captions": """
            Generate an Instagram caption based on these lyrics:
            {input}
            
            Make it:
            - Catchy and quotable
            - Use relevant emojis
            - Include hashtags
            - Reference the lyrics cleverly
            """,
        
        "Rap Name Generator": """
            Create a modern rap name inspired by:
            {input}
            
            Consider:
            - Current naming trends
            - Personal meaning
            - Memorability
            - Explain the meaning
            """,
        
        "Shapeshift": """
            Transform this word into another word through gradual changes:
            {input}
            
            Rules:
            - Change one letter at a time
            - Each step must be a real word
            - Show the transformation process
            """,
        
        "Triple Entendre": """
            Create a phrase with three distinct meanings related to:
            {input}
            
            Requirements:
            - Each meaning should be clear when explained
            - Meanings should be interconnected
            - Use clever wordplay
            - Explain all three meanings
            """
    ]
    
    func getPrompt(for tool: String, input: String) -> String {
        guard let promptTemplate = prompts[tool] else {
            return "Generate creative lyrics about: {input}"
        }
        return promptTemplate.replacingOccurrences(of: "{input}", with: input)
    }
    
    func generateResponse(for tool: String, input: String) async throws -> String {
        let prompt = getPrompt(for: tool, input: input)
        return try await OpenAIService.shared.generateCompletion(prompt: prompt)
    }
} 