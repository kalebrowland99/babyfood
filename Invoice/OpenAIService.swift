import Foundation
import UIKit

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
    
    func generateCompletion(prompt: String, model: String = Config.defaultModel, maxTokens: Int = Config.defaultMaxTokens, temperature: Double = Config.defaultTemperature, retryCount: Int = 0) async throws -> String {
        print("🔍 Debug: baseURL = \(baseURL)")
        guard let url = URL(string: baseURL) else {
            print("❌ Error: Could not create URL from \(baseURL)")
            throw OpenAIError.invalidURL
        }
        print("✅ URL created successfully: \(url)")
        
        let message = [["role": "user", "content": prompt]]
        let body = [
            "model": model,
            "messages": message,
            "max_tokens": maxTokens,
            "temperature": temperature
        ] as [String: Any]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60.0 // 60 second timeout
        let apiKey = Config.openAIApiKey
        print("🔍 Debug: API Key length = \(apiKey.count)")
        print("🔍 Debug: API Key starts with = \(String(apiKey.prefix(10)))...")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        // Create custom URLSession with longer timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 120.0
        let session = URLSession(configuration: config)
        
        do {
            print("🌐 Making network request to OpenAI... (attempt \(retryCount + 1))")
            let (data, response) = try await session.data(for: request)
            print("📡 Response received")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Error: Invalid response type")
                throw OpenAIError.invalidResponse
            }
            
            print("📊 HTTP Status Code: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("❌ HTTP Error: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 Response body: \(responseString)")
                }
                let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data)
                throw OpenAIError.apiError(errorResponse?.error.message ?? "HTTP \(httpResponse.statusCode) error")
            }
            
            guard let completion = try? JSONDecoder().decode(OpenAIResponse.self, from: data) else {
                throw OpenAIError.decodingError
            }
            
            return completion.choices.first?.message.content ?? ""
        } catch {
            // Retry on network errors (up to 2 retries)
            if retryCount < 2, let urlError = error as? URLError, urlError.code == .networkConnectionLost {
                print("🔄 Network error, retrying in 2 seconds... (attempt \(retryCount + 1)/3)")
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                return try await generateCompletion(prompt: prompt, model: model, maxTokens: maxTokens, temperature: temperature, retryCount: retryCount + 1)
            }
            throw error
        }
    }
    
    func generateVisionCompletion(prompt: String, images: [UIImage], maxTokens: Int = 500, temperature: Double = 0.3, retryCount: Int = 0) async throws -> String {
        print("🔍 Debug: Vision API baseURL = \(baseURL)")
        guard let url = URL(string: baseURL) else {
            print("❌ Error: Could not create URL from \(baseURL)")
            throw OpenAIError.invalidURL
        }
        print("✅ Vision URL created successfully: \(url)")
        
        // Create content array with text and images
        var contentArray: [[String: Any]] = [
            ["type": "text", "text": prompt]
        ]
        
        // Track uploaded paths for cleanup
        var uploadedPaths: [String] = []
        
        // Upload images to Firebase and use URLs
        for (index, image) in images.enumerated() {
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                // Upload to Firebase Storage and get public URL
                do {
                    let imagePath = "serp-api/vision_\(UUID().uuidString).jpg"
                    let publicURL = try await FirebaseStorageService.shared.uploadImageForSerpAPI(image: image, path: imagePath)
                    
                    // Track path for cleanup
                    uploadedPaths.append(imagePath)
                    
                    contentArray.append([
                        "type": "image_url",
                        "image_url": ["url": publicURL]
                    ])
                    
                    print("🔗 Added image \(index + 1) to vision request: \(publicURL)")
                } catch {
                    print("❌ Failed to upload image \(index + 1) for vision: \(error)")
                    // Continue with other images
                }
            }
        }
        
        let message = [
            "role": "user",
            "content": contentArray
        ] as [String: Any]
        
        let body = [
            "model": "gpt-4o", // Use GPT-4o for vision
            "messages": [message],
            "max_tokens": maxTokens,
            "temperature": temperature
        ] as [String: Any]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120.0 // Longer timeout for vision
        let apiKey = Config.openAIApiKey
        print("🔍 Debug: Vision API Key length = \(apiKey.count)")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        // Create custom URLSession with longer timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120.0
        config.timeoutIntervalForResource = 240.0
        let session = URLSession(configuration: config)
        
        do {
            print("🌐 Making Vision API request to OpenAI... (attempt \(retryCount + 1))")
            let (data, response) = try await session.data(for: request)
            print("📡 Vision response received")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Error: Invalid response type")
                throw OpenAIError.invalidResponse
            }
            
            print("📊 Vision HTTP Status Code: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("❌ Vision HTTP Error: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 Vision Response body: \(responseString)")
                }
                let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data)
                throw OpenAIError.apiError(errorResponse?.error.message ?? "HTTP \(httpResponse.statusCode) error")
            }
            
            guard let completion = try? JSONDecoder().decode(OpenAIResponse.self, from: data) else {
                throw OpenAIError.decodingError
            }
            
                        let result = completion.choices.first?.message.content ?? ""
            
            // Cleanup temporary vision images after successful API call
            for path in uploadedPaths {
                FirebaseStorageService.shared.deleteImage(at: path) { error in
                    if let error = error {
                        print("⚠️ Failed to clean up temporary vision image at \(path): \(error)")
                    } else {
                        print("🧹 Cleaned up temporary vision image: \(path)")
                    }
                }
            }
            
            return result
        } catch {
            // Cleanup temporary images even on error
            for path in uploadedPaths {
                FirebaseStorageService.shared.deleteImage(at: path) { _ in
                    print("🧹 Cleaned up temporary vision image after error: \(path)")
                }
            }
            
            // Retry on network errors (up to 2 retries)
            if retryCount < 2, let urlError = error as? URLError, urlError.code == .networkConnectionLost {
                print("🔄 Vision network error, retrying in 3 seconds... (attempt \(retryCount + 1)/3)")
                try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                return try await generateVisionCompletion(prompt: prompt, images: images, maxTokens: maxTokens, temperature: temperature, retryCount: retryCount + 1)
            }
            throw error
        }
    }
}

// Response Models
struct OpenAIResponse: Codable {
    let choices: [Choice]
}

struct Choice: Codable {
    let message: Message
}

struct Message: Codable {
    let content: String
}

struct OpenAIErrorResponse: Codable {
    let error: OpenAIErrorDetail
}

struct OpenAIErrorDetail: Codable {
    let message: String
} 
