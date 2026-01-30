//
//  FoodModels.swift
//  Invoice
//
//  Food database models and data transfer objects
//  Clean architecture - Domain layer
//

import Foundation

// MARK: - Domain Models

/// Represents a food product with nutritional information
struct FoodProduct: Identifiable, Codable {
    let id: String
    let name: String
    let brand: String?
    let imageURL: URL?
    let nutritionalInfo: NutritionalInfo?
    let servingSize: String?
    
    var displayName: String {
        if let brand = brand, !brand.isEmpty {
            return "\(name) - \(brand)"
        }
        return name
    }
}

/// Nutritional information per 100g and per serving
struct NutritionalInfo: Codable {
    // Per 100g
    let caloriesPer100g: Double?
    let proteinPer100g: Double?
    let carbsPer100g: Double?
    let fatPer100g: Double?
    let fiberPer100g: Double?
    let sugarsPer100g: Double?
    let sodiumPer100g: Double?
    
    // Per serving
    let caloriesPerServing: Double?
    let proteinPerServing: Double?
    let carbsPerServing: Double?
    let fatPerServing: Double?
}

// MARK: - API Response Models (DTOs)

/// OpenFoodFacts API search response
struct OFFSearchResponse: Codable {
    let products: [OFFProduct]
    let count: Int?
    let page: Int?
    let pageSize: Int?
    
    enum CodingKeys: String, CodingKey {
        case products, count, page
        case pageSize = "page_size"
    }
}

/// OpenFoodFacts API single product response
struct OFFProductResponse: Codable {
    let status: Int?
    let code: String?
    let product: OFFProduct?
}

/// OpenFoodFacts API product model
struct OFFProduct: Codable, Identifiable {
    let code: String?
    let productName: String?
    let productNameEn: String?
    let productNameEs: String?
    let productNameRu: String?
    let brands: String?
    let imageURL: String?
    let nutriments: OFFNutriments?
    let servingSize: String?
    
    var id: String { code ?? UUID().uuidString }
    
    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case productNameEn = "product_name_en"
        case productNameEs = "product_name_es"
        case productNameRu = "product_name_ru"
        case brands
        case imageURL = "image_url"
        case nutriments
        case servingSize = "serving_size"
    }
}

/// OpenFoodFacts nutriment data
struct OFFNutriments: Codable {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?
    let fiber100g: Double?
    let sugars100g: Double?
    let sodium100g: Double?
    
    let energyKcalServing: Double?
    let proteinsServing: Double?
    let carbohydratesServing: Double?
    let fatServing: Double?
    
    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
        case fiber100g = "fiber_100g"
        case sugars100g = "sugars_100g"
        case sodium100g = "sodium_100g"
        case energyKcalServing = "energy-kcal_serving"
        case proteinsServing = "proteins_serving"
        case carbohydratesServing = "carbohydrates_serving"
        case fatServing = "fat_serving"
    }
}

// MARK: - Mapper Extensions

extension OFFProduct {
    /// Convert API model to domain model with proper language handling
    func toDomainModel(preferredLanguage: AppLanguage) -> FoodProduct? {
        // Get product name in preferred language, fallback to default
        let name = getLocalizedName(for: preferredLanguage)
        
        // Skip products without a name in any language
        guard !name.isEmpty else { return nil }
        
        // Convert nutriments
        let nutritionalInfo: NutritionalInfo? = nutriments.map {
            NutritionalInfo(
                caloriesPer100g: $0.energyKcal100g,
                proteinPer100g: $0.proteins100g,
                carbsPer100g: $0.carbohydrates100g,
                fatPer100g: $0.fat100g,
                fiberPer100g: $0.fiber100g,
                sugarsPer100g: $0.sugars100g,
                sodiumPer100g: $0.sodium100g,
                caloriesPerServing: $0.energyKcalServing,
                proteinPerServing: $0.proteinsServing,
                carbsPerServing: $0.carbohydratesServing,
                fatPerServing: $0.fatServing
            )
        }
        
        return FoodProduct(
            id: code ?? UUID().uuidString,
            name: name,
            brand: brands,
            imageURL: imageURL.flatMap { URL(string: $0) },
            nutritionalInfo: nutritionalInfo,
            servingSize: servingSize
        )
    }
    
    /// Get product name in preferred language with intelligent fallback
    private func getLocalizedName(for language: AppLanguage) -> String {
        switch language {
        case .english:
            return productNameEn ?? productName ?? ""
        case .spanish:
            return productNameEs ?? productName ?? ""
        case .russian:
            return productNameRu ?? productName ?? ""
        }
    }
    
    /// Check if product has name in specified language
    func hasNameInLanguage(_ language: AppLanguage) -> Bool {
        let name = getLocalizedName(for: language)
        return !name.isEmpty
    }
}

// MARK: - Search Configuration

/// Configuration for food database searches
struct FoodSearchConfig {
    let pageSize: Int
    let timeout: TimeInterval
    let cacheExpiration: TimeInterval
    let maxCacheEntries: Int
    
    static let `default` = FoodSearchConfig(
        pageSize: 12,
        timeout: 10.0,
        cacheExpiration: 300, // 5 minutes
        maxCacheEntries: 20
    )
}

// MARK: - Service Errors

enum FoodServiceError: LocalizedError {
    case invalidQuery
    case invalidResponse
    case networkError(Error)
    case noResults
    case productNotFound
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .invalidQuery:
            return NSLocalizedString("invalid_search_query", comment: "")
        case .invalidResponse:
            return NSLocalizedString("unable_to_reach_database", comment: "")
        case .networkError(let error):
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost:
                    return NSLocalizedString("no_internet_connection", comment: "")
                case .timedOut:
                    return NSLocalizedString("search_timed_out", comment: "")
                default:
                    return NSLocalizedString("unable_to_reach_database", comment: "")
                }
            }
            return NSLocalizedString("search_failed", comment: "")
        case .noResults:
            return NSLocalizedString("no_results_found", comment: "")
        case .productNotFound:
            return NSLocalizedString("product_not_found", comment: "")
        case .parsingError:
            return NSLocalizedString("search_failed", comment: "")
        }
    }
}
