import Foundation

enum OpenAIError: Error {
    case invalidURL
    case invalidResponse
    case noData
    case decodingError
    case apiError(String)
}

class OpenAIService {
    static let shared = OpenAIService()
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    private init() {}
    
    func generateCompletion(prompt: String, model: String = Config.defaultModel, maxTokens: Int = Config.defaultMaxTokens, temperature: Double = Config.defaultTemperature) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidURL
        }
        
        let message = [["role": "user", "content": prompt]]
        let body = [
            "model": model,
            "messages": message,
            "max_tokens": maxTokens,
            "temperature": temperature
        ] as [String: Any]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Config.openAIApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data)
            throw OpenAIError.apiError(errorResponse?.error.message ?? "Unknown error")
        }
        
        guard let completion = try? JSONDecoder().decode(OpenAIResponse.self, from: data) else {
            throw OpenAIError.decodingError
        }
        
        return completion.choices.first?.message.content ?? ""
    }
}

// Response Models
struct OpenAIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let content: String
    }
}

struct OpenAIErrorResponse: Codable {
    let error: OpenAIErrorDetail
    
    struct OpenAIErrorDetail: Codable {
        let message: String
    }
} 