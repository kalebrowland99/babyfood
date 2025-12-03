import Foundation

class SerpAPIService: ObservableObject {
    static let shared = SerpAPIService()
    private let apiKey = APIKeys.serpAPI
    private let baseURL = "https://serpapi.com/search"
    
    private init() {}
    
    func searchProducts(query: String, completion: @escaping (Result<SerpSearchResult, Error>) -> Void) {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(.failure(SerpAPIError.invalidQuery))
            return
        }
        
        let urlString = "\(baseURL)?engine=google_shopping&q=\(encodedQuery)&api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(SerpAPIError.invalidURL))
            return
        }
        
        print("🔍 SerpAPI Request: \(urlString)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ SerpAPI Error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(SerpAPIError.noData))
                return
            }
            
            do {
                let searchResult = try JSONDecoder().decode(SerpSearchResult.self, from: data)
                print("✅ SerpAPI Success: Found \(searchResult.shopping_results?.count ?? 0) shopping results")
                DispatchQueue.main.async {
                    completion(.success(searchResult))
                }
            } catch {
                print("❌ SerpAPI Decode Error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    func searchWithLocation(query: String, location: String = "United States", completion: @escaping (Result<SerpSearchResult, Error>) -> Void) {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedLocation = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(.failure(SerpAPIError.invalidQuery))
            return
        }
        
        let urlString = "\(baseURL)?engine=google_shopping&q=\(encodedQuery)&location=\(encodedLocation)&api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(SerpAPIError.invalidURL))
            return
        }
        
        print("🔍 SerpAPI Request with location: \(urlString)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ SerpAPI Error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(SerpAPIError.noData))
                return
            }
            
            do {
                let searchResult = try JSONDecoder().decode(SerpSearchResult.self, from: data)
                print("✅ SerpAPI Success with location: Found \(searchResult.shopping_results?.count ?? 0) shopping results")
                DispatchQueue.main.async {
                    completion(.success(searchResult))
                }
            } catch {
                print("❌ SerpAPI Decode Error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
}

// MARK: - Error Types
enum SerpAPIError: Error, LocalizedError {
    case invalidQuery
    case invalidURL
    case noData
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidQuery:
            return "Invalid search query"
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}
