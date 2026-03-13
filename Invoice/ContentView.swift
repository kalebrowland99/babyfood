//
//  ContentView.swift
//  Invoice
//
//  Created by Eliana Silva on 8/19/24.
//

import SwiftUI
import StoreKit
import AVKit
import ConfettiSwiftUI
import AVFoundation
import PhotosUI
import AuthenticationServices
import CryptoKit
import FirebaseCore
import FirebaseAuth
import FirebaseFunctions
import FirebaseFirestore
import FirebaseStorage
import GoogleSignIn
import MapKit
import CoreLocation
import UIKit
import AdSupport
import AppTrackingTransparency

// MARK: - Tab Bar Hidden Environment Key
private struct TabBarHiddenKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    var tabBarHidden: Binding<Bool> {
        get { self[TabBarHiddenKey.self] }
        set { self[TabBarHiddenKey.self] = newValue }
    }
}

// MARK: - Pending Meta Event Service
/// Service to store and send Meta CAPI events after user logs in
/// This ensures we capture user email for better tracking attribution
class PendingMetaEventService {
    static let shared = PendingMetaEventService()
    
    private struct PendingPurchase: Codable {
        let transactionId: String
        let price: Double
        let planType: String
        let timestamp: Int
        let currency: String
    }
    
    private let userDefaults = UserDefaults.standard
    private let pendingPurchaseKey = "pendingMetaPurchase"
    
    private init() {}
    
    /// Store purchase data to send later when user logs in
    func storePendingPurchase(transactionId: String, price: Double, planType: String, currency: String = "USD") {
        let purchase = PendingPurchase(
            transactionId: transactionId,
            price: price,
            planType: planType,
            timestamp: Int(Date().timeIntervalSince1970),
            currency: currency
        )
        
        if let encoded = try? JSONEncoder().encode(purchase) {
            userDefaults.set(encoded, forKey: pendingPurchaseKey)
            print("💾 Stored pending Meta purchase event: \(transactionId)")
        }
    }
    
    /// Send stored purchase event after user logs in
    func sendPendingPurchaseIfExists(userEmail: String) {
        guard let data = userDefaults.data(forKey: pendingPurchaseKey),
              let purchase = try? JSONDecoder().decode(PendingPurchase.self, from: data) else {
            print("📭 No pending Meta purchase events to send")
            return
        }
        
        print("📤 Sending pending Meta purchase event with email: \(userEmail)")
        
        Task {
            await sendMetaPurchaseEvent(
                email: userEmail,
                transactionId: purchase.transactionId,
                price: purchase.price,
                planType: purchase.planType,
                timestamp: purchase.timestamp,
                currency: purchase.currency
            )
            
            // Clear pending purchase after sending
            userDefaults.removeObject(forKey: pendingPurchaseKey)
            print("✅ Cleared pending Meta purchase event")
        }
    }
    
    /// Send Meta CAPI event with all required fields per documentation
    private func sendMetaPurchaseEvent(
        email: String,
        transactionId: String,
        price: Double,
        planType: String,
        timestamp: Int,
        currency: String
    ) async {
        do {
            // Get ATT status for advertiser_tracking_enabled
            let attStatus = await getATTStatus()
            
            // Get IDFA if available
            let idfa = getIDFA()
            
            // Get app installation ID (anonymous ID)
            let installId = getInstallationID()
            
            // Build extinfo array (required for app events)
            let extinfo = buildExtInfo()
            
            let functions = Functions.functions()
            var eventData: [String: Any] = [
                "email": email,
                "price": price,
                "planType": planType,
                "transactionId": transactionId,
                "timestamp": timestamp,
                "currency": currency,
                "advertiserTrackingEnabled": attStatus ? 1 : 0,
                "applicationTrackingEnabled": attStatus ? 1 : 0,
                "extinfo": extinfo,
                "installId": installId
            ]
            
            if let idfa = idfa {
                eventData["idfa"] = idfa
            }
            
            let result = try await functions.httpsCallable("sendMetaPurchaseEvent").call(eventData)
            print("✅ Meta Conversions API: Purchase event sent successfully with email")
            if let data = result.data as? [String: Any] {
                print("📊 Meta response: \(data)")
            }
        } catch {
            print("⚠️ Meta Conversions API error (non-critical): \(error.localizedDescription)")
        }
    }
    
    private func getATTStatus() async -> Bool {
        if #available(iOS 14, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            return status == .authorized
        }
        return true
    }
    
    private func getIDFA() -> String? {
        if #available(iOS 14, *) {
            guard ATTrackingManager.trackingAuthorizationStatus == .authorized else {
                return nil
            }
        }
        
        let idfa = ASIdentifierManager.shared().advertisingIdentifier
        return idfa.uuidString != "00000000-0000-0000-0000-000000000000" ? idfa.uuidString : nil
    }
    
    private func getInstallationID() -> String {
        let key = "appInstallationID"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: key)
        return newID
    }
    
    private func buildExtInfo() -> [String] {
        let device = UIDevice.current
        let screen = UIScreen.main
        
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let osVersion = device.systemVersion
        let deviceModel = getDeviceModel()
        let locale = Locale.current.identifier
        let timezone = TimeZone.current.abbreviation() ?? ""
        let carrier = ""
        
        let screenWidth = String(Int(screen.bounds.width * screen.scale))
        let screenHeight = String(Int(screen.bounds.height * screen.scale))
        let screenDensity = String(format: "%.2f", screen.scale)
        
        let cpuCores = String(ProcessInfo.processInfo.processorCount)
        let storageInfo = getStorageInfo()
        let deviceTimezone = TimeZone.current.identifier
        
        return [
            "i2", bundleId, appVersion, appVersion, osVersion, deviceModel,
            locale, timezone, carrier, screenWidth, screenHeight, screenDensity,
            cpuCores, storageInfo.total, storageInfo.free, deviceTimezone
        ]
    }
    
    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    private func getStorageInfo() -> (total: String, free: String) {
        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory() as String)
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            
            if let totalCapacity = values.volumeTotalCapacity,
               let availableCapacity = values.volumeAvailableCapacity {
                let totalGB = String(totalCapacity / 1_073_741_824)
                let freeGB = String(availableCapacity / 1_073_741_824)
                return (total: totalGB, free: freeGB)
            }
        } catch {
            print("Error getting storage info: \(error)")
        }
        return (total: "", free: "")
    }
}

// MARK: - Analysis Results Cache
class AnalysisResultsCache {
    static let shared = AnalysisResultsCache()
    private init() {}
    
    private var clothingDetailsCache: [String: ClothingDetails] = [:]
    private var titleCache: [String: String] = [:]
    
    func storeClothingDetails(_ details: ClothingDetails, for image: UIImage) {
        let key = imageKey(for: image)
        clothingDetailsCache[key] = details
    }
    
    func storeGeneratedTitle(_ title: String, for image: UIImage) {
        let key = imageKey(for: image)
        titleCache[key] = title
    }
    
    func getClothingDetails(for image: UIImage) -> ClothingDetails? {
        let key = imageKey(for: image)
        return clothingDetailsCache[key]
    }
    
    func getGeneratedTitle(for image: UIImage) -> String? {
        let key = imageKey(for: image)
        return titleCache[key]
    }
    
    private func imageKey(for image: UIImage) -> String {
        // Create a simple hash based on image data
        guard let data = image.jpegData(compressionQuality: 0.1) else { return UUID().uuidString }
        return String(data.hashValue)
    }
    
    func clearCache() {
        clothingDetailsCache.removeAll()
        titleCache.removeAll()
    }
}

// MARK: - SerpAPI Service
class SerpAPIService: ObservableObject {
    private let apiKey = "3c540135dddf486b63c45201bb004e9bdfc8abf132be8ca3d11a9af57095a26e"
    private let baseURL = "https://serpapi.com/search"
    
    // MARK: - Text-based Search Methods
    
    func searchEBayItems(query: String, condition: String = "used") async throws -> SerpSearchResult {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "engine", value: "ebay"),
            URLQueryItem(name: "ebay_domain", value: "ebay.com"),
            URLQueryItem(name: "_nkw", value: query), // eBay uses _nkw for search query
            URLQueryItem(name: "_salic", value: "1"), // Used items only
            URLQueryItem(name: "_pgn", value: "1") // First page
        ]
        
        guard let url = components.url else {
            print("🔍 Failed to create URL for eBay search")
            throw PlacesAPIError.invalidURL
        }
        
        print("🔍 Making eBay search request: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("🔍 Invalid HTTP response from eBay")
            throw PlacesAPIError.invalidResponse
        }
        
        print("🔍 eBay response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            if let errorString = String(data: data, encoding: .utf8) {
                print("🔍 eBay error response: \(errorString)")
            }
            throw PlacesAPIError.invalidResponse
        }
        
        let result = try JSONDecoder().decode(SerpSearchResult.self, from: data)
        return result
    }
    
    func searchGoogleShopping(query: String) async throws -> SerpSearchResult {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "engine", value: "google_shopping"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "num", value: "50")
        ]
        
        guard let url = components.url else {
            print("🔍 Failed to create URL for Google Shopping")
            throw PlacesAPIError.invalidURL
        }
        
        print("🔍 Making Google Shopping request: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("🔍 Invalid HTTP response from Google Shopping")
            throw PlacesAPIError.invalidResponse
        }
        
        print("🔍 Google Shopping response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            if let errorString = String(data: data, encoding: .utf8) {
                print("🔍 Google Shopping error response: \(errorString)")
            }
            throw PlacesAPIError.invalidResponse
        }
        
        let result = try JSONDecoder().decode(SerpSearchResult.self, from: data)
        return result
    }
    
    // MARK: - Image-based Search Methods
    
    func searchWithImage(imageData: Data) async throws -> SerpSearchResult {
        print("🔍 Using Google Lens API for visual product identification...")
        
        // Use Google Lens API for the best visual product matching
        do {
            return try await searchGoogleLens(imageData: imageData)
        } catch {
            print("🔍 Google Lens search failed: \(error)")
            
            // Fallback to eBay for vintage items if Google Lens fails
            print("🔍 Falling back to eBay for vintage items")
            return try await searchEBayItems(query: "vintage fashion clothing accessories", condition: "used")
        }
    }
    
    private func searchGoogleLens(imageData: Data) async throws -> SerpSearchResult {
        // Convert Data to UIImage for Firebase Storage
        guard let uiImage = UIImage(data: imageData) else {
            print("🔍 Failed to convert image data to UIImage")
            throw PlacesAPIError.invalidResponse
        }
        
        print("🔍 Uploading image to Firebase Storage for Google Lens...")
        
        // Upload image to Firebase Storage and get public URL
        let publicImageURL = try await FirebaseStorageService.shared.uploadForReverseImageSearch(image: uiImage)
        
        print("🔍 Image uploaded successfully, making Google Lens request with URL: \(publicImageURL)")
        
        // Make Google Lens API call with image URL - pure visual search
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "engine", value: "google_lens"),
            URLQueryItem(name: "url", value: publicImageURL),
            URLQueryItem(name: "num", value: "50"),
            URLQueryItem(name: "hl", value: "en"),  // Language
            URLQueryItem(name: "gl", value: "us")   // Country
        ]
        
        guard let url = components.url else {
            print("🔍 Failed to create URL for Google Lens search")
            throw PlacesAPIError.invalidURL
        }
        
        print("🔍 Making Google Lens request: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("🔍 Invalid HTTP response from Google Lens")
            throw PlacesAPIError.invalidResponse
        }
        
        print("🔍 Google Lens response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            if let errorString = String(data: data, encoding: .utf8) {
                print("🔍 Google Lens error response: \(errorString)")
            }
            throw PlacesAPIError.invalidResponse
        }
        
        let result = try JSONDecoder().decode(SerpSearchResult.self, from: data)
        
        // Debug logging for Google Lens results
        let visualCount = result.visualMatches?.count ?? 0
        let organicCount = result.organicResults?.count ?? 0
        let imageCount = result.imageResults?.count ?? 0
        let totalCount = visualCount + organicCount + imageCount
        
        print("🔍 Google Lens API Results:")
        print("   📸 Visual Matches: \(visualCount)")
        print("   🔗 Organic Results: \(organicCount)")
        print("   🖼️ Image Results: \(imageCount)")
        print("   📊 Total Results: \(totalCount)")
        
        return result
    }
    

    

}

// MARK: - Cache Models
struct CachedMarketData: Codable {
    let searchResult: SerpSearchResult
    let cachedAt: Date
    let searchQuery: String
    let hasCustomImage: Bool
    
    // Cache persists indefinitely - only cleared manually when new photos are added
    var isValid: Bool {
        return true // Never expires
    }
}

struct CachedOpenAIResponse: Codable {
    let response: String
    let prompt: String
    let tool: String
    let input: String
    let cachedAt: Date
    
    // Check if cache is still valid (7 days for OpenAI responses)
    var isValid: Bool {
        Date().timeIntervalSince(cachedAt) < 7 * 24 * 60 * 60 // 7 days
    }
}

// MARK: - Market Data Cache Service
class MarketDataCache {
    static let shared = MarketDataCache()
    private init() {}
    
    private let userDefaults = UserDefaults.standard
    private let marketDataKey = "cached_market_data"
    private let openaiResponseKey = "cached_openai_responses"
    private let searchQueryCacheKey = "cached_search_queries" // New: Cache by search query as fallback
    
    // MARK: - Market Data Caching
    
    func saveMarketData(_ data: SerpSearchResult, for songId: String, searchQuery: String, hasCustomImage: Bool) {
        let cacheKey = generateMarketDataCacheKey(songId: songId, hasCustomImage: hasCustomImage)
        let searchQueryKey = generateSearchQueryCacheKey(searchQuery: searchQuery, hasCustomImage: hasCustomImage)
        
        let cachedData = CachedMarketData(
            searchResult: data,
            cachedAt: Date(),
            searchQuery: searchQuery,
            hasCustomImage: hasCustomImage
        )
        
        do {
            let encoded = try JSONEncoder().encode(cachedData)
            
            // Save by song ID (primary cache)
            var allCachedData = getAllMarketData()
            allCachedData[cacheKey] = encoded
            
            // Save by search query (fallback cache)
            var searchQueryCache = getAllSearchQueryCache()
            searchQueryCache[searchQueryKey] = encoded
            
            // Clean up expired entries
            cleanupExpiredMarketData(&allCachedData)
            cleanupExpiredSearchQueryCache(&searchQueryCache)
            
            userDefaults.set(allCachedData, forKey: marketDataKey)
            userDefaults.set(searchQueryCache, forKey: searchQueryCacheKey)
            
            print("✅ Market data cached for song ID key: \(cacheKey)")
            print("✅ Market data cached for search query key: \(searchQueryKey)")
            print("🗂️ Total cached entries: \(allCachedData.count) songs, \(searchQueryCache.count) queries")
        } catch {
            print("❌ Failed to cache market data: \(error)")
        }
    }
    
    func getMarketData(for songId: String, hasCustomImage: Bool) -> SerpSearchResult? {
        let cacheKey = generateMarketDataCacheKey(songId: songId, hasCustomImage: hasCustomImage)
        let allCachedData = getAllMarketData()
        
        guard let data = allCachedData[cacheKey],
              let cachedData = try? JSONDecoder().decode(CachedMarketData.self, from: data) else {
            print("🔍 No cached market data found for song ID: \(songId)")
            return nil
        }
        
        if cachedData.isValid {
            print("✅ Found valid cached market data for song ID: \(songId)")
            return cachedData.searchResult
        } else {
            print("⏰ Cached market data expired for song ID: \(songId)")
            // Remove expired entry
            removeMarketData(for: songId, hasCustomImage: hasCustomImage)
            return nil
        }
    }
    
    // New: Get market data by search query as fallback
    func getMarketDataByQuery(searchQuery: String, hasCustomImage: Bool) -> SerpSearchResult? {
        let searchQueryKey = generateSearchQueryCacheKey(searchQuery: searchQuery, hasCustomImage: hasCustomImage)
        let searchQueryCache = getAllSearchQueryCache()
        
        guard let data = searchQueryCache[searchQueryKey],
              let cachedData = try? JSONDecoder().decode(CachedMarketData.self, from: data) else {
            print("🔍 No cached market data found for search query: \(searchQuery)")
            return nil
        }
        
        if cachedData.isValid {
            print("✅ Found valid cached market data for search query: \(searchQuery)")
            return cachedData.searchResult
        } else {
            print("⏰ Cached market data expired for search query: \(searchQuery)")
            // Remove expired entry
            removeMarketDataByQuery(searchQuery: searchQuery, hasCustomImage: hasCustomImage)
            return nil
        }
    }
    
    func removeMarketData(for songId: String, hasCustomImage: Bool) {
        let cacheKey = generateMarketDataCacheKey(songId: songId, hasCustomImage: hasCustomImage)
        var allCachedData = getAllMarketData()
        allCachedData.removeValue(forKey: cacheKey)
        userDefaults.set(allCachedData, forKey: marketDataKey)
        print("🗑️ Removed cached market data for song ID: \(songId)")
    }
    
    // New: Remove market data by search query
    func removeMarketDataByQuery(searchQuery: String, hasCustomImage: Bool) {
        let searchQueryKey = generateSearchQueryCacheKey(searchQuery: searchQuery, hasCustomImage: hasCustomImage)
        var searchQueryCache = getAllSearchQueryCache()
        searchQueryCache.removeValue(forKey: searchQueryKey)
        userDefaults.set(searchQueryCache, forKey: searchQueryCacheKey)
        print("🗑️ Removed cached market data for search query: \(searchQuery)")
    }
    
    // MARK: - OpenAI Response Caching
    
    func saveOpenAIResponse(_ response: String, for tool: String, input: String, prompt: String) {
        let cacheKey = generateOpenAICacheKey(tool: tool, input: input)
        let cachedResponse = CachedOpenAIResponse(
            response: response,
            prompt: prompt,
            tool: tool,
            input: input,
            cachedAt: Date()
        )
        
        do {
            let encoded = try JSONEncoder().encode(cachedResponse)
            var allCachedResponses = getAllOpenAIResponses()
            allCachedResponses[cacheKey] = encoded
            
            // Clean up expired entries
            cleanupExpiredOpenAIResponses(&allCachedResponses)
            
            userDefaults.set(allCachedResponses, forKey: openaiResponseKey)
            print("✅ OpenAI response cached for tool: \(tool), input: \(input.prefix(50))...")
        } catch {
            print("❌ Failed to cache OpenAI response: \(error)")
        }
    }
    
    func getOpenAIResponse(for tool: String, input: String) -> String? {
        let cacheKey = generateOpenAICacheKey(tool: tool, input: input)
        let allCachedResponses = getAllOpenAIResponses()
        
        guard let data = allCachedResponses[cacheKey],
              let cachedResponse = try? JSONDecoder().decode(CachedOpenAIResponse.self, from: data) else {
            return nil
        }
        
        if cachedResponse.isValid {
            print("✅ Found valid cached OpenAI response for tool: \(tool)")
            return cachedResponse.response
        } else {
            print("⏰ Cached OpenAI response expired for tool: \(tool)")
            // Remove expired entry
            removeOpenAIResponse(for: tool, input: input)
            return nil
        }
    }
    
    func removeOpenAIResponse(for tool: String, input: String) {
        let cacheKey = generateOpenAICacheKey(tool: tool, input: input)
        var allCachedResponses = getAllOpenAIResponses()
        allCachedResponses.removeValue(forKey: cacheKey)
        userDefaults.set(allCachedResponses, forKey: openaiResponseKey)
        print("🗑️ Removed cached OpenAI response for tool: \(tool)")
    }
    
    // MARK: - Cache Management
    
    func clearAllCache() {
        userDefaults.removeObject(forKey: marketDataKey)
        userDefaults.removeObject(forKey: openaiResponseKey)
        userDefaults.removeObject(forKey: searchQueryCacheKey)
        print("🗑️ Cleared all cache data")
    }
    
    func getCacheStats() -> (marketDataCount: Int, openaiResponseCount: Int, searchQueryCount: Int) {
        let marketDataCount = getAllMarketData().count
        let openaiResponseCount = getAllOpenAIResponses().count
        let searchQueryCount = getAllSearchQueryCache().count
        return (marketDataCount, openaiResponseCount, searchQueryCount)
    }
    
    // Debug function to print cache contents
    func debugCacheContents() {
        let stats = getCacheStats()
        print("🔍 Cache Debug:")
        print("  - Market Data (Song ID): \(stats.marketDataCount) entries")
        print("  - Search Query Cache: \(stats.searchQueryCount) entries") 
        print("  - OpenAI Responses: \(stats.openaiResponseCount) entries")
        
        let marketData = getAllMarketData()
        if !marketData.isEmpty {
            print("📋 Market Data Keys:")
            for key in marketData.keys.sorted() {
                print("  - \(key)")
            }
        }
        
        let searchQueryData = getAllSearchQueryCache()
        if !searchQueryData.isEmpty {
            print("📋 Search Query Keys:")
            for key in searchQueryData.keys.sorted() {
                print("  - \(key)")
            }
        }
    }
    
    // Debug function to clear cache for testing (optional)
    func clearCacheForTesting() {
        clearAllCache()
        print("🧪 Cache cleared for testing - next API calls will be fresh")
    }
    
    // MARK: - Private Helper Methods
    
    private func generateMarketDataCacheKey(songId: String, hasCustomImage: Bool) -> String {
        return "market_\(songId)_\(hasCustomImage)"
    }
    
    private func generateSearchQueryCacheKey(searchQuery: String, hasCustomImage: Bool) -> String {
        let normalizedQuery = searchQuery.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
        return "query_\(normalizedQuery.hashValue)_\(hasCustomImage)"
    }
    
    private func generateOpenAICacheKey(tool: String, input: String) -> String {
        let normalizedTool = tool.lowercased().replacingOccurrences(of: " ", with: "_")
        let normalizedInput = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return "openai_\(normalizedTool)_\(normalizedInput.hashValue)"
    }
    
    private func getAllMarketData() -> [String: Data] {
        return userDefaults.object(forKey: marketDataKey) as? [String: Data] ?? [:]
    }
    
    private func getAllSearchQueryCache() -> [String: Data] {
        return userDefaults.object(forKey: searchQueryCacheKey) as? [String: Data] ?? [:]
    }
    
    private func getAllOpenAIResponses() -> [String: Data] {
        return userDefaults.object(forKey: openaiResponseKey) as? [String: Data] ?? [:]
    }
    
    private func cleanupExpiredMarketData(_ cache: inout [String: Data]) {
        let keysToRemove = cache.compactMap { key, data -> String? in
            guard let cachedData = try? JSONDecoder().decode(CachedMarketData.self, from: data) else {
                return key // Remove invalid entries
            }
            return cachedData.isValid ? nil : key
        }
        
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
        
        if !keysToRemove.isEmpty {
            print("🧹 Cleaned up \(keysToRemove.count) expired market data entries")
        }
    }
    
    private func cleanupExpiredSearchQueryCache(_ cache: inout [String: Data]) {
        let keysToRemove = cache.compactMap { key, data -> String? in
            guard let cachedData = try? JSONDecoder().decode(CachedMarketData.self, from: data) else {
                return key // Remove invalid entries
            }
            return cachedData.isValid ? nil : key
        }
        
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
        
        if !keysToRemove.isEmpty {
            print("🧹 Cleaned up \(keysToRemove.count) expired search query cache entries")
        }
    }
    
    private func cleanupExpiredOpenAIResponses(_ cache: inout [String: Data]) {
        let keysToRemove = cache.compactMap { key, data -> String? in
            guard let cachedResponse = try? JSONDecoder().decode(CachedOpenAIResponse.self, from: data) else {
                return key // Remove invalid entries
            }
            return cachedResponse.isValid ? nil : key
        }
        
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
        
        if !keysToRemove.isEmpty {
            print("🧹 Cleaned up \(keysToRemove.count) expired OpenAI response entries")
        }
    }
}

// MARK: - SerpAPI Models
struct SerpSearchResult: Codable, Equatable {
    let searchMetadata: SearchMetadata?
    let searchParameters: SearchParameters?
    let searchInformation: SearchInformation?
    let shoppingResults: [ShoppingResult]?
    let organicResults: [OrganicResult]?
    let imageResults: [ImageResult]?
    let visualMatches: [VisualMatch]?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case searchMetadata = "search_metadata"
        case searchParameters = "search_parameters"
        case searchInformation = "search_information"
        case shoppingResults = "shopping_results"
        case organicResults = "organic_results"
        case imageResults = "image_results"
        case visualMatches = "visual_matches"
        case error
    }
}

struct SearchMetadata: Codable, Equatable {
    let status: String?
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case status
        case createdAt = "created_at"
    }
}

struct SearchParameters: Codable, Equatable {
    let engine: String?
    let query: String?
    let condition: String?
}

struct SearchInformation: Codable, Equatable {
    let totalResults: String?
    let queryDisplayed: String?
    
    enum CodingKeys: String, CodingKey {
        case totalResults = "total_results"
        case queryDisplayed = "query_displayed"
    }
}

struct ShoppingResult: Codable, Equatable {
    let position: Int?
    let title: String?
    let price: String?
    let extractedPrice: Double?
    let link: String?
    let source: String?
    let rating: Double?
    let reviews: Int?
    let thumbnail: String?
    let condition: String?
    
    enum CodingKeys: String, CodingKey {
        case position, title, price, link, source, rating, reviews, thumbnail, condition
        case extractedPrice = "extracted_price"
    }
}

struct OrganicResult: Codable, Equatable {
    let position: Int?
    let title: String?
    let link: String?
    let snippet: String?
    let price: String?
    let extractedPrice: Double?
    let rating: Double?
    let reviews: Int?
    let thumbnail: String?
    
    enum CodingKeys: String, CodingKey {
        case position, title, link, snippet, price, rating, reviews, thumbnail
        case extractedPrice = "extracted_price"
    }
}

struct ImageResult: Codable, Equatable {
    let position: Int?
    let title: String?
    let link: String?
    let redirectLink: String?
    let displayedLink: String?
    let favicon: String?
    let thumbnail: String?
    let imageResolution: String?
    let snippet: String?
    let snippetHighlightedWords: [String]?
    let source: String?
    let date: String?
    
    enum CodingKeys: String, CodingKey {
        case position, title, link, favicon, thumbnail, snippet, source, date
        case redirectLink = "redirect_link"
        case displayedLink = "displayed_link"
        case imageResolution = "image_resolution"
        case snippetHighlightedWords = "snippet_highlighted_words"
    }
}

struct VisualMatch: Codable, Equatable {
    let position: Int?
    let title: String?
    let link: String?
    let source: String?
    let sourceIcon: String?
    let rating: Double?
    let reviews: Int?
    let price: PriceInfo?
    let inStock: Bool?
    let condition: String?
    let thumbnail: String?
    let thumbnailWidth: Int?
    let thumbnailHeight: Int?
    let image: String?
    let imageWidth: Int?
    let imageHeight: Int?
    
    enum CodingKeys: String, CodingKey {
        case position, title, link, source, rating, reviews, price, condition
        case thumbnail, image
        case sourceIcon = "source_icon"
        case inStock = "in_stock"
        case thumbnailWidth = "thumbnail_width"
        case thumbnailHeight = "thumbnail_height"
        case imageWidth = "image_width"
        case imageHeight = "image_height"
    }
}

struct PriceInfo: Codable, Equatable {
    let value: String?
    let extractedValue: Double?
    let currency: String?
    
    enum CodingKeys: String, CodingKey {
        case value, currency
        case extractedValue = "extracted_value"
    }
}

enum PlacesAPIError: Error {
    case invalidURL
    case invalidResponse
    case noResults
    case decodingError
}

// MARK: - Thrift Store Map Service
class ThriftStoreMapService: ObservableObject {
    private let apiKey = APIKeys.googleMaps
    private let baseURL = "https://places.googleapis.com/v1/places:searchNearby"
    
    @Published var thriftStores: [ThriftStore] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Cache to prevent duplicate API calls
    private var lastSearchLocation: CLLocation?
    private var lastSearchTime: Date?
    private let searchCooldownMinutes: TimeInterval = 30 * 60 // 30 minutes cooldown
    private let significantDistanceThreshold: CLLocationDistance = 5000 // 5km
    
    func searchNearbyThriftStores(latitude: Double, longitude: Double, radius: Int = 10) async {
        let currentLocation = CLLocation(latitude: latitude, longitude: longitude)
        
        // Check if we should skip this search to prevent excessive API calls
        if shouldSkipSearch(for: currentLocation) {
            print("⏭️ Skipping thrift store search - too recent or too close to last search")
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        print("🔍 Searching for real thrift stores near (\(latitude), \(longitude))")
        
        // Update search tracking
        lastSearchLocation = currentLocation
        lastSearchTime = Date()
        
        do {
            // First try nearby search
            var stores = try await performThriftStoreSearch(latitude: latitude, longitude: longitude, radius: radius)
            
            // If we don't have enough thrift stores, try text search as fallback
            if stores.count < 3 {
                print("🔍 Not enough thrift stores found (\(stores.count)), trying text search fallback...")
                let textSearchStores = try await performTextSearchForThriftStores(latitude: latitude, longitude: longitude)
                
                // Combine results, avoiding duplicates
                let existingIds = Set(stores.map { $0.id })
                let newStores = textSearchStores.filter { !existingIds.contains($0.id) }
                stores.append(contentsOf: newStores)
                
                print("🔍 Combined search found \(stores.count) total thrift stores")
            }
            
            await MainActor.run {
                self.thriftStores = stores
                self.isLoading = false
            }
        } catch {
            print("❌ ThriftStoreMapService error: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // Helper method to determine if we should skip the search
    private func shouldSkipSearch(for location: CLLocation) -> Bool {
        // If we have existing stores and recent search, check conditions
        guard let lastLocation = lastSearchLocation,
              let lastTime = lastSearchTime else {
            return false // First search, don't skip
        }
        
        let timeSinceLastSearch = Date().timeIntervalSince(lastTime)
        let distanceFromLastSearch = location.distance(from: lastLocation)
        
        // Skip if:
        // 1. Recent search (within cooldown period) AND
        // 2. User hasn't moved significantly
        if timeSinceLastSearch < searchCooldownMinutes && 
           distanceFromLastSearch < significantDistanceThreshold {
            return true
        }
        
        return false
    }
    
    // Method to force refresh (for manual refresh scenarios)
    func forceRefreshStores(latitude: Double, longitude: Double, radius: Int = 10) async {
        // Reset cache to force new search
        lastSearchLocation = nil
        lastSearchTime = nil
        await searchNearbyThriftStores(latitude: latitude, longitude: longitude, radius: radius)
    }
    
    // New method for text search fallback
    private func performTextSearchForThriftStores(latitude: Double, longitude: Double) async throws -> [ThriftStore] {
        let textSearchURL = "https://places.googleapis.com/v1/places:searchText"
        
        guard let url = URL(string: textSearchURL) else {
            throw PlacesAPIError.invalidURL
        }
        
        // Create request body for text search
        let requestBody: [String: Any] = [
            "textQuery": "thrift store near me",
            "maxResultCount": 10
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.primaryType", forHTTPHeaderField: "X-Goog-FieldMask")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw PlacesAPIError.invalidURL
        }
        
        print("🔍 Text search for thrift stores...")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlacesAPIError.invalidResponse
        }
        
        print("🗺️ Text search response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            if let errorString = String(data: data, encoding: .utf8) {
                print("🗺️ Text search error response: \(errorString)")
            }
            return [] // Return empty array instead of throwing to allow nearby search results to still show
        }
        
        let result = try JSONDecoder().decode(NewGooglePlacesResult.self, from: data)
        
        let stores = result.places?.compactMap { place in
            ThriftStore(from: place)
        } ?? []
        
        print("🔍 Text search found \(stores.count) thrift stores")
        
        // Filter to only nearby stores (within reasonable distance)
        let nearbyStores = stores.filter { store in
            let distance = calculateDistance(lat1: latitude, lon1: longitude, lat2: store.latitude, lon2: store.longitude)
            return distance <= 25.0 // 25km max distance
        }
        
        print("🔍 \(nearbyStores.count) text search stores are within 25km")
        
        return nearbyStores
    }
    
    // Helper function to calculate distance between two coordinates
    private func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadius = 6371.0 // Earth's radius in kilometers
        
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0
        
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return earthRadius * c
    }
    
    private func performThriftStoreSearch(latitude: Double, longitude: Double, radius: Int) async throws -> [ThriftStore] {
        // Convert radius from km to meters (Google Places API uses meters)
        let radiusInMeters = radius * 1000
        
        guard let url = URL(string: baseURL) else {
            throw PlacesAPIError.invalidURL
        }
        
        // Create request body for new Places API with expanded types to catch thrift stores
        let requestBody: [String: Any] = [
            "includedTypes": ["store", "discount_store", "clothing_store"], // Expanded to include more thrift store types
            "maxResultCount": 20,
            "locationRestriction": [
                "circle": [
                    "center": [
                        "latitude": latitude,
                        "longitude": longitude
                    ],
                    "radius": min(radiusInMeters, 50000) // Max 50km
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue("places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.primaryType", forHTTPHeaderField: "X-Goog-FieldMask")
        
        // Print bundle ID for debugging
        if let bundleId = Bundle.main.bundleIdentifier {
            print("🗺️ App bundle ID: \(bundleId)")
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw PlacesAPIError.invalidURL
        }
        
        print("🗺️ Searching for thrift stores near: \(latitude), \(longitude)")
        print("🔍 New Google Places API request with expanded types")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlacesAPIError.invalidResponse
        }
        
        print("🗺️ Places API response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            if let errorString = String(data: data, encoding: .utf8) {
                print("🗺️ Places API error response: \(errorString)")
            }
            throw PlacesAPIError.invalidResponse
        }
        
        let result = try JSONDecoder().decode(NewGooglePlacesResult.self, from: data)
        
        let stores = result.places?.compactMap { place in
            ThriftStore(from: place)
        } ?? []
        
        print("🗺️ New Google Places API found \(stores.count) potential stores")
        
        // Debug: Print first few stores to see what we're getting
        for (index, store) in stores.prefix(5).enumerated() {
            print("🔍 Store \(index + 1): '\(store.title)' at \(store.address)")
        }
        
        // Enhanced filter for thrift stores with better keyword matching
        let thriftKeywords = [
            // Core thrift terms
            "thrift", "thrifting", "thrifted", "thrift store", "thrift shop",
            
            // Secondhand terms
            "secondhand", "second-hand", "second hand", "preloved", "pre-loved", "pre loved",
            
            // Resale terms
            "resale", "resell", "recycled", "reclaimed", "hand-me-down",
            
            // Store types and names
            "consignment", "donation", "donation center", "vintage", "used", 
            "antique", "flea market", "streetwear", "retro",
            
            // Popular chains and store names
            "goodwill", "salvation army", "savers", "value village", "platos closet", "plato's closet",
            "buffalo exchange", "crossroads trading", "crossroads", "wasteland", "beacon's closet",
            "out of the closet", "community thrift", "relove", "eye thrift", "born again",
            "2nd street", "second street",
            
            // Other terms
            "charity", "discount"
        ]
        
        let thriftStores = stores.filter { store in
            let searchText = "\(store.title) \(store.address)".lowercased()
            let isThriftStore = thriftKeywords.contains { keyword in
                searchText.contains(keyword)
            }
            
            if isThriftStore {
                print("✅ Found thrift store: '\(store.title)'")
            }
            
            return isThriftStore
        }
        
        print("🗺️ Filtered to \(thriftStores.count) thrift stores")
        
        // If we still have few thrift stores, let's be more inclusive for testing
        if thriftStores.count < 3 {
            print("⚠️ Only found \(thriftStores.count) thrift stores, showing additional discount/clothing stores for testing")
            // Include stores that might be thrift stores based on type
            let additionalStores = stores.filter { store in
                let searchText = "\(store.title) \(store.address)".lowercased()
                let isAlreadyIncluded = thriftKeywords.contains { keyword in
                    searchText.contains(keyword)
                }
                // Include discount stores and some clothing stores that might be thrift stores
                return !isAlreadyIncluded && (searchText.contains("discount") || searchText.contains("vintage") || searchText.contains("used"))
            }
            return thriftStores + additionalStores.prefix(5)
        }
        
        return thriftStores
    }
}

// MARK: - Thrift Store Data Models
struct ThriftStore: Identifiable, Codable {
    let id = UUID()
    let title: String
    let address: String
    let latitude: Double
    let longitude: Double
    let rating: Double?
    let reviews: Int?
    let phoneNumber: String?
    let website: String?
    let hours: String?
    let thumbnail: String?
    
    init(from place: NewGooglePlace) {
        self.title = place.displayName?.text ?? "Store"
        self.address = place.formattedAddress ?? ""
        self.latitude = place.location.latitude
        self.longitude = place.location.longitude
        self.rating = place.rating
        self.reviews = place.userRatingCount
        self.phoneNumber = nil // Not available in basic search
        self.website = nil // Not available in basic search
        self.hours = nil // Not available in basic search
        self.thumbnail = nil // Not available in basic search
    }
    
    // Legacy initializer for backward compatibility
    init(from place: GooglePlace) {
        self.title = place.name
        self.address = place.vicinity ?? place.formatted_address ?? ""
        self.latitude = place.geometry.location.lat
        self.longitude = place.geometry.location.lng
        self.rating = place.rating
        self.reviews = place.user_ratings_total
        self.phoneNumber = nil // Not available in Nearby Search
        self.website = nil // Not available in Nearby Search
        self.hours = nil // Not available in Nearby Search
        self.thumbnail = place.photos?.first?.photo_reference
    }
    
    // Custom initializer for mock data
    init(title: String, address: String, latitude: Double, longitude: Double, rating: Double?, reviews: Int?, phoneNumber: String?, website: String?, hours: String?, thumbnail: String?) {
        self.title = title
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.rating = rating
        self.reviews = reviews
        self.phoneNumber = phoneNumber
        self.website = website
        self.hours = hours
        self.thumbnail = thumbnail
    }
}

// MARK: - New Google Places API Models
struct NewGooglePlacesResult: Codable {
    let places: [NewGooglePlace]?
}

struct NewGooglePlace: Codable {
    let id: String
    let displayName: PlaceDisplayName?
    let formattedAddress: String?
    let location: NewPlaceLocation
    let rating: Double?
    let userRatingCount: Int?
    let primaryType: String?
}

struct PlaceDisplayName: Codable {
    let text: String
}

struct NewPlaceLocation: Codable {
    let latitude: Double
    let longitude: Double
}

// MARK: - Legacy Google Places API Models (for backward compatibility)
struct GooglePlacesResult: Codable {
    let results: [GooglePlace]
    let status: String
    let error_message: String?
}

struct GooglePlace: Codable {
    let place_id: String
    let name: String
    let vicinity: String?
    let formatted_address: String?
    let geometry: PlaceGeometry
    let rating: Double?
    let user_ratings_total: Int?
    let photos: [PlacePhoto]?
    let types: [String]
    
    enum CodingKeys: String, CodingKey {
        case place_id, name, vicinity, formatted_address, geometry, rating, user_ratings_total, photos, types
    }
}

struct PlaceGeometry: Codable {
    let location: PlaceLocation
}

struct PlaceLocation: Codable {
    let lat: Double
    let lng: Double
}

struct PlacePhoto: Codable {
    let photo_reference: String
    let height: Int
    let width: Int
}

// MARK: - Enhanced Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var locationUpdateTimer: Timer?
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTrackingLocation = false
    
    // Singleton to ensure consistent location tracking across the app
    static let shared = LocationManager()
    
    // Track if we've already performed initial location fetch
    private var hasPerformedInitialLocationFetch = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 100 // Only update when user moves 100 meters (reduced frequency)
        authorizationStatus = locationManager.authorizationStatus
        
        // Track app lifecycle for optimized location services
        NotificationCenter.default.addObserver(
            self, 
            selector: #selector(appDidBecomeActive), 
            name: UIApplication.didBecomeActiveNotification, 
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self, 
            selector: #selector(appWillResignActive), 
            name: UIApplication.willResignActiveNotification, 
            object: nil
        )
    }
    
    deinit {
        locationUpdateTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func appDidBecomeActive() {
        print("📱 App became active - starting optimized location tracking")
        startOptimizedLocationTracking()
    }
    
    @objc private func appWillResignActive() {
        print("📱 App will resign active - stopping location tracking to save battery")
        stopLocationTracking()
    }
    
    func startOptimizedLocationTracking() {
        guard !isTrackingLocation else { return }
        
        isTrackingLocation = true
        
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            // Only get location once when app opens, no continuous tracking
            performSingleLocationUpdate()
        case .denied, .restricted:
            setDefaultLocation()
        @unknown default:
            print("📍 Unknown authorization status")
            locationManager.requestWhenInUseAuthorization()
        }
        
        // Remove periodic timer - we only want location on app open/close
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }
    
    // Legacy method for backward compatibility
    func startLocationTracking() {
        startOptimizedLocationTracking()
    }
    
    func stopLocationTracking() {
        isTrackingLocation = false
        locationManager.stopUpdatingLocation()
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }
    
    private func performSingleLocationUpdate() {
        // Only request location once, don't start continuous updates
        locationManager.requestLocation()
        print("📍 Requesting single location update for app session")
    }
    
    private func beginLocationUpdates() {
        // For backward compatibility, but now optimized
        performSingleLocationUpdate()
    }
    
    private func refreshLocation() {
        // Only refresh if we haven't gotten location yet
        guard isTrackingLocation && location == nil else { return }
        
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            break
        }
    }
    
    private func setDefaultLocation() {
        // Default to NYC coordinates
        location = CLLocation(latitude: 40.7589, longitude: -73.9851)
        print("📍 Set default location: NYC")
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        // Update location and stop continuous tracking to save battery
        location = newLocation
        print("📍 Location updated: \(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude)")
        
        // Stop location updates after getting the location to prevent excessive API calls
        locationManager.stopUpdatingLocation()
        
        // Mark that we've performed initial fetch for this session
        hasPerformedInitialLocationFetch = true
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
        
        // If we don't have a location yet, set default
        if location == nil {
            setDefaultLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            // Only get location once when authorization is granted
            performSingleLocationUpdate()
        case .denied, .restricted:
            setDefaultLocation()
        case .notDetermined:
            // Will be handled by the next authorization request
            break
        @unknown default:
            print("📍 Unknown authorization status")
        }
    }
}

// MARK: - Thrift Store Annotation
class ThriftStoreAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let thriftStore: ThriftStore
    
    init(thriftStore: ThriftStore) {
        self.thriftStore = thriftStore
        self.coordinate = CLLocationCoordinate2D(latitude: thriftStore.latitude, longitude: thriftStore.longitude)
        self.title = thriftStore.title
        
        var subtitleText = thriftStore.address
        if let rating = thriftStore.rating {
            subtitleText += " • ⭐ \(String(format: "%.1f", rating))"
        }
        if let reviews = thriftStore.reviews {
            subtitleText += " (\(reviews) reviews)"
        }
        self.subtitle = subtitleText
        
        super.init()
    }
}

// MARK: - Custom Apple-Style Annotation View
class ThriftStoreAnnotationView: MKAnnotationView {
    
    private var nameLabel: UILabel!
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    private func setupView() {
        canShowCallout = false
        isUserInteractionEnabled = true
        
        // Create the main container
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.isUserInteractionEnabled = true
        
        // Create store name label (lowercase, smaller, with ellipsis)
        nameLabel = UILabel()
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor = .black
        nameLabel.backgroundColor = .white
        nameLabel.layer.cornerRadius = 16  // Larger radius for new size
        nameLabel.layer.masksToBounds = false  // Allow shadow
        nameLabel.layer.borderWidth = 0.5
        nameLabel.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor  // Subtle blue hint
        
        // Add shadow using a separate shadow layer to avoid masksToBounds conflict
        nameLabel.layer.shadowColor = UIColor.black.cgColor
        nameLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        nameLabel.layer.shadowOpacity = 0.15
        nameLabel.layer.shadowRadius = 4
        nameLabel.layer.shadowPath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 130, height: 32), cornerRadius: 16).cgPath
        nameLabel.isUserInteractionEnabled = false // Let map handle the touches
        
        // Create link emoji pin
        let pinView = UILabel()
        pinView.translatesAutoresizingMaskIntoConstraints = false
        pinView.text = "🔗"
        pinView.font = UIFont.systemFont(ofSize: 24)
        pinView.textAlignment = .center
        pinView.isUserInteractionEnabled = false  // Don't block map interactions
        
        // Add subviews
        containerView.addSubview(nameLabel)
        containerView.addSubview(pinView)
        addSubview(containerView)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Container
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -20),
            
            // Name label - increased touch area
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            nameLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            nameLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 130), // Wider
            nameLabel.heightAnchor.constraint(equalToConstant: 32), // Taller for better touch
            
            // Pin (link emoji) - larger touch target
            pinView.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            pinView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            pinView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            pinView.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            pinView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }
    

    
    // Remove aggressive touch handling to allow map interactions
    
    func showCopyFeedback() {
        // Add visual feedback for tap
        UIView.animate(withDuration: 0.1, animations: {
            self.nameLabel.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            self.nameLabel.alpha = 0.8
            self.nameLabel.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.nameLabel.transform = CGAffineTransform.identity
                self.nameLabel.alpha = 1.0
                self.nameLabel.backgroundColor = .white
            }
        }
    }
    

    
    override func prepareForReuse() {
        super.prepareForReuse()
        updateContent()
    }
    
    override var annotation: MKAnnotation? {
        didSet {
            updateContent()
        }
    }
    
    private func updateContent() {
        guard let annotation = annotation as? ThriftStoreAnnotation else { return }
        nameLabel.text = "  \(annotation.thriftStore.title.lowercased())  "
    }
}

// MARK: - Map View Controller (DISABLED - GoogleMaps removed)
/* Commented out - GoogleMaps removed
class MapViewController: ObservableObject {
    private var mapView: GMSMapView?
    
    func setMapView(_ mapView: GMSMapView) {
        self.mapView = mapView
    }
    
    func zoomIn() {
        guard let mapView = mapView else { return }
        let currentZoom = mapView.camera.zoom
        let newZoom = min(currentZoom + 1, 20) // Max zoom level 20
        
        let camera = GMSCameraUpdate.zoom(to: newZoom)
        mapView.animate(with: camera)
    }
    
    func zoomOut() {
        guard let mapView = mapView else { return }
        let currentZoom = mapView.camera.zoom
        let newZoom = max(currentZoom - 1, 1) // Min zoom level 1
        
        let camera = GMSCameraUpdate.zoom(to: newZoom)
        mapView.animate(with: camera)
    }
}
*/

// Placeholder MapViewController for compatibility
class MapViewController: ObservableObject {
    func zoomIn() { }
    func zoomOut() { }
}

// MARK: - Legacy Apple Maps View (DEPRECATED - Use GoogleMapsView instead)
/*
struct ThriftStoreMapView: UIViewRepresentable {
    @StateObject private var mapService = ThriftStoreMapService()
    @ObservedObject private var locationManager = LocationManager.shared // Use singleton
    @ObservedObject var mapController: MapViewController
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        
        // Ultra-minimal map appearance - no streets or labels
        let config = MKStandardMapConfiguration()
        config.emphasisStyle = .muted
        config.pointOfInterestFilter = .excludingAll
        mapView.preferredConfiguration = config
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsTraffic = false
        mapView.showsBuildings = false
        mapView.showsPointsOfInterest = false
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        
        // Hide all text labels on map
        mapView.mapType = .mutedStandard
        
        // Set initial region based on current location or default to NYC
        let initialLocation = locationManager.location?.coordinate ?? CLLocationCoordinate2D(latitude: 40.7589, longitude: -73.9851)
        let defaultRegion = MKCoordinateRegion(
            center: initialLocation,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        mapView.setRegion(defaultRegion, animated: false)
        
        // Register custom annotation view
        mapView.register(ThriftStoreAnnotationView.self, forAnnotationViewWithReuseIdentifier: "ThriftStorePin")
        
        // Set map reference in controller for zoom functionality
        mapController.setMapView(mapView)
        
        print("🗺️ Map view initialized with location: \(initialLocation)")
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        let coordinator = context.coordinator
        
        // Update annotations when thrift stores change (no state modification here)
        let currentAnnotations = mapView.annotations.compactMap { $0 as? ThriftStoreAnnotation }
        let newStores = mapService.thriftStores
        
        // Only update annotations if the stores have actually changed
        if currentAnnotations.count != newStores.count || 
           !currentAnnotations.allSatisfy({ annotation in
               newStores.contains { $0.id == annotation.thriftStore.id }
           }) {
            
            mapView.removeAnnotations(currentAnnotations)
            let newAnnotations = newStores.map { ThriftStoreAnnotation(thriftStore: $0) }
            mapView.addAnnotations(newAnnotations)
            print("🗺️ Updated map with \(newAnnotations.count) store annotations")
        }
        
        // Handle location updates (use coordinator state, not @State)
        if let location = locationManager.location {
            // Only update region if this is the first location or user has moved significantly
            let shouldUpdateRegion = !coordinator.hasInitializedLocation || 
                                   (coordinator.lastSearchLocation == nil || 
                                    location.distance(from: coordinator.lastSearchLocation!) > 1000) // 1km threshold
            
            if shouldUpdateRegion {
                let newRegion = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                mapView.setRegion(newRegion, animated: coordinator.hasInitializedLocation)
                coordinator.hasInitializedLocation = true
                print("🗺️ Updated map region to: \(location.coordinate)")
            }
            
            // Search for thrift stores if location has changed significantly or no stores loaded
            let shouldSearchStores = coordinator.lastSearchLocation == nil || 
                                   location.distance(from: coordinator.lastSearchLocation!) > 2000 || // 2km threshold
                                   (mapService.thriftStores.isEmpty && !mapService.isLoading)
            
            if shouldSearchStores {
                coordinator.lastSearchLocation = location
                Task {
                    print("🗺️ Searching for stores near: \(location.coordinate)")
                    await mapService.searchNearbyThriftStores(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // Use coordinator to track state instead of @State to avoid infinite loops
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ThriftStoreMapView
        var hasInitializedLocation = false
        var lastSearchLocation: CLLocation?
        
        init(_ parent: ThriftStoreMapView) {
            self.parent = parent
            super.init()
            
            // Start location tracking immediately
            parent.locationManager.startLocationTracking()
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Don't customize user location annotation
            if annotation is MKUserLocation {
                return nil
            }
            
            guard annotation is ThriftStoreAnnotation else {
                return nil
            }
            
            let identifier = "ThriftStorePin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? ThriftStoreAnnotationView
            
            if annotationView == nil {
                annotationView = ThriftStoreAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = annotation
            }
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            print("🗺️ Map annotation selected")
            
            // Handle address copying when annotation is selected
            guard let annotation = view.annotation as? ThriftStoreAnnotation else { 
                return 
            }
            
            let store = annotation.thriftStore
            
            // Ensure we have a valid address
            guard !store.address.isEmpty else {
                print("❌ Store address is empty")
                return
            }
            
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Copy address to clipboard
            UIPasteboard.general.string = store.address
            print("✅ Address copied to clipboard: \(store.address)")
            
            // Add visual feedback to the annotation view
            if let annotationView = view as? ThriftStoreAnnotationView {
                annotationView.showCopyFeedback()
            }
            
            // Show feedback that address was copied
            let alert = UIAlertController(
                title: "✨ Address Copied!",
                message: "\n\(store.title)\n\(store.address)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Got it!", style: .default))
            
            // Find the top view controller to present the alert
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    
                    var topController = rootViewController
                    while let presented = topController.presentedViewController {
                        topController = presented
                    }
                    
                    topController.present(alert, animated: true)
                } else {
                    print("❌ Could not find view controller to present alert")
                }
            }
            
            // Deselect the annotation to allow multiple taps
            mapView.deselectAnnotation(annotation, animated: false)
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Disabled automatic search on map pan to prevent excessive API calls
            // Users can manually refresh if they want to search in a new area
            print("🗺️ Map region changed - automatic search disabled to save API calls")
            
            // Optional: Update last search location for reference but don't trigger search
            let currentCenter = mapView.region.center
            self.lastSearchLocation = CLLocation(latitude: currentCenter.latitude, longitude: currentCenter.longitude)
        }
    }
}
*/



// MARK: - Clothing Details Models
struct ClothingDetails: Codable, Equatable {
    let category: String?
    let style: String?
    let season: String?
    let gender: String?
    let designerTier: String?
    let era: String?
    let colors: [String]?
    let fabricComposition: [FabricComponent]?
    let isAuthentic: Bool?
    
    enum CodingKeys: String, CodingKey {
        case category, style, season, gender, era, colors
        case designerTier = "designer_tier"
        case fabricComposition = "fabric_composition"
        case isAuthentic = "is_authentic"
    }
}

struct FabricComponent: Codable, Equatable {
    let material: String
    let percentage: Int
}

// Completely static Apple Sign In Button - no visual changes allowed
struct AppleSignInButton: View {
    @ObservedObject var authManager: AuthenticationManager
    
    var body: some View {
        ZStack {
            // Static black background - never changes
            Rectangle()
                .fill(Color.black)
                .frame(maxWidth: .infinity, maxHeight: 56)
                .cornerRadius(28)
            
            // Static content - never changes
            HStack {
                Image(systemName: "applelogo")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                Text("Sign in with Apple")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .contentShape(Rectangle()) // Define tap area
        .onTapGesture {
            // Simple tap action - no button styling at all
            authManager.signInWithApple()
        }
        .allowsHitTesting(!authManager.isLoading) // Disable when loading but no visual change
    }
}

// Completely static Google Sign In Button - no visual changes allowed
struct GoogleSignInButton: View {
    @ObservedObject var authManager: AuthenticationManager
    
    var body: some View {
        ZStack {
            // Static white background with border - never changes
            Rectangle()
                .fill(Color.white)
                .frame(maxWidth: .infinity, maxHeight: 56)
                .cornerRadius(28)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )
            
            // Static content - never changes
            HStack {
                Image("google-logo")
                    .resizable()
                    .frame(width: 32, height: 32)
                Text("Sign in with Google")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.black)
            }
        }
        .contentShape(Rectangle()) // Define tap area
        .onTapGesture {
            // Simple tap action - no button styling at all
            authManager.signInWithGoogle()
        }
        .allowsHitTesting(!authManager.isLoading) // Disable when loading but no visual change
    }
}

// Completely static Get Started Button - no visual changes allowed
struct GetStartedButton: View {
    @Binding var showingOnboarding: Bool
    
    var body: some View {
        ZStack {
            // Static black background - never changes
            Rectangle()
                .fill(Color.black)
                .frame(maxWidth: .infinity, maxHeight: 56)
                .cornerRadius(28)
            
            // Static content - never changes
            Text("Get Started")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
        }
        .contentShape(Rectangle()) // Define tap area
        .onTapGesture {
            // Simple tap action - no button styling at all
            showingOnboarding = true
        }
    }
}

// Song Data Model with Codable support for persistence
struct Song: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var lyrics: String
    var imageName: String
    var customImageData: Data? // Store image as Data for persistence
    var additionalImagesData: [Data]? // Store additional images for multi-image analysis
    var useWaveformDesign: Bool = false
    var lastEdited: Date
    var associatedInstrumental: String? // Track which instrumental is loaded with this song
    
    // Custom initializer to ensure UUID is created only once
    init(title: String, lyrics: String, imageName: String, customImageData: Data? = nil, additionalImagesData: [Data]? = nil, useWaveformDesign: Bool = false, lastEdited: Date = Date(), associatedInstrumental: String? = nil, id: UUID = UUID()) {
        self.id = id
        self.title = title
        self.lyrics = lyrics
        self.imageName = imageName
        self.customImageData = customImageData
        self.additionalImagesData = additionalImagesData
        self.useWaveformDesign = useWaveformDesign
        self.lastEdited = lastEdited
        self.associatedInstrumental = associatedInstrumental
    }
    
    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: lastEdited)
    }
    
    // Computed property for UIImage (not persisted directly)
    var customImage: UIImage? {
        get {
            guard let data = customImageData else { return nil }
            return UIImage(data: data)
        }
        set {
            customImageData = newValue?.jpegData(compressionQuality: 0.7)
        }
    }
    
    // Computed property for additional images (not persisted directly)
    var additionalImages: [UIImage]? {
        get {
            guard let dataArray = additionalImagesData else { return nil }
            return dataArray.compactMap { UIImage(data: $0) }
        }
        set {
            additionalImagesData = newValue?.compactMap { $0.jpegData(compressionQuality: 0.7) }
        }
    }
    
    // All images combined (main + additional + asset images)
    var allImages: [UIImage] {
        var images: [UIImage] = []
        
        // Add custom image if available
        if let mainImage = customImage {
            images.append(mainImage)
        }
        // Add asset image if available and no custom image
        else if !imageName.isEmpty, let assetImage = UIImage(named: imageName) {
            images.append(assetImage)
        }
        
        // Add additional images
        if let additionalImages = additionalImages {
            images.append(contentsOf: additionalImages)
        }
        
        return images
    }
    
    // Custom coding keys to exclude computed properties from Codable
    enum CodingKeys: String, CodingKey {
        case id, title, lyrics, imageName, customImageData, additionalImagesData, useWaveformDesign, lastEdited, associatedInstrumental
    }
}

// Song Manager to handle app-wide song data with persistence
@MainActor
class SongManager: ObservableObject {
    @Published var songs: [Song] = []
    
    private let userDefaultsKey = "SavedSongs"
    private let imageIndexKey = "CurrentImageIndex"
    private let migrationKey = "RealThriftDataMigrationCompleted"
    
    // Available images for new songs (includes new + default images)
    private let availableImages = [
        "travis",      // New artist image
        "ecko",        // New artist image
        "coach",       // New artist image
        "mansion",     // New image
        "skyline",     // New image  
        "couple",      // New image
        "lambo",       // Existing
        "boy",         // Existing
        "girl"         // Existing
    ]
    
    private var currentImageIndex: Int {
        get {
            UserDefaults.standard.integer(forKey: imageIndexKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: imageIndexKey)
        }
    }
    
    init() {
        // DISABLED: This is an invoice app, not a thrift tracking app
        // Song/item tracking functionality has been disabled
        // DispatchQueue.main.async { [weak self] in
        //     self?.loadSongs()
        // }
        print("ℹ️ SongManager initialized (song loading disabled for invoice app)")
    }
    
    func updateSong(_ song: Song) {
        if let index = songs.firstIndex(where: { $0.id == song.id }) {
            // Remove the song from its current position
            songs.remove(at: index)
            // Insert it at the beginning to make it most recently edited
            songs.insert(song, at: 0)
            saveSongs()
            print("📝 Moved song '\(song.title)' to front of recently added list")
        }
    }
    
    // Update song properties without changing its position in the list
    func updateSongInPlace(_ song: Song) {
        if let index = songs.firstIndex(where: { $0.id == song.id }) {
            songs[index] = song
            saveSongs()
            print("📝 Updated song '\(song.title)' without moving position")
        }
    }
    
    func addSong(_ song: Song) {
        songs.insert(song, at: 0) // Add to beginning of list
        saveSongs()
    }
    
    func createNewSong() -> Song {
        // Get the next image in rotation
        let selectedImage = availableImages[currentImageIndex]
        
        // Move to next image for the next song
        currentImageIndex = (currentImageIndex + 1) % availableImages.count
        
        // Generate unique title
        let uniqueTitle = generateUniqueTitle()
        
        let newSong = Song(
            title: uniqueTitle,
            lyrics: "", // Start with empty lyrics - placeholder will show in UI
            imageName: selectedImage,
            useWaveformDesign: false, // Use actual images instead of waveform
            lastEdited: Date()
        )
        
        print("🎨 Created new song with title: '\(uniqueTitle)' and image: \(selectedImage)")
        addSong(newSong)
        return newSong
    }
    
    // Generate unique title with incrementing numbers
    private func generateUniqueTitle() -> String {
        let baseName = "Untitled Song"
        
        // Check if base name is available
        if !songs.contains(where: { $0.title == baseName }) {
            return baseName
        }
        
        // Find the highest number suffix in use
        var highestNumber = 0
        let basePattern = "\(baseName) ("
        
        for song in songs {
            if song.title.hasPrefix(basePattern) && song.title.hasSuffix(")") {
                let numberPart = song.title.dropFirst(basePattern.count).dropLast(1)
                if let number = Int(numberPart) {
                    highestNumber = max(highestNumber, number)
                }
            }
        }
        
        // Return the next available number
        let nextNumber = highestNumber + 1
        let uniqueTitle = "\(baseName) (\(nextNumber))"
        
        print("📝 Generated unique title: '\(uniqueTitle)' (highest existing: \(highestNumber))")
        return uniqueTitle
    }
    
    func deleteSong(_ song: Song) {
        songs.removeAll { $0.id == song.id }
        saveSongs()
    }
    
    func removeSong(_ song: Song) {
        songs.removeAll { $0.id == song.id }
        saveSongs()
        print("🗑️ Removed song '\(song.title)' from song manager")
        
        // Also remove associated profit data from UserDefaults
        UserDefaults.standard.removeObject(forKey: "avgPrice_\(song.id)")
        UserDefaults.standard.removeObject(forKey: "sellPrice_\(song.id)")
        UserDefaults.standard.removeObject(forKey: "profitOverride_\(song.id)")
        UserDefaults.standard.removeObject(forKey: "useCustomProfit_\(song.id)")
    }
    
    private func saveSongs() {
        if let encoded = try? JSONEncoder().encode(songs) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            print("💾 Saved \(songs.count) songs to UserDefaults")
        } else {
            print("❌ Failed to encode songs for saving")
        }
    }
    
    private func loadSongs() {
        // DISABLED: This is an invoice app, not a thrift tracking app
        // All song/thrift item tracking has been disabled
        print("ℹ️ loadSongs() called but disabled for invoice app")
        // Do not load or create any song data
        return
    }
    
    // Migrate existing sample songs to use new artist images
    private func migrateSampleSongsToNewImages() {
        // Check if migration has already been completed
        if UserDefaults.standard.bool(forKey: migrationKey) {
            return
        }
        
        let imageMapping = [
            "lambo": "travis",
            "boy": "ecko", 
            "girl": "coach"
        ]
        
        // Also handle title mapping for old sample songs
        let titleMapping = [
            "My Turn (Sample Song)": "Nike Air Jordan 1's - T-Scott",
            "IDGAF (Sample Song)": "Vintage Ecko Navy Blue Hoodie",
            "Deep Thoughts (Sample Song)": "Coach Vintage Handbag"
        ]
        
        var updated = false
        
        for i in 0..<songs.count {
            let currentSong = songs[i]
            
            // Check if this is an old sample song that needs migration
            if currentSong.title.contains("(Sample Song)") || 
               imageMapping.keys.contains(currentSong.imageName) {
                
                // Update image if needed
                if let newImageName = imageMapping[currentSong.imageName] {
                    songs[i].imageName = newImageName
                    updated = true
                }
                
                // Update title and content if it's an old sample song
                if let newTitle = titleMapping[currentSong.title] {
                    songs[i].title = newTitle
                    
                    // Set realistic dates for migrated songs
                    let calendar = Calendar.current
                    let now = Date()
                    
                    // Add realistic content and dates based on the new title
                    switch newTitle {
                    case "Nike Air Jordan 1's - T-Scott":
                        songs[i].lyrics = "🔥 FIND: Authentic 80s leather jacket\n💰 PRICE: $45 (Retail: $300+)\n📍 SOURCE: Local thrift store\n⭐ CONDITION: Excellent, minimal wear\n\n📝 NOTES:\n• Genuine leather, buttery soft\n• Classic moto style with zippers\n• Perfect for fall/winter\n• Checked comps - selling for $150+ online\n• Could flip for 3x profit easily\n\n🎯 WHY I BOUGHT IT:\nTimeless piece, great ROI potential, fits current trends"
                        songs[i].lastEdited = calendar.date(byAdding: .day, value: -3, to: now) ?? now
                    case "Vintage Ecko Navy Blue Hoodie":
                        songs[i].lyrics = "🔥 FIND: Jordan 4 White Cement (2016)\n💰 PRICE: $65 (Retail: $190, Resale: $180-250)\n📍 SOURCE: Goodwill\n⭐ CONDITION: 8/10, light creasing\n\n📝 NOTES:\n• Size 10.5 - popular size\n• OG all with box (missing lid)\n• Slight yellowing on midsole (normal)\n• No major flaws or scuffs\n• StockX verified authentic look-alikes\n\n🎯 WHY I BOUGHT IT:\nInstant profit, always in demand, classic colorway"
                        songs[i].lastEdited = calendar.date(byAdding: .day, value: -7, to: now) ?? now
                    case "Coach Vintage Handbag":
                        songs[i].lyrics = "🔥 FIND: Coach Legacy Shoulder Bag\n💰 PRICE: $12 (Retail: $298)\n📍 SOURCE: Estate sale\n⭐ CONDITION: 9/10, barely used\n\n📝 NOTES:\n• Authentic serial number verified\n• Black pebbled leather\n• Silver hardware, no tarnishing\n• Interior pristine, no stains\n• Dust bag included\n• Model 9966 - discontinued style\n\n🎯 WHY I BOUGHT IT:\nAuthentic Coach under $15 is always a buy. These sell for $80-120 online."
                        songs[i].lastEdited = calendar.date(byAdding: .day, value: -12, to: now) ?? now
                    default:
                        break
                    }
                    updated = true
                }
                
                print("🔄 Migrated sample: '\(currentSong.title)' to '\(songs[i].title)' with image '\(songs[i].imageName)'")
            }
        }
        
        if updated {
            saveSongs()
            print("✅ Sample songs migration completed with real thrift data")
        }
        
        // Mark migration as completed
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}

@MainActor
class StoreManager: ObservableObject {
    @Published private(set) var subscriptions: [Product] = []
    @Published private(set) var purchasedSubscriptions: [Product] = []
    @Published var isSubscribed = false
    
    private let productIds = [
        "com.thrifty.thrifty.unlimited.yearly149",        // Yearly subscription
        "com.thrifty.thrifty.unlimited.yearly.winback79"  // Yearly winback offer
    ]
    
    // Fallback product IDs (temporarily for testing while new products are pending approval)
    private let fallbackProductIds = [
        "com.thrifty.thrifty.unlimited.monthly",         // Monthly subscription (for testing)
        "com.thrifty.thrifty.unlimited.monthly.winback" // Monthly winback offer (for testing)
    ]
    
    init() {
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    func loadProducts() async {
        do {
            subscriptions = try await Product.products(for: productIds)
            print("✅ Successfully loaded \(subscriptions.count) products")
            for product in subscriptions {
                print("   - \(product.id): \(product.displayPrice)")
            }
            
            // Check if we got the expected number of products
            if subscriptions.count < productIds.count {
                print("⚠️ Missing products detected!")
                let loadedIds = subscriptions.map { $0.id }
                for productId in productIds {
                    if !loadedIds.contains(productId) {
                        print("❌ Missing product: \(productId)")
                    }
                }
                print("💡 Trying fallback product IDs for testing...")
                
                // Try fallback products since new ones aren't available
                do {
                    let fallbackProducts = try await Product.products(for: fallbackProductIds)
                    print("✅ Fallback products loaded successfully: \(fallbackProducts.count) products")
                    for product in fallbackProducts {
                        print("   - \(product.id): \(product.displayPrice)")
                    }
                    // Use fallback products if we got more products than with new IDs
                    if fallbackProducts.count > subscriptions.count {
                        subscriptions = fallbackProducts
                        print("⚠️ Using old product IDs temporarily until new ones are approved")
                    }
                } catch {
                    print("❌ Fallback products also failed:", error)
                }
            }
            
        } catch {
            print("❌ Failed to load products:", error)
            print("🔍 Attempting to load products with these IDs:")
            for productId in productIds {
                print("   - \(productId)")
            }
            
            // Try fallback products immediately if main load failed
            print("💡 Trying fallback product IDs...")
            do {
                subscriptions = try await Product.products(for: fallbackProductIds)
                print("✅ Fallback products loaded successfully: \(subscriptions.count) products")
                for product in subscriptions {
                    print("   - \(product.id): \(product.displayPrice)")
                }
                print("⚠️ Using old product IDs temporarily until new ones are approved")
            } catch {
                print("❌ Even fallback products failed:", error)
                print("💡 This usually means:")
                print("   1. Products are not yet approved in App Store Connect")
                print("   2. Products are not available in this region")
                print("   3. There's a configuration issue")
            }
        }
    }
    
    func updateSubscriptionStatus() async {
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.productID == productIds[0] {
                    isSubscribed = true
                    return
                }
            case .unverified:
                continue
            }
        }
        isSubscribed = false
    }
    
    func restorePurchases() async throws {
        try? await AppStore.sync()
        await updateSubscriptionStatus()
    }
}

enum StoreError: Error {
    case failedVerification
    case userCancelled
    case pending
    case unknown
}

struct SignInView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var showingPrivacyPolicy = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            ZStack {
                Text("Sign In")
                    .font(.system(size: 24, weight: .bold))
                    .frame(maxWidth: .infinity)
                
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16))
                            .foregroundColor(Color.gray.opacity(0.7))
                    }
                }
            }
            .padding(.top, 4)
            .padding(.horizontal, 24)
            
            Divider()
                .padding(.top, 16)
            
            // Sign in buttons
            VStack(spacing: 20) {
                // Sign in with Apple - Isolated button
                AppleSignInButton(authManager: authManager)
                
                // Google Sign In - RE-ENABLED with real CLIENT_ID
                GoogleSignInButton(authManager: authManager)
            }
            .padding(.top, 48)
            .padding(.horizontal, 24)
            
            // Terms text with original format and simplified tap detection
            TermsAndPrivacyText(showingPrivacyPolicy: $showingPrivacyPolicy)
                .padding(.top, 32)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
        .frame(maxHeight: UIScreen.main.bounds.height * 0.55)
        .background(Color.white)
        .cornerRadius(32, corners: [.topLeft, .topRight])
        .clipped() // Prevent any content from bleeding outside bounds
        .onChange(of: authManager.isLoggedIn) { isLoggedIn in
            if isLoggedIn {
                dismiss()
            }
        }
        .alert("Authentication Error", isPresented: .constant(authManager.errorMessage != nil)) {
            Button("OK") {
                authManager.errorMessage = nil
            }
        } message: {
            Text(authManager.errorMessage ?? "")
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
                .presentationDetents([.height(UIScreen.main.bounds.height * 0.8)])
                .presentationDragIndicator(.visible)
        }
    }
}

// Terms and Privacy Text Component - Separated to avoid compilation issues
struct TermsAndPrivacyText: View {
    @Binding var showingPrivacyPolicy: Bool
    @State private var showingTermsOfService = false
    
    var body: some View {
        VStack(spacing: 0) {
            termsText
                .multilineTextAlignment(.center)
        }
    }
    
    private var termsText: some View {
        VStack(spacing: 2) {
            Text("By continuing you agree to Thrifty's")
                .font(.system(size: 12))
                .foregroundColor(.black)
            
            HStack(spacing: 0) {
                Text("Terms of Service")
                    .font(.system(size: 12))
                    .foregroundColor(.black)
                    .underline(color: .black)
                    .onTapGesture {
                        print("✅ Opening Thrifty Terms of Service")
                        showingTermsOfService = true
                    }
                
                Text(" and ")
                    .font(.system(size: 12))
                    .foregroundColor(.black)
                
                Text("Privacy Policy")
                    .font(.system(size: 12))
                    .foregroundColor(.black)
                    .underline(color: .black)
                    .onTapGesture {
                        print("✅ Privacy Policy tapped directly")
                        showingPrivacyPolicy = true
                    }
            }
        }
        .sheet(isPresented: $showingTermsOfService) {
            TermsOfServiceView()
                .presentationDetents([.height(UIScreen.main.bounds.height * 0.8)])
                .presentationDragIndicator(.visible)
        }
    }

}

// Terms of Service View
struct TermsOfServiceView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    contentSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("Terms of Service")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 20)
            
            Text("Last updated: July 23, 2025")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            introductionText
            serviceTermsSection
            userObligationsSection
            intellectualPropertySection
            disclaimerSection
            contactSection
        }
    }
    
    private var introductionText: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome to Thrifty. These Terms of Service govern your use of our application and services.")
                .font(.system(size: 16))
                .foregroundColor(.black)
            
            Text("By using our Service, you agree to be bound by these Terms. If you disagree with any part of these terms, then you may not access the Service.")
                .font(.system(size: 16))
                .foregroundColor(.black)
        }
    }
    
    private var serviceTermsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Service Description")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
                .padding(.top, 10)
            
            Text("Thrifty provides an AI-powered item scanning platform that helps users identify and evaluate thrift store items using artificial intelligence technology.")
                .font(.system(size: 16))
                .foregroundColor(.black)
            
            Text("Our services include but are not limited to:")
                .font(.system(size: 16))
                .foregroundColor(.black)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• AI-powered item identification and analysis")
                Text("• Price estimation and market value assessment")
                Text("• Brand and product recognition technology")
                Text("• Unlimited item scanning capabilities")
                Text("• Thrift store item evaluation tools")
            }
            .font(.system(size: 16))
            .foregroundColor(.black)
        }
    }
    
    private var userObligationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("User Obligations")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
                .padding(.top, 10)
            
            Text("You agree to use our Service responsibly and in accordance with these terms:")
                .font(.system(size: 16))
                .foregroundColor(.black)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Use the Service only for lawful purposes")
                Text("• Respect intellectual property rights")
                Text("• Provide accurate information when required")
                Text("• Maintain the security of your account")
                Text("• Report any bugs or security issues")
            }
            .font(.system(size: 16))
            .foregroundColor(.black)
        }
    }
    
    private var intellectualPropertySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Intellectual Property")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
                .padding(.top, 10)
            
            Text("User-Generated Content")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
            
            Text("You retain ownership of any images and content you upload to our Service. However, you grant us a limited license to process and analyze your content to provide item identification, pricing analysis, and improve our services.")
                .font(.system(size: 16))
                .foregroundColor(.black)
            
            Text("Our Technology")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
                .padding(.top, 10)
            
            Text("All technology, software, and AI models used in our Service remain the exclusive property of Thrifty and are protected by copyright and other intellectual property laws.")
                .font(.system(size: 16))
                .foregroundColor(.black)
        }
    }
    
    private var disclaimerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Disclaimer")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
                .padding(.top, 10)
            
            Text("Our Service is provided \"as is\" without warranties of any kind. We strive to provide accurate and helpful AI-generated item analysis, but cannot guarantee the absolute accuracy of price estimates, brand identification, or market value assessments.")
                .font(.system(size: 16))
                .foregroundColor(.black)
            
            Text("Limitation of Liability")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
                .padding(.top, 10)
            
            Text("In no event shall Thrifty be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of the Service.")
                .font(.system(size: 16))
                .foregroundColor(.black)
        }
    }
    
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Contact Information")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
                .padding(.top, 10)
            
            Text("If you have any questions about these Terms of Service, please contact us:")
                .font(.system(size: 16))
                .foregroundColor(.black)
            
            Text(NSLocalizedString("📧 By email: helpthrifty@gmail.com", comment: ""))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
        }
    }
}

// Privacy Policy View - Updated with exact content
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    contentSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 10) {
            Text("Privacy Policy")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 20)
            
            Text("Last updated: July 23, 2025")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            introductionText
            interpretationAndDefinitionsSection
            collectingAndUsingDataSection
            
            Group {
                retentionSection
                transferSection
                deleteDataSection
                disclosureSection
                securitySection
            }
            
            Group {
                childrenPrivacySection
                linksSection
                changesSection
            contactSection
            }
        }
    }
    
    private var introductionText: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Privacy Policy describes Our policies and procedures on the collection, use and disclosure of Your information when You use the Service and tells You about Your privacy rights and how the law protects You.")
                .font(.system(size: 16))
                .foregroundColor(.black)
            
            Text("We use Your Personal data to provide and improve the Service. By using the Service, You agree to the collection and use of information in accordance with this Privacy Policy.")
                .font(.system(size: 16))
                .foregroundColor(.black)
        }
    }
    
    private var interpretationAndDefinitionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Interpretation and Definitions")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
                .padding(.top, 10)
            
            Text("Interpretation")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
            
            Text("The words of which the initial letter is capitalized have meanings defined under the following conditions. The following definitions shall have the same meaning regardless of whether they appear in singular or in plural.")
                .font(.system(size: 16))
                .foregroundColor(.black)
            
            Text("Definitions")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
                .padding(.top, 8)
            
            Text("For the purposes of this Privacy Policy:")
                .font(.system(size: 16))
                .foregroundColor(.black)
            
            VStack(alignment: .leading, spacing: 8) {
            Group {
                Text("Account means a unique account created for You to access our Service or parts of our Service.")
                    Text("Affiliate means an entity that controls, is controlled by or is under common control with a party...")
                Text("Application refers to any application or software program provided by the Company, including but not limited to thrifty.ai, and any other applications or software programs provided by the Company.")
                Text("Company (referred to as either \"the Company\", \"We\", \"Us\" or \"Our\" in this Agreement) refers to Totally Science, 60 Heather Drive.")
                Text("Country refers to: New York, United States")
                }
                
                Group {
                    Text("Device means any device that can access the Service...")
                Text("Personal Data is any information that relates to an identified or identifiable individual.")
                Text("Service refers to the Application.")
                    Text("Service Provider means any natural or legal person who processes the data on behalf of the Company.")
                    Text("Usage Data refers to data collected automatically...")
                Text("You means the individual accessing or using the Service...")
                }
            }
            .font(.system(size: 16))
            .foregroundColor(.black)
        }
    }
    
    private var collectingAndUsingDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Collecting and Using Your Personal Data")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
                .padding(.top, 20)
            
            Group {
                Text("Types of Data Collected")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                
                Text("Personal Data")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                
                Text("While using Our Service, We may ask You to provide Us with certain personally identifiable information...")
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                
                Text("Usage Data")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.top, 8)
                
                Text("Usage Data is collected automatically when using the Service...")
                    .font(.system(size: 16))
                    .foregroundColor(.black)
            }
            
            Group {
                Text("Use of Your Personal Data")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.top, 12)
                
                Text("The Company may use Personal Data for the following purposes:")
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("To provide and maintain our Service")
                    Text("To manage Your Account")
                    Text("For the performance of a contract")
                    Text("To contact You")
                    Text("To provide You with news, special offers...")
                    Text("To manage Your requests")
                    Text("For business transfers")
                    Text("For other purposes...")
                }
                .font(.system(size: 16))
                .foregroundColor(.black)
                .padding(.leading, 16)
            }
            
            Group {
            Text("Creative Data")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
                    .padding(.top, 12)
            
            Text("We may process users' lyric drafts and generation history to improve user experience and help users refine their songwriting process more effectively.")
                .font(.system(size: 16))
                .foregroundColor(.black)
            
            Text("All creative data is processed on the device and is not stored on our servers. You may delete your lyric data at any time.")
                .font(.system(size: 16))
                .foregroundColor(.black)
            }
        }
    }
    
    private var retentionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Retention of Your Personal Data")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
                .padding(.top, 10)
            
            Text("The Company will retain Your Personal Data only for as long as is necessary for the purposes set out in this Privacy Policy. We will retain and use Your Personal Data to the extent necessary to:")
                .font(.system(size: 16))
                .foregroundColor(.black)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("comply with our legal obligations (for example, if we are required to retain your data to comply with applicable laws),")
                Text("resolve disputes, and")
                Text("enforce our legal agreements and policies.")
            }
            .font(.system(size: 16))
            .foregroundColor(.black)
            .padding(.leading, 16)
            
            Text("We also retain Usage Data for internal analysis purposes. Usage Data is generally retained for a shorter period, except when this data is used to strengthen the security or to improve the functionality of Our Service, or We are legally obligated to retain this data for longer periods.")
                .font(.system(size: 16))
                .foregroundColor(.black)
        }
    }
    
    private var transferSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transfer of Your Personal Data")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
                .padding(.top, 10)
            
            Text("Your information, including Personal Data, may be transferred to — and maintained on — computers located outside of Your state, province, country or other governmental jurisdiction where the data protection laws may differ from those in Your jurisdiction.")
                .font(.system(size: 16))
                .foregroundColor(.black)
            
            Text("Your consent to this Privacy Policy followed by Your submission of such information represents Your agreement to that transfer.")
                .font(.system(size: 16))
                .foregroundColor(.black)
            
            Text("The Company will take all steps reasonably necessary to ensure that Your data is treated securely and in accordance with this Privacy Policy, and no transfer of Your Personal Data will take place to an organization or a country unless there are adequate controls in place, including the security of Your data and other personal information.")
                .font(.system(size: 16))
                .foregroundColor(.black)
        }
    }
    
    private var deleteDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Delete Your Personal Data")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
                .padding(.top, 10)
            
            Text("You have the right to delete or request that We assist in deleting the Personal Data...")
                .font(.system(size: 16))
                .foregroundColor(.black)
        }
    }
    
    private var disclosureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Disclosure of Your Personal Data")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
                .padding(.top, 10)
            
            Text("Business Transactions")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
            
            Text("Law enforcement")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
            
            Text("Other legal requirements")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
        }
    }
    
    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Security of Your Personal Data")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
                .padding(.top, 10)
            
            Text("The security of Your Personal Data is important to Us...")
                .font(.system(size: 16))
                .foregroundColor(.black)
        }
    }
    
    private var childrenPrivacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Children's Privacy")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
                .padding(.top, 10)
            
            Text("Our Service does not address anyone under the age of 13...")
                .font(.system(size: 16))
                .foregroundColor(.black)
        }
    }
    
    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Links to Other Websites")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
                .padding(.top, 10)
            
            Text("Our Service may contain links to other websites that are not operated by Us...")
                .font(.system(size: 16))
                .foregroundColor(.black)
        }
    }
    
    private var changesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Changes to this Privacy Policy")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
                .padding(.top, 10)
            
            Text("We may update Our Privacy Policy from time to time...")
                .font(.system(size: 16))
                .foregroundColor(.black)
        }
    }
    
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Contact Us")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
                .padding(.top, 10)
            
            Text("If you have any questions about this Privacy Policy, You can contact us:")
                .font(.system(size: 16))
                .foregroundColor(.black)
            
            Text(NSLocalizedString("📧 By email: helpthrifty@gmail.com", comment: ""))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
        }
    }
}

// Instrumental Card Component
class GlobalLoopSettings: ObservableObject {
    static let shared = GlobalLoopSettings()
    
    @Published var hasPendingLoop: Bool = false
    @Published var pendingLoopStart: TimeInterval = 0
    @Published var pendingLoopEnd: TimeInterval = 0
    
    private init() {}
    
    func setPendingLoop(start: TimeInterval, end: TimeInterval) {
        hasPendingLoop = true
        pendingLoopStart = start
        pendingLoopEnd = end
        print("🔄 Set pending loop: \(formatTime(start)) to \(formatTime(end))")
    }
    
    func clearPendingLoop() {
        hasPendingLoop = false
        pendingLoopStart = 0
        pendingLoopEnd = 0
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Global Audio Manager for coordinating all audio playback
@MainActor
class GlobalAudioManager: ObservableObject {
    static let shared = GlobalAudioManager()
    
    @Published var currentPlayingManager: AudioManager?
    
    private init() {}
    
    func playAudio(_ manager: AudioManager) {
        // Stop any currently playing audio
        if let currentManager = currentPlayingManager, currentManager != manager {
            currentManager.pause()
        }
        
        // Set the new manager as current
        currentPlayingManager = manager
    }
}

// Audio Manager for handling audio playback and controls
@MainActor
class AudioManager: ObservableObject, Equatable {
    @Published var player: AVAudioPlayer?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isLooping = false
    @Published var loopStart: TimeInterval = 0
    @Published var loopEnd: TimeInterval = 0
    @Published var hasCustomLoop = false
    @Published var audioFileName: String = ""
    
    private var timer: Timer?
    
    init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            print("🔊 Audio session configured successfully")
        } catch {
            print("❌ Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    static func == (lhs: AudioManager, rhs: AudioManager) -> Bool {
        return lhs === rhs
    }
    
    func loadAudio(from url: URL) {
        do {
            // Preserve current loop settings before loading
            let wasCustomLoop = hasCustomLoop
            let savedLoopStart = loopStart
            let savedLoopEnd = loopEnd
            
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            duration = player?.duration ?? 0
            audioFileName = url.lastPathComponent
            
            // Check if there are pending loop settings from the UI
            if GlobalLoopSettings.shared.hasPendingLoop {
                hasCustomLoop = true
                loopStart = GlobalLoopSettings.shared.pendingLoopStart
                loopEnd = min(GlobalLoopSettings.shared.pendingLoopEnd, duration)
                print("✅ Applied pending loop settings: \(formatTime(loopStart)) to \(formatTime(loopEnd))")
            } else {
                // Restore loop settings if they were set
                if wasCustomLoop {
                    hasCustomLoop = true
                    loopStart = savedLoopStart
                    loopEnd = min(savedLoopEnd, duration) // Ensure loop end doesn't exceed duration
                    print("🔄 Restored loop settings: \(formatTime(loopStart)) to \(formatTime(loopEnd))")
                } else {
            resetLoop()
                }
            }
        } catch {
            print("Failed to load audio: \(error)")
        }
    }
    
    func play() {
        guard let player = player else { return }
        
        print("🎵 Play called for: \(audioFileName)")
        print("🎵 hasCustomLoop: \(hasCustomLoop)")
        print("🎵 loopStart: \(formatTime(loopStart))")
        print("🎵 loopEnd: \(formatTime(loopEnd))")
        
        // Notify global manager to stop other audio
        GlobalAudioManager.shared.playAudio(self)
        
        // Handle custom loop settings when starting playback
        if hasCustomLoop {
            // Always start from loop start when custom loop is enabled
            player.currentTime = loopStart
            currentTime = loopStart
            print("✅ Starting playback at loop start: \(formatTime(loopStart))")
        } else {
            print("ℹ️ No custom loop, starting from current position")
        }
        
        player.play()
        isPlaying = true
        startTimer()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func stop() {
        player?.stop()
        player?.currentTime = 0
        currentTime = 0
        isPlaying = false
        stopTimer()
    }
    
    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }
    
    func toggleLoop() {
        isLooping.toggle()
        player?.numberOfLoops = isLooping ? -1 : 0
    }
    
    func setCustomLoop(start: TimeInterval, end: TimeInterval) {
        loopStart = start
        loopEnd = end
        hasCustomLoop = true
    }
    
    func resetLoop() {
        hasCustomLoop = false
        loopStart = 0
        loopEnd = duration
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                guard let player = self.player else { return }
                self.currentTime = player.currentTime
                
                // Handle custom loop
                if self.hasCustomLoop && self.currentTime >= self.loopEnd {
                    player.currentTime = self.loopStart
                    self.currentTime = self.loopStart
                }
                
                // Check if song ended
                if !player.isPlaying && self.isPlaying {
                    self.isPlaying = false
                    self.stopTimer()
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Shared Instrumental Manager with persistence
@MainActor
class SharedInstrumentalManager: ObservableObject {
    static let shared = SharedInstrumentalManager()
    
    @Published var instrumentals: [String] = []
    @Published var audioManagers: [String: AudioManager] = [:]
    
    private let userDefaultsKey = "SavedInstrumentals"
    private let defaultInstrumentals = [
        "10AM In The South.mp3",
        "Better Mornings.mp3", 
        "Pleasent Poetry.mp3",
        "Run It Up.mp3",
        "Yacht Parties.mp3"
    ]
    
    private init() {
        loadInstrumentals()
        initializeAudioManagers()
    }
    
    func addInstrumental(_ fileName: String, url: URL) {
        print("📥 Adding instrumental: \(fileName) from URL: \(url)")
        
        if !instrumentals.contains(fileName) {
            instrumentals.insert(fileName, at: 0)
            
            // Copy file to app's documents directory for permanent access
            if let permanentURL = copyToDocuments(file: url, fileName: fileName) {
            let newAudioManager = AudioManager()
                newAudioManager.loadAudio(from: permanentURL)
            audioManagers[fileName] = newAudioManager
                
                print("✅ Added instrumental to list and created audio manager")
                print("🎵 Audio manager has player: \(newAudioManager.player != nil)")
                print("⏱️ Duration: \(newAudioManager.duration)")
                print("📁 Copied to: \(permanentURL)")
            } else {
                print("❌ Failed to copy file to documents directory")
                // Remove from list if copy failed
                instrumentals.removeFirst()
                return
            }
            
            saveInstrumentals()
        } else {
            print("⚠️ Instrumental already exists: \(fileName)")
        }
    }
    
    // Copy file to app's documents directory for permanent access
    private func copyToDocuments(file sourceURL: URL, fileName: String) -> URL? {
        guard sourceURL.startAccessingSecurityScopedResource() else {
            print("❌ Failed to access security scoped resource")
            return nil
        }
        
        defer {
            sourceURL.stopAccessingSecurityScopedResource()
        }
        
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destinationURL = documentsPath.appendingPathComponent(fileName)
            
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Copy the file
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            print("✅ Copied \(fileName) to documents directory")
            return destinationURL
        } catch {
            print("❌ Failed to copy file: \(error)")
            return nil
        }
    }
    
    func removeInstrumental(_ fileName: String) {
        if let index = instrumentals.firstIndex(of: fileName) {
            instrumentals.remove(at: index)
            audioManagers.removeValue(forKey: fileName)
            
            // Also remove file from documents directory if it exists
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent(fileName)
            
            do {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                    print("✅ Removed file from documents: \(fileName)")
                }
            } catch {
                print("⚠️ Failed to remove file from documents: \(error)")
            }
            
            saveInstrumentals()
        }
    }
    
    func getAudioManager(for instrumental: String) -> AudioManager {
        if let existingManager = audioManagers[instrumental] {
            // Check if existing manager has a player, if not, try to reload
            if existingManager.player == nil {
                print("🔄 Audio manager exists but no player, attempting to reload: \(instrumental)")
                loadAudioForManager(existingManager, instrumental: instrumental)
            }
            return existingManager
        } else {
            print("🔄 Creating new audio manager for missing instrumental: \(instrumental)")
            let newManager = AudioManager()
            loadAudioForManager(newManager, instrumental: instrumental)
            audioManagers[instrumental] = newManager
            return newManager
        }
    }
    
    // Helper function to load audio into a manager
    private func loadAudioForManager(_ manager: AudioManager, instrumental: String) {
        // Try to load from bundle first (for default instrumentals)
        let fileNameWithoutExtension = instrumental.replacingOccurrences(of: ".mp3", with: "").replacingOccurrences(of: ".wav", with: "").replacingOccurrences(of: ".m4a", with: "")
        if let url = Bundle.main.url(forResource: fileNameWithoutExtension, withExtension: "mp3") {
            manager.loadAudio(from: url)
            print("✅ Loaded default instrumental from bundle: \(instrumental)")
        } else {
            // Try to load from documents directory (for user-uploaded files)
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent(instrumental)
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                manager.loadAudio(from: fileURL)
                print("✅ Loaded user instrumental from documents: \(instrumental)")
            } else {
                print("⚠️ Could not find instrumental file: \(instrumental)")
            }
        }
    }
    
    private func saveInstrumentals() {
        if let encoded = try? JSONEncoder().encode(instrumentals) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            print("💾 Saved \(instrumentals.count) instrumentals to UserDefaults")
        } else {
            print("❌ Failed to encode instrumentals for saving")
        }
    }
    
    private func loadInstrumentals() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            instrumentals = decoded
            print("🎵 Loaded \(instrumentals.count) instrumentals from UserDefaults")
            print("🎵 Instrumentals list: \(instrumentals)")
            
            // Remove unwanted default instrumentals
            if let freestyleIndex = instrumentals.firstIndex(where: { $0.contains("3KFreestyle") }) {
                let freestyleFile = instrumentals[freestyleIndex]
                print("🗑️ Removing unwanted default instrumental: \(freestyleFile)")
                instrumentals.remove(at: freestyleIndex)
                saveInstrumentals()
            }
            
            // Debug: Check for problematic LoBo file
            if let loboIndex = instrumentals.firstIndex(where: { $0.contains("LoBo") }) {
                let loboFile = instrumentals[loboIndex]
                print("🚨 Found LoBo file in instrumentals: \(loboFile)")
                print("🚨 Removing it to fix persistent error...")
                instrumentals.remove(at: loboIndex)
                saveInstrumentals()
            }
        } else {
            // First time - use default instrumentals
            instrumentals = defaultInstrumentals
            saveInstrumentals()
            print("🎵 Created initial default instrumentals")
        }
    }
    
    private func initializeAudioManagers() {
        // Initialize audio managers for all instrumentals
        for instrumental in instrumentals {
            let newAudioManager = AudioManager()
            
            // Try to load from bundle first (for default instrumentals)
            if let url = Bundle.main.url(forResource: instrumental.replacingOccurrences(of: ".mp3", with: ""), withExtension: "mp3") {
                newAudioManager.loadAudio(from: url)
            }
            // Note: User-added instrumentals will need to be re-added after app restart
            // This is a limitation of the file system access in iOS
            
            audioManagers[instrumental] = newAudioManager
        }
    }
}

// Instrumentals View - Audio upload and playback interface
struct SettingsView: View {
    @ObservedObject var audioManager: AudioManager
    @State private var showingFilePicker = false
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero
    @StateObject private var sharedManager = SharedInstrumentalManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with background image like homepage and lyric tools
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Instrumentals")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    // Browse Files button
                    Button(action: { showingFilePicker = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                            Text("Browse Files")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Image("tool-bg1")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        )
                        .clipShape(
                        RoundedCorner(radius: 16, corners: [.topLeft, .topRight, .bottomLeft, .bottomRight])
                    )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 20)
            }
            .background(Color.black)  // Simple black background
            
            // Main content area with proper spacing
            VStack(spacing: 0) {
                // Instrumentals list with bottom padding to prevent cutoff
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sharedManager.instrumentals, id: \.self) { instrumental in
                            InstrumentalListItem(
                                title: instrumental,
                                audioManager: sharedManager.getAudioManager(for: instrumental),
                                onDelete: {
                                    sharedManager.removeInstrumental(instrumental)
                                }
                            )
                        }
                    }
                    .padding(.bottom, 120)
                }
                .padding(.top, 20)
                
                Spacer()
            }
            
            // Fixed bottom section with loop controls
            VStack(spacing: 16) {
                // Loop controls - always visible
                LoopControlsView()
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 50)
            .padding(.top, 8)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.9),
                        Color.black
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .background(Color.black)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingFilePicker) {
            AudioFilePicker { url in
                print("🎵 Loading audio from: \(url)")
                
                // Add the file to the shared manager
                let fileName = url.lastPathComponent
                sharedManager.addInstrumental(fileName, url: url)
            }
        }
    }
}

// Audio File Picker
struct AudioFilePicker: UIViewControllerRepresentable {
    let onFilePicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onFilePicked: onFilePicked)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onFilePicked: (URL) -> Void
        
        init(onFilePicked: @escaping (URL) -> Void) {
            self.onFilePicked = onFilePicked
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onFilePicked(url)
        }
    }
}

struct InstrumentalCard: View {
    let title: String
    let imageName: String
    let genres: String
    let playCount: String
    let likeCount: String
    let commentCount: String
    
    // Get audio manager from shared manager
    @ObservedObject private var audioManager: AudioManager
    
    init(title: String, imageName: String, genres: String, playCount: String, likeCount: String, commentCount: String) {
        self.title = title
        self.imageName = imageName
        self.genres = genres
        self.playCount = playCount
        self.likeCount = likeCount
        self.commentCount = commentCount
        
        // Get the audio manager from shared manager
        // title already includes .mp3 extension, so use it directly
        self.audioManager = SharedInstrumentalManager.shared.getAudioManager(for: title)
    }
    
    // Create audio data for this instrumental
    private var audioFileName: String {
        return title // title already includes .mp3 extension
    }
    
    // Display title without .mp3 extension
    private var displayTitle: String {
        return title.replacingOccurrences(of: ".mp3", with: "")
    }
    
    private var audioDuration: TimeInterval {
        return audioManager.duration
    }
    
    private var audioCurrentTime: TimeInterval {
        return audioManager.currentTime
    }
    
    private var progressPercentage: Double {
        return audioDuration > 0 ? audioCurrentTime / audioDuration : 0.0
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Container for artwork and gradient
            ZStack {
                // Square artwork as background
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 180, height: 180) // Made image even larger
                    .clipped()
                    .clipShape(
                        RoundedCorner(radius: 16, corners: [.topLeft, .topRight, .bottomLeft, .bottomRight])
                    )
            }
            
            // Compact Audio Player below the image
            instrumentalAudioPlayer
                .padding(.horizontal, 12)
        }
    }
    
    private var instrumentalAudioPlayer: some View {
        VStack(spacing: 8) {
            // Top row: File info and play button
            HStack(spacing: 8) {
                // Waveform icon
                Image(systemName: "waveform")
                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white.opacity(0.1))
                    )
                
                // File name and time - smaller text
                VStack(alignment: .leading, spacing: 1) {
                    Text(displayTitle)
                        .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("\(formatTime(audioCurrentTime)) / \(formatTime(audioDuration))")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Play button
                Button(action: {
                    if audioManager.isPlaying {
                        audioManager.pause()
                    } else {
                        // Try to load from bundle first (for default files)
                        let fileNameWithoutExtension = title.replacingOccurrences(of: ".mp3", with: "")
                        if let url = Bundle.main.url(forResource: fileNameWithoutExtension, withExtension: "mp3") {
                            audioManager.loadAudio(from: url)
                            audioManager.play()
                        } else {
                            // If not in bundle, the audio manager should already have the file loaded
                            // Just play it if it has a player
                            if audioManager.player != nil {
                        audioManager.play()
                            }
                        }
                    }
                }) {
                    Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12))
                                    .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.white.opacity(0.1))
                        )
                }
            }
            
            // Simple progress line without markers
            GeometryReader { geometry in
                ZStack {
                    // Background line
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.white.opacity(0.2))
                        .frame(height: 4)
                    
                    // Progress line
                    HStack {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(hex: "#8B5CF6"),
                                        Color(hex: "#EC4899")
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progressPercentage, height: 4)
                        
                        Spacer()
                    }
                }
            }
            .frame(height: 20)
        }
        .padding(8)
                    .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.clear)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Instrumental List Item Component
struct InstrumentalListItem: View {
    let title: String
    @ObservedObject var audioManager: AudioManager
    let onDelete: () -> Void
    @State private var offset: CGFloat = 0
    @State private var isSwiped = false
    @State private var isDragging = false
    
    private var progressPercentage: Double {
        return audioManager.duration > 0 ? audioManager.currentTime / audioManager.duration : 0.0
    }
    
    var body: some View {
        ZStack {
            // Delete button background
            HStack {
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black)
                        .cornerRadius(8)
                }
            }
            .padding(.trailing, 16)
            
            // Main content
            VStack(spacing: 12) {
                // Top row with track info and play button
                HStack(spacing: 12) {
                    // Waveform icon
                    Image(systemName: "waveform")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                    
                    // Track info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text("\(formatTime(audioManager.currentTime)) / \(formatTime(audioManager.duration))")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Play button
                    Button(action: {
                        if audioManager.isPlaying {
                            audioManager.pause()
                        } else {
                            // Try to load from bundle first (for default files)
                            if let url = Bundle.main.url(forResource: title.replacingOccurrences(of: ".mp3", with: ""), withExtension: "mp3") {
                                audioManager.loadAudio(from: url)
                                audioManager.play()
                            } else {
                                // If not in bundle, the audio manager should already have the file loaded
                                // Just play it if it has a player
                                if audioManager.player != nil {
                                    audioManager.play()
                                }
                            }
                        }
                    }) {
                        Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(4)
                    }
                }
                
                // Scrubber line with drag gesture
                GeometryReader { geometry in
                    ZStack {
                        // Background line
                        RoundedRectangle(cornerRadius: 1)
                            .fill(.white.opacity(0.2))
                            .frame(height: 4)
                        
                        // Progress line
                        HStack {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(hex: "#8B5CF6"),
                                            Color(hex: "#EC4899")
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progressPercentage, height: 4)
                            
                            Spacer()
                        }
                    }
                    .frame(height: 20)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                let percentage = min(max(value.location.x / geometry.size.width, 0), 1)
                                let time = audioManager.duration * percentage
                                audioManager.seek(to: time)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.black)
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 && !isDragging {
                            offset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        if !isDragging {
                            withAnimation(.spring()) {
                                if value.translation.width < -50 {
                                    offset = -60
                                    isSwiped = true
                                } else {
                                    offset = 0
                                    isSwiped = false
                                }
                            }
                        }
                    }
            )
            .onTapGesture {
                if !isDragging {
                    withAnimation(.spring()) {
                        offset = 0
                        isSwiped = false
                    }
                }
            }
        }
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
                .offset(y: 60),
            alignment: .bottom
        )
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// Loop Controls View
struct LoopControlsView: View {
    @StateObject private var globalAudioManager = GlobalAudioManager.shared
    @StateObject private var sharedManager = SharedInstrumentalManager.shared
    @StateObject private var globalLoopSettings = GlobalLoopSettings.shared
    @State private var startTimeText: String = "0:00"
    @State private var endTimeText: String = "0:00"
    @State private var isEditingStart: Bool = false
    @State private var isEditingEnd: Bool = false
    @State private var isLoopSaved: Bool = false
    @State private var currentManager: AudioManager?
    
    // Get the currently playing manager or apply settings to the song that's about to be played
    private func getCurrentManager() -> AudioManager {
        if let playingManager = globalAudioManager.currentPlayingManager {
            return playingManager
        } else {
            // If no song is playing, we'll apply the loop settings to whatever song gets played next
            // For now, return a temporary manager for UI purposes
            let tempManager = AudioManager()
            return tempManager
        }
    }
    
    // Apply loop settings to a specific manager
    private func applyLoopSettings(to manager: AudioManager) {
        if let startTime = parseTimeString(startTimeText),
           let endTime = parseTimeString(endTimeText),
           startTime < endTime {
            manager.hasCustomLoop = true
            manager.loopStart = startTime
            manager.loopEnd = min(endTime, manager.duration)
            print("✅ Applied loop settings to \(manager.audioFileName): \(formatTime(startTime)) to \(formatTime(endTime))")
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Start time
            VStack(alignment: .leading, spacing: 4) {
                Text("START")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
                
                HStack {
                    TimePickerButton(text: $startTimeText) { newValue in
                        startTimeText = newValue
                        updateStartTime()
                    }
                    
                    Button(action: { 
                        let manager = getCurrentManager()
                        manager.loopStart = manager.currentTime
                        startTimeText = formatTime(manager.loopStart)
                    }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(6)
            }
            
            // End time
            VStack(alignment: .leading, spacing: 4) {
                Text("END")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
                
                HStack {
                    TimePickerButton(text: $endTimeText) { newValue in
                        endTimeText = newValue
                        updateEndTime()
                    }
                    
                    Button(action: { 
                        let manager = getCurrentManager()
                        manager.loopEnd = manager.currentTime
                        manager.hasCustomLoop = true
                        endTimeText = formatTime(manager.loopEnd)
                    }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(6)
            }
            
            // Save/Stop Loop Button
            VStack(alignment: .leading, spacing: 4) {
                Text("LOOP")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
                
                Button(action: {
                    if isLoopSaved {
                        // Just disable the loop without resetting timestamps
                        globalLoopSettings.clearPendingLoop()
                        if let playingManager = globalAudioManager.currentPlayingManager {
                            playingManager.hasCustomLoop = false
                        }
                        isLoopSaved = false
                    } else {
                        // Save loop
                        saveLoop()
                        isLoopSaved = globalLoopSettings.hasPendingLoop
                    }
                }) {
                    Text(isLoopSaved ? "STOP LOOP" : "SET LOOP")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(
                            Image("tool-bg1")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        )
                        .cornerRadius(6)
                }
            }
        }
        .padding(12)
        .padding(.bottom, 12) // Add extra bottom padding
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
        .onAppear {
            // Initialize with global loop settings if available
            if globalLoopSettings.hasPendingLoop {
                startTimeText = formatTime(globalLoopSettings.pendingLoopStart)
                endTimeText = formatTime(globalLoopSettings.pendingLoopEnd)
                isLoopSaved = true
            } else {
                startTimeText = "0:00"
                endTimeText = "0:00"
                isLoopSaved = false
            }
        }
        .onChange(of: globalLoopSettings.hasPendingLoop) { hasLoop in
            isLoopSaved = hasLoop
        }
    }
    
    private func updateStartTime() {
        let manager = getCurrentManager()
        if let time = parseTimeString(startTimeText) {
            // Ensure start time is less than end time
            if manager.loopEnd > 0 && time >= manager.loopEnd {
                // If start time is greater than or equal to end time, adjust end time
                manager.loopEnd = min(time + 10, manager.duration) // Set to 10 seconds after start
                endTimeText = formatTime(manager.loopEnd)
            }
            
            manager.loopStart = time
        } else {
            startTimeText = formatTime(manager.loopStart)
        }
    }
    
    private func updateEndTime() {
        let manager = getCurrentManager()
        if let time = parseTimeString(endTimeText) {
            // Check if end time is too close to start time (2 seconds or less)
            if time <= manager.loopStart + 2 {
                // If end time is too close to start time, set it to 10 seconds after start
                let newEndTime = min(manager.loopStart + 10, manager.duration)
                manager.loopEnd = newEndTime
                endTimeText = formatTime(newEndTime)
                print("🔄 Auto-adjusted END time to 10 seconds after START: \(formatTime(newEndTime))")
            } else {
                manager.loopEnd = time
            }
        } else {
            endTimeText = formatTime(manager.loopEnd)
        }
    }
    
    private func saveLoop() {
        print("🔍 Save loop called")
        print("🔍 Start text: \(startTimeText), End text: \(endTimeText)")
        
        // Enable custom loop if both times are valid
        if let startTime = parseTimeString(startTimeText),
           let endTime = parseTimeString(endTimeText) {
            
            // Check if end time is too close to start time (2 seconds or less)
            let finalEndTime: TimeInterval
            if endTime <= startTime + 2 {
                finalEndTime = startTime + 10
                print("🔄 Auto-adjusted END time to 10 seconds after START: \(formatTime(finalEndTime))")
            } else {
                finalEndTime = endTime
            }
            
            if startTime < finalEndTime {
                // Set global pending loop settings
                globalLoopSettings.setPendingLoop(start: startTime, end: finalEndTime)
                
                // Also apply to currently playing manager if any
                if let playingManager = globalAudioManager.currentPlayingManager {
                    playingManager.hasCustomLoop = true
                    playingManager.loopStart = startTime
                    playingManager.loopEnd = finalEndTime
                    print("✅ Loop saved to current manager: \(playingManager.audioFileName)")
                }
                
                print("✅ Global loop settings saved: \(formatTime(startTime)) to \(formatTime(finalEndTime))")
            } else {
                globalLoopSettings.clearPendingLoop()
                print("❌ Invalid loop times, loop disabled")
            }
        } else {
            globalLoopSettings.clearPendingLoop()
            print("❌ Invalid loop times, loop disabled")
        }
    }
    
    private func validateAndCorrectTime(_ timeString: String) -> String? {
        let components = timeString.split(separator: ":")
        
        // Must have exactly one colon
        guard components.count == 2 else { return nil }
        
        // Parse minutes and seconds
        guard let minutesStr = components.first,
              let secondsStr = components.last,
              let minutes = Int(minutesStr),
              let seconds = Int(secondsStr) else {
            return nil
        }
        
        // Validate ranges
        guard minutes >= 0 && seconds >= 0 else { return nil }
        
        var correctedMinutes = minutes
        var correctedSeconds = seconds
        
        // Handle seconds overflow (e.g., 0:60 becomes 1:00)
        if seconds >= 60 {
            correctedMinutes += seconds / 60
            correctedSeconds = seconds % 60
        }
        
        // Format the corrected time
        return String(format: "%d:%02d", correctedMinutes, correctedSeconds)
    }
    
    private func parseTimeString(_ timeString: String) -> TimeInterval? {
        let components = timeString.split(separator: ":")
        guard components.count == 2,
              let minutes = Int(components[0]),
              let seconds = Int(components[1]),
              seconds >= 0 && seconds < 60 else {
            return nil
        }
        return TimeInterval(minutes * 60 + seconds)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatTimeInput(_ input: String) -> String {
        // Remove any non-numeric characters and limit to 3 digits
        let numbers = input.filter { $0.isNumber }.prefix(3)
        
        // If empty, return default
        if numbers.isEmpty {
            return "0:00"
        }
        
        // Convert to string and pad with leading zeros
        let paddedNumbers = String(repeating: "0", count: max(0, 3 - numbers.count)) + numbers
        
        // Format as M:SS
        return "\(paddedNumbers.prefix(1)):\(paddedNumbers.suffix(2))"
    }
}

// Lyric Tool Card Component
struct LyricToolCard: View {
    let title: String
    let icon: String
    let description: String
    let index: Int
    let isPro: Bool
    let backgroundImage: String
    @State private var showingToolDetail = false
    

    
    // Map tool titles to their corresponding image names (same as ToolCard)
    private var imageName: String {
        switch title {
        case "AI Bar Generator":
            return "ai-bar-generator"
        case "Alliterate It":
            return "alliterator"
        case "Chorus Creator":
            return "chorus-creator"
        case "Creative One-Liner":
            return "creative-one-liner"
        case "Diss Track Generator":
            return "disstrack-generator"
        case "Double Entendre":
            return "double-entendre"
        case "Finisher":
            return "song-finisher"
        case "Flex-on-'em":
            return "flex-on-em"
        case "Imperfect Rhyme":
            return "imperfect-rhyme"
        case "Industry Analyzer":
            return "industry-analyzer"
        case "Quadruple Entendre":
            return "quadruple-entendre"
        case "Rap Instagram Captions":
            return "song-ig-captions"
        case "Rap Name Generator":
            return "name-generator"
        case "Shapeshift":
            return "shapeshift"
        case "Triple Entendre":
            return "Triple-Entendre"
        case "Ultimate Come Up Song":
            return "ultimate-comeup-song"
        default:
            return "ai-bar-generator" // fallback
        }
    }
    
    var body: some View {
        Button(action: { showingToolDetail = true }) {
            HStack(alignment: .top, spacing: 12) {
                // Thumbnail with background image and custom tool image overlay
                ZStack {
                    // Background image
                    Image(backgroundImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipped()
                        .cornerRadius(8)
                    
                    // Dark overlay for better icon visibility
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 60, height: 60)
                    
                    // Custom tool image overlay
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Description only
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 0)
        }
        .fullScreenCover(isPresented: $showingToolDetail) {
            ToolDetailView(title: title, description: description, backgroundImage: backgroundImage)
        }
    }
}

// Helper to apply corner radius to specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    // Custom horizontal slide transition for onboarding
    func horizontalSlideTransition() -> some View {
        self
            .transition(
                .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                )
            )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct ConfettiPiece: View {
    let color: Color
    @State private var position = CGPoint(x: 0, y: 0)
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: CGFloat.random(in: 4...8), height: CGFloat.random(in: 8...16))
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .position(position)
            .onAppear {
                let startX = CGFloat.random(in: 0...UIScreen.main.bounds.width)
                let endX = startX + CGFloat.random(in: -100...100)
                let endY = UIScreen.main.bounds.height + 100
                
                position = CGPoint(x: startX, y: -20)
                
                withAnimation(.easeOut(duration: Double.random(in: 2...4))) {
                    position = CGPoint(x: endX, y: endY)
                    rotation = Double.random(in: 0...360)
                    opacity = 0
                }
            }
    }
}

// Custom ConfettiView removed - now using ConfettiSwiftUI package

// Local confetti implementation removed - now using ConfettiSwiftUI package
// The .confettiCannon() modifier is now provided by the ConfettiSwiftUI library

struct RatingView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @StateObject private var remoteConfig = RemoteConfigManager.shared
    @State private var selectedRating: Int = 5 // Default to 5 stars selected
    @State private var navigateToNext = false
    @State private var showingRatingPopup = false
    @State private var ratingCompleted = false
    @State private var popupShown = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Scrollable content
                ScrollView {
                    VStack(spacing: 0) {
                        // Ensure proper spacing for all device sizes, especially iPad
                        // Header with back button and progress
                HStack(spacing: 16) {
                    Button(action: { dismiss() }) {
                        Circle()
                            .fill(Color(.systemGray6))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "arrow.left")
                                    .foregroundColor(.black)
                                    .font(.system(size: 18))
                            )
                    }
                    
                    // Progress bar
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: UIScreen.main.bounds.width * (18.0/32.0), height: 2) // 18/32
                        
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 2)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                
                // Title
                Text("Give us rating")
                    .font(.system(size: 32, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                
                // Star rating container - enhanced design
                VStack {
                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { index in
                            Button(action: {
                                selectedRating = index
                                // Track question-specific answer
                                coordinator.trackQuestionAnswered(answer: "\(index) stars")
                            }) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 24)) // Reduced from 28
                                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                                    .scaleEffect(selectedRating >= index ? 1.1 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedRating)
                            }
                        }
                    }
                    .padding(.vertical, 16) // Reduced from 20
                    .padding(.horizontal, 32)
                }
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color(.systemGray6), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
                .padding(.top, 24) // Reduced from 32
                
                // Social proof section
                VStack(spacing: 12) { // Reduced from 16
                    Text("Made for\nmoms like you")
                        .font(.system(size: 20, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding(.top, 24) // Reduced from 32
                    
                    // User avatars with real photos
                    HStack(spacing: -8) {
                        Image("onb1")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44) // Reduced from 48
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                            )
                        
                        Image("onb2")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44) // Reduced from 48
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                            )
                        
                        Image("onb3")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44) // Reduced from 48
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                            )
                    }
                    .padding(.top, 8)
                    
                    Text("+ 1000 happy moms")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                
                // Testimonials with enhanced styling
                VStack(spacing: 12) { // Reduced from 16
                    // Marley Bryle testimonial
                    HStack(alignment: .top, spacing: 12) {
                        Image("onb4")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40) // Reduced from 44
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text("Jessica M.")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 10)) // Reduced from 12
                                            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                                    }
                                }
                            }
                            
                            Text("\"This app took all the guesswork out of starting solids. My daughter is 7 months and has already tried 15 new foods! I feel so much more confident as a mom.\"")
                                .font(.system(size: 13)) // Reduced from 14
                                .foregroundColor(.white.opacity(0.95))
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(2)
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray))
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    
                    // Benny Marcs testimonial
                    HStack(alignment: .top, spacing: 12) {
                        Image("onb5")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40) // Reduced from 44
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text("Amanda K.")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 10)) // Reduced from 12
                                            .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
                                    }
                                }
                            }
                            
                            Text("\"I was terrified about introducing allergenic foods. This app guided me step by step and my son now eats everything. No more picky eating anxiety!\"")
                                .font(.system(size: 13)) // Reduced from 14
                                .foregroundColor(.white.opacity(0.95))
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(2)
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray))
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 24) // Reduced from 32
                .padding(.bottom, 80) // Reduced bottom padding for floating button
                    }
                }
                
                // Floating Next button overlay
                VStack(spacing: 20) {
                    // Next button - Floating over scrollable content
                    Button(action: {
                        navigateToNext = true
                    }) {
                        Text("Next")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 26)
                                    .fill(selectedRating > 0 ? Color.black : Color.gray)
                                    .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                            )
                            .foregroundColor(.white)
                    }
                    .disabled(selectedRating == 0)
                    .padding(.horizontal, 24)
                    .padding(.top, 20) // Add equal top padding to match the spacing
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom + 16, 40)) // Ensure minimum 40pt bottom padding for iPad
                    .onChange(of: showingRatingPopup) { newValue in
                        if newValue && !popupShown {
                            popupShown = true
                            // Request review when showingRatingPopup becomes true
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                                SKStoreReviewController.requestReview(in: scene)
                            }
                            // Set a timer to detect when the popup is dismissed
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                showingRatingPopup = false
                                ratingCompleted = true
                            }
                        }
                    }
                    
                    // Force button visibility - safety measure for iPad
                    if selectedRating == 0 {
                        Text("Please select a rating to continue")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.bottom, 8)
                    }
                }
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                )
                
                // Hidden NavigationLink for programmatic navigation
                NavigationLink(isActive: $navigateToNext) {
                    CustomPlanView()
                } label: {
                    EmptyView()
                }
            }
            // Add bottom background to ensure button area is visible on iPad
            .background(Color.white, alignment: .bottom)
            .background(Color.white)
            .navigationBarHidden(true)
            .preferredColorScheme(.light)
            .ignoresSafeArea(.keyboard, edges: .bottom) // Ensure content isn't cut off by keyboard
            .onAppear {
                coordinator.currentStep = 18
                MixpanelService.shared.trackQuestionViewed(questionTitle: "Give us rating", stepNumber: 18)
                // FacebookPixelService.shared.trackOnboardingStepViewed(questionTitle: "Give us rating", stepNumber: 15)
                
                // Ensure button is always visible by default
                ratingCompleted = true
                
                // Show rating popup automatically when view appears - only when hardPaywall is true
                if remoteConfig.hardPaywall {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showingRatingPopup = true
                    }
                }
            }
        }
    }
}

// Update CompletionView to navigate to RatingView
struct CompletionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @StateObject private var remoteConfig = RemoteConfigManager.shared
    @State private var showContent = false
    @State private var confettiTrigger = 0
    @State private var navigateToRating = false
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with back button and progress
                HStack(spacing: 16) {
                    Button(action: { dismiss() }) {
                        Circle()
                            .fill(Color(.systemGray6))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "arrow.left")
                                    .foregroundColor(.black)
                                    .font(.system(size: 18))
                            )
                    }
                    
                    // Progress bar
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: UIScreen.main.bounds.width * 0.714, height: 2) // 15/21 ≈ 0.714
                        
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 2)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                
                Spacer()
                
                // Success checkmark
                ZStack {
                    Circle()
                        .fill(Color(red: 0.83, green: 0.69, blue: 0.52))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(showContent ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.3), value: showContent)
                
                // Main title
                Text("Thank you for trusting us")
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.top, 32)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.6), value: showContent)
                
                // Privacy message
                Text("We promise to always keep your personal information private and secure.")
                    .font(.system(size: 17))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.8), value: showContent)
                
                Spacer()
                
                // Continue button
                NavigationLink(isActive: $navigateToRating) {
                    RatingView()
                        .horizontalSlideTransition()
                } label: {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .simultaneousGesture(TapGesture().onEnded {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    coordinator.nextStep()
                    navigateToRating = true
                })
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
        .confettiCannon(trigger: $confettiTrigger)
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
        .onAppear {
            coordinator.currentStep = 17
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showContent = true
                confettiTrigger += 1
            }
        }
    }
}

// Update ProgressGraphView to navigate to CompletionView
struct ProgressGraphView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var showGraph = false
    @State private var showTrophy = false
    @State private var navigateToNext = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * 0.667, height: 2) // 14/21 ≈ 0.667
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Title
            Text("You have great potential to crush your goal")
                .font(.system(size: 32, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 32)
            
            // Graph container
            VStack(spacing: 16) {
                // Graph title
                Text("Your weight transition")
                    .font(.system(size: 17))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .opacity(showGraph ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.3), value: showGraph)
                
                // Graph
                ZStack {
                    // Background grid lines (horizontal)
                    VStack(spacing: 40) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 1)
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 1)
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 1)
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 24)
                    
                    GeometryReader { geometry in
                        let graphWidth = geometry.size.width - 48 // Account for padding
                        let graphHeight: CGFloat = 160
                        
                        // Define exact data points first
                        let point1 = CGPoint(x: 0, y: graphHeight * 0.8)           // 3 days
                        let point2 = CGPoint(x: graphWidth * 0.5, y: graphHeight * 0.5)  // 7 days  
                        let point3 = CGPoint(x: graphWidth, y: graphHeight * 0.2)   // 30 days
                        
                        // Area under curve
                        Path { path in
                            // Start from bottom
                            path.move(to: CGPoint(x: point1.x, y: graphHeight))
                            // Line to first point
                            path.addLine(to: point1)
                            // Curve through all points
                            path.addCurve(
                                to: point3,
                                control1: CGPoint(x: point1.x + graphWidth * 0.3, y: point1.y - 20),
                                control2: CGPoint(x: point3.x - graphWidth * 0.3, y: point3.y + 20)
                            )
                            // Close the area
                            path.addLine(to: CGPoint(x: point3.x, y: graphHeight))
                            path.addLine(to: CGPoint(x: point1.x, y: graphHeight))
                            path.closeSubpath()
                        }
                        .fill(Color(red: 0.83, green: 0.69, blue: 0.52).opacity(0.1))
                        .offset(x: 24) // Apply padding offset
                        .opacity(showGraph ? 1 : 0)
                        .animation(.easeOut(duration: 1.2).delay(0.6), value: showGraph)
                        
                        // Line graph
                        Path { path in
                            path.move(to: point1)
                            path.addCurve(
                                to: point3,
                                control1: CGPoint(x: point1.x + graphWidth * 0.3, y: point1.y - 20),
                                control2: CGPoint(x: point3.x - graphWidth * 0.3, y: point3.y + 20)
                            )
                        }
                        .trim(from: 0, to: showGraph ? 1 : 0)
                        .stroke(Color(red: 0.83, green: 0.69, blue: 0.52), lineWidth: 2)
                        .offset(x: 24) // Apply padding offset
                        .animation(.easeOut(duration: 1.2).delay(0.5), value: showGraph)
                        
                        // Data points - using the SAME coordinate system
                        Group {
                            // First point (3 days)
                            Circle()
                                .fill(.white)
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(Color(red: 0.83, green: 0.69, blue: 0.52), lineWidth: 2)
                                )
                                .position(x: point1.x + 24, y: point1.y) // Apply padding offset
                                .opacity(showGraph ? 1 : 0)
                                .animation(.easeOut(duration: 0.3).delay(0.5), value: showGraph)
                            
                            // Second point (7 days)
                            Circle()
                                .fill(.white)
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(Color(red: 0.83, green: 0.69, blue: 0.52), lineWidth: 2)
                                )
                                .position(x: point2.x + 24, y: point2.y) // Apply padding offset
                                .opacity(showGraph ? 1 : 0)
                                .animation(.easeOut(duration: 0.3).delay(0.8), value: showGraph)
                            
                            // Third point with trophy (30 days)
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 12, height: 12)
                                    .overlay(
                                        Circle()
                                            .stroke(Color(red: 0.83, green: 0.69, blue: 0.52), lineWidth: 2)
                                    )
                                
                                Circle()
                                    .fill(Color(red: 0.83, green: 0.69, blue: 0.52))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "trophy.fill")
                                            .foregroundColor(.white)
                                            .font(.system(size: 16))
                                    )
                                    .offset(y: -24)
                            }
                            .position(x: point3.x + 24, y: point3.y) // Apply padding offset
                            .opacity(showGraph ? 1 : 0)
                            .animation(.easeOut(duration: 0.3).delay(1.1), value: showGraph)
                        }
                    }
                }
                .frame(height: 160)
                .padding(.horizontal, 24)
                
                // Time labels
                HStack {
                    Text("3 Days")
                        .font(.system(size: 15))
                    Spacer()
                    Text("7 Days")
                        .font(.system(size: 15))
                    Spacer()
                    Text("30 Days")
                        .font(.system(size: 15))
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .opacity(showGraph ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(1.2), value: showGraph)
                
                // Description text - full text without truncation
                Text("Based on Cal AI's historical data, weight loss is usually delayed at first, but after 7 days, you can burn fat like crazy!")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil) // Allow unlimited lines
                    .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .opacity(showGraph ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(1.3), value: showGraph)
            }
            .padding(.bottom, 24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemGray6))
            )
            .padding(.horizontal, 24)
            .padding(.top, 40)
            
            Spacer()
            
            // Continue button
            NavigationLink(isActive: $navigateToNext) {
                CompletionView()
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(showGraph ? Color.black : Color(.systemGray5))
                    .foregroundColor(showGraph ? .white : Color(.systemGray2))
                    .cornerRadius(28)
            }
            .disabled(!showGraph)
            .simultaneousGesture(TapGesture().onEnded {
                if showGraph {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    coordinator.nextStep()
                    navigateToNext = true
                }
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
        .onAppear {
            coordinator.currentStep = 16
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showGraph = true
            }
        }
    }
}

// Update UltimateGoalView to navigate to ProgressGraphView
struct UltimateGoalView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var selectedGoal: String?
    @State private var navigateToNext = false
    
    let goals = [
        "Raise an adventurous eater",
        "Ensure balanced nutrition",
        "Build lifelong healthy habits"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * 0.619, height: 2) // 13/21 ≈ 0.619
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Title and subtitle
            VStack(alignment: .leading, spacing: 8) {
                Text("What would you like\nto achieve?")
                    .font(.system(size: 32, weight: .bold))
                Text("We'll build your baby's personalized food plan.")
                    .font(.system(size: 17))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            
            // Goals list
            VStack(spacing: 16) {
                ForEach(goals, id: \.self) { goal in
                    Button(action: { 
                        selectedGoal = goal
                        // Track question-specific answer
                        coordinator.trackQuestionAnswered(answer: goal)
                    }) {
                        Text(goal)
                            .font(.system(size: 17))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(selectedGoal == goal ? Color.black : Color(.systemGray6))
                            .foregroundColor(selectedGoal == goal ? .white : .black)
                            .clipShape(
                        RoundedCorner(radius: 16, corners: [.topLeft, .topRight, .bottomLeft, .bottomRight])
                    )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            
            Spacer()
            
            // Continue button
            NavigationLink(isActive: $navigateToNext) {
                ProgressGraphView()
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedGoal != nil ? Color.black : Color(.systemGray5))
                    .foregroundColor(selectedGoal != nil ? .white : Color(.systemGray2))
                    .cornerRadius(28)
            }
            .disabled(selectedGoal == nil)
            .simultaneousGesture(TapGesture().onEnded {
                if selectedGoal != nil {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    coordinator.nextStep()
                    navigateToNext = true
                }
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
        .onAppear {
            coordinator.currentStep = 12
        }
    }
}

// Update ObstaclesView to navigate to UltimateGoalView
struct ObstaclesView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var selectedObstacle: String?
    @State private var navigateToNext = false
    
    let obstacles = [
        ("Worried about allergies", "exclamationmark.shield"),
        ("Don't know which foods to start with", "questionmark.circle"),
        ("Concerned about choking hazards", "hand.raised"),
        ("Unsure about textures and purees", "fork.knife"),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * 0.571, height: 2) // 12/21 ≈ 0.571
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Title
            Text("What are your biggest\nworries about\nstarting solids?")
                .font(.system(size: 32, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 32)
            
            // Obstacles list
            VStack(spacing: 16) {
                ForEach(obstacles, id: \.0) { obstacle, icon in
                    Button(action: { 
                        selectedObstacle = obstacle
                        // Track question-specific answer
                        coordinator.trackQuestionAnswered(answer: obstacle)
                    }) {
                        HStack {
                            Image(systemName: icon)
                                .font(.system(size: 20))
                                .frame(width: 24)
                            Text(obstacle)
                                .font(.system(size: 17))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(selectedObstacle == obstacle ? Color.black : Color(.systemGray6))
                        .foregroundColor(selectedObstacle == obstacle ? .white : .black)
                        .clipShape(
                        RoundedCorner(radius: 16, corners: [.topLeft, .topRight, .bottomLeft, .bottomRight])
                    )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            
            Spacer()
            
            // Continue button
            NavigationLink(isActive: $navigateToNext) {
                UltimateGoalView()
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedObstacle != nil ? Color.black : Color(.systemGray5))
                    .foregroundColor(selectedObstacle != nil ? .white : Color(.systemGray2))
                    .cornerRadius(28)
            }
            .disabled(selectedObstacle == nil)
            .simultaneousGesture(TapGesture().onEnded {
                if selectedObstacle != nil {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    coordinator.nextStep()
                    navigateToNext = true
                }
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
        .onAppear {
            coordinator.currentStep = 11
        }
    }
}

// Update ThriftingTransitionView to navigate to ObstaclesView
struct ThriftingTransitionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var navigateToNext = false
    @State private var showChart = false
    @State private var animationComplete = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * 0.524, height: 2) // 11/21 ≈ 0.524
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Title
            Text("Babies introduced to more\nfoods early are far less\npicky eaters")
                .font(.system(size: 32, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 32)
            
            // Comparison chart
            VStack {
                HStack(alignment: .top, spacing: 16) {
                    // Without plan column
                    VStack(spacing: 0) {
                        Text("Without\na plan")
                            .font(.system(size: 17))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .padding(.bottom, 12)
                        
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.5))
                                .frame(width: 80, height: 160)
                            
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .frame(width: 80, height: showChart ? 40 : 0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: showChart)
                            
                            Text("5 foods")
                                .font(.system(size: 17))
                                .foregroundColor(.black)
                                .opacity(showChart ? 1 : 0)
                                .animation(.easeIn.delay(0.8), value: showChart)
                                .padding(.bottom, showChart ? 8 : 0)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // With plan column
                    VStack(spacing: 0) {
                        Text("With\nour plan")
                            .font(.system(size: 17))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .padding(.bottom, 12)
                        
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.5))
                                .frame(width: 80, height: 160)
                            
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.black,
                                        Color.black.opacity(0.8)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                ))
                                .frame(width: 80, height: showChart ? 120 : 0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: showChart)
                            
                            Text("20+")
                                .font(.system(size: 17))
                                .foregroundColor(.white)
                                .opacity(showChart ? 1 : 0)
                                .animation(.easeIn.delay(0.9), value: showChart)
                                .padding(.bottom, showChart ? 8 : 0)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 1.0, green: 0.4, blue: 0.7), // Pink
                                    Color(red: 0.4, green: 0.9, blue: 0.5)  // Green
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .opacity(0.1) // Subtle gradient
                        )
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            
            Spacer()
            
            // Continue button
            NavigationLink(isActive: $navigateToNext) {
                ObstaclesView()
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(animationComplete ? Color.black : Color(.systemGray5))
                    .foregroundColor(animationComplete ? .white : Color(.systemGray2))
                    .cornerRadius(28)
            }
            .disabled(!animationComplete)
            .simultaneousGesture(TapGesture().onEnded {
                if animationComplete {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    coordinator.nextStep()
                    navigateToNext = true
                }
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
        .onAppear {
            coordinator.currentStep = 10
            MixpanelService.shared.trackQuestionViewed(questionTitle: "Cal AI Comparison", stepNumber: 10)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showChart = true
                // Enable the button after all animations complete (0.3s initial delay + 0.9s for animations + 0.1s buffer)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    animationComplete = true
                }
            }
        }
    }
}

// Update GoalSpeedView to navigate to ThriftingTransitionView
struct GoalSpeedView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var navigateToNext = false
    let selectedGoal: String
    
    init(selectedGoal: String) {
        self.selectedGoal = selectedGoal
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * 0.476, height: 2) // 10/21 ≈ 0.476
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Title and subtitle
            VStack(alignment: .leading, spacing: 8) {
                Text("AI Powered Fake Detection")
                    .font(.system(size: 32, weight: .bold))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Thrifty analyzes stitching, logos, and materials. We flag possible fakes automatically.")
                    .font(.system(size: 17))
                    .foregroundColor(.gray)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            
            // AI Fake Detection Image
            Image("ai-fake-detection")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 400)
                .padding(.horizontal, 16)
                .padding(.top, 0)
            
            Spacer()
            
            // Update Continue button to navigate to ThriftingTransitionView
            NavigationLink(isActive: $navigateToNext) {
                ThriftingTransitionView()
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(28)
            }
            .simultaneousGesture(TapGesture().onEnded {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                // Track question-specific answer
                coordinator.trackQuestionAnswered(answer: "Viewed AI Powered Fake Detection")
                coordinator.nextStep()
                navigateToNext = true
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
        .onAppear {
            coordinator.currentStep = 9
        }
    }
}

// Update GoalConfirmationView to navigate to GoalSpeedView
struct GoalConfirmationView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var navigateToSpeed = false
    let selectedGoal: String
    
    init(selectedGoal: String) {
        self.selectedGoal = selectedGoal
    }
    
    var formattedGoal: String {
        switch selectedGoal {
        case "I sometimes skip rare/valuable finds":
            return "Finding rare/valuable items"
        case "It's a hassle figuring out what things are really worth.":
            return "Valuing items correctly"
        case "I regret some of my purchases":
            return "Making smarter purchases"
        default:
            return selectedGoal
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * 0.429, height: 2) // 9/21 ≈ 0.429
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            Spacer()
            
            // Goal confirmation text
            VStack(spacing: 16) {
                Text(formattedGoal)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color(red: 0.83, green: 0.69, blue: 0.52)) // Gold color for the goal
                + Text(" is a realistic target. It's not hard at all!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.black)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            
            // Subtitle
            Text("90% of users say that the change is obvious after using Thrifty.")
                .font(.system(size: 17))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 24)
            
            Spacer()
            
            // Continue button
            NavigationLink(isActive: $navigateToSpeed) {
                GoalSpeedView(selectedGoal: selectedGoal)
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(28)
            }
            .simultaneousGesture(TapGesture().onEnded {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                coordinator.nextStep()
                navigateToSpeed = true
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
        .onAppear {
            coordinator.currentStep = 8
            MixpanelService.shared.trackQuestionViewed(questionTitle: "Goal Confirmation", stepNumber: 8)
            // FacebookPixelService.shared.trackOnboardingStepViewed(questionTitle: "Goal Confirmation", stepNumber: 8)
        }
    }
}

// Update ThriftingGoalSelectionView to navigate to GoalConfirmationView
struct ThriftingGoalSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var selectedGoal: String?
    @State private var navigateToConfirmation = false
    
    let goals = [
        "I sometimes skip rare/valuable finds",
        "It's a hassle figuring out what things are really worth.",
        "I regret some of my purchases"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * 0.381, height: 2) // 8/21 ≈ 0.381
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Title and subtitle
            VStack(alignment: .leading, spacing: 8) {
                Text("What are you struggling with?")
                    .font(.system(size: 32, weight: .bold))
                Text("This will be used to calibrate your custom thrift settings.")
                    .font(.system(size: 17))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            
            // Goal options
            VStack(spacing: 16) {
                ForEach(goals, id: \.self) { goal in
                    Button(action: { 
                        selectedGoal = goal
                        // Track question-specific answer
                        coordinator.trackQuestionAnswered(answer: goal)
                    }) {
                        Text(goal)
                            .font(.system(size: 17))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(selectedGoal == goal ? Color.black : Color(.systemGray6))
                            .foregroundColor(selectedGoal == goal ? .white : .black)
                            .clipShape(
                        RoundedCorner(radius: 16, corners: [.topLeft, .topRight, .bottomLeft, .bottomRight])
                    )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            
            Spacer()
            
            // Continue button
            NavigationLink(isActive: $navigateToConfirmation) {
                if let goal = selectedGoal {
                    GoalConfirmationView(selectedGoal: goal)
                }
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedGoal != nil ? Color.black : Color(.systemGray5))
                    .foregroundColor(selectedGoal != nil ? .white : Color(.systemGray2))
                    .cornerRadius(28)
            }
            .disabled(selectedGoal == nil)
            .simultaneousGesture(TapGesture().onEnded {
                if selectedGoal != nil {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    coordinator.nextStep()
                    navigateToConfirmation = true
                }
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
        .onAppear {
            coordinator.currentStep = 7
        }
    }
}

// Update WritingStyleView to navigate to ThriftingGoalSelectionView
struct WritingStyleView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var selectedStyle: String?
    @State private var navigateToGoal = false
    
    let styles = [
        ("Unique, story-rich items", "sparkles"),
        ("Deals & Discounts", "tag.fill"),
        ("Quick Flips", "arrow.clockwise"),
        ("No specific style", "xmark.circle")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * 0.333, height: 2) // 7/21 ≈ 0.333
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Title and subtitle
            VStack(alignment: .leading, spacing: 8) {
                Text("Do you have a specific\neating style?")
                    .font(.system(size: 32, weight: .bold))
                Text("This will be used to calibrate your custom nutrition plan.")
                    .font(.system(size: 17))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            
            // Style options
            VStack(spacing: 16) {
                ForEach(styles, id: \.0) { style, icon in
                    Button(action: { 
                        selectedStyle = style
                        // Track question-specific answer
                        coordinator.trackQuestionAnswered(answer: style)
                    }) {
                        HStack {
                            Image(systemName: icon)
                                .font(.system(size: 24))
                                .frame(width: 32)
                            Text(style)
                                .font(.system(size: 17))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(selectedStyle == style ? Color.black : Color(.systemGray6))
                        .foregroundColor(selectedStyle == style ? .white : .black)
                        .clipShape(
                        RoundedCorner(radius: 16, corners: [.topLeft, .topRight, .bottomLeft, .bottomRight])
                    )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            
            Spacer()
            
            // Continue button
            NavigationLink(isActive: $navigateToGoal) {
                ThriftingGoalSelectionView()
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedStyle != nil ? Color.black : Color(.systemGray5))
                    .foregroundColor(selectedStyle != nil ? .white : Color(.systemGray2))
                    .cornerRadius(28)
            }
            .disabled(selectedStyle == nil)
            .simultaneousGesture(TapGesture().onEnded {
                if selectedStyle != nil {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    coordinator.nextStep()
                    navigateToGoal = true
                }
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
        .onAppear {
            coordinator.currentStep = 6
        }
    }
}

// Update MusicGenreView to navigate to WritingStyleView
struct MusicGenreView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var navigateToStyle = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * 0.286, height: 2) // 6/21 ≈ 0.286
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Title and subtitle
            VStack(alignment: .leading, spacing: 8) {
                Text("Real-Time Marketplace Data")
                    .font(.system(size: 32, weight: .bold))
                Text("We use AI and real-time listings data from eBay, Etsy, Depop, & More!")
                    .font(.system(size: 17))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            
            // AI Summary Image
            Image("ai-summary")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 400)
                .padding(.horizontal, 16)
                .padding(.top, 20)
            
            Spacer()
            
            // Next button with navigation to WritingStyleView
            NavigationLink(isActive: $navigateToStyle) {
                WritingStyleView()
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .cornerRadius(28)
            }
            .simultaneousGesture(TapGesture().onEnded {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                // Track question-specific answer
                coordinator.trackQuestionAnswered(answer: "Viewed Real-Time Marketplace Data")
                coordinator.nextStep()
                navigateToStyle = true
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
        .onAppear {
            coordinator.currentStep = 5
        }
    }
}

// Update AnimatedGraph to expose animation state
struct AnimatedGraph: View {
    @State private var showGraph = false
    @Binding var isAnimationComplete: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Graph container
            ZStack {
                // Graph background
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemGray6))
                    .frame(height: 240)
                
                VStack(alignment: .leading, spacing: 0) {
                    // Your weight label
                    Text("Your weight")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                        .padding(.leading, 24)
                        .padding(.top, 24)
                        .opacity(showGraph ? 1 : 0)
                        .animation(.easeOut(duration: 0.6).delay(0.3), value: showGraph)
                    
                    ZStack {
                        // Creativity line and fill
                        Path { path in
                            path.move(to: CGPoint(x: 24, y: 120))
                            path.addCurve(
                                to: CGPoint(x: 290, y: 60),
                                control1: CGPoint(x: 100, y: 160),
                                control2: CGPoint(x: 220, y: 60)
                            )
                            path.addLine(to: CGPoint(x: 290, y: 0))
                            path.addLine(to: CGPoint(x: 24, y: 0))
                            path.closeSubpath()
                        }
                        .trim(from: 0, to: showGraph ? 1 : 0)
                        .fill(Color.green.opacity(0.08))
                        .animation(.easeOut(duration: 1).delay(0.5), value: showGraph)
                        
                        // Normal writing line
                        Path { path in
                            path.move(to: CGPoint(x: 24, y: 120))
                            path.addCurve(
                                to: CGPoint(x: 290, y: 180),
                                control1: CGPoint(x: 100, y: 180),
                                control2: CGPoint(x: 220, y: 180)
                            )
                        }
                        .trim(from: 0, to: showGraph ? 1 : 0)
                        .stroke(Color.black, lineWidth: 1)
                        .animation(.easeOut(duration: 1), value: showGraph)
                        
                        // Creativity line
                        Path { path in
                            path.move(to: CGPoint(x: 24, y: 120))
                            path.addCurve(
                                to: CGPoint(x: 290, y: 60),
                                control1: CGPoint(x: 100, y: 160),
                                control2: CGPoint(x: 220, y: 60)
                            )
                        }
                        .trim(from: 0, to: showGraph ? 1 : 0)
                        .stroke(Color.green, lineWidth: 1)
                        .animation(.easeOut(duration: 1).delay(0.5), value: showGraph)
                        
                        // Normal writing text
                        Text("Normal dieting")
                            .font(.system(size: 10))
                            .foregroundColor(Color.gray.opacity(0.95))
                            .offset(x: 40, y: 60)
                            .opacity(showGraph ? 1 : 0)
                            .animation(.easeOut(duration: 0.6).delay(0.6), value: showGraph)
                        
                        // Month labels
                        HStack {
                            Text("Month 1")
                                .font(.system(size: 15))
                                .padding(.leading, 24)
                            
                            Spacer()
                            
                            Text("Month 6")
                                .font(.system(size: 15))
                                .padding(.trailing, 24)
                        }
                        .frame(maxWidth: .infinity)
                        .offset(y: 100)
                        .opacity(showGraph ? 1 : 0)
                        .animation(.easeOut(duration: 0.6).delay(0.6), value: showGraph)
                    }
                    .frame(height: 180)
                    .padding(.bottom, 60)
                }
            }
            
            // Bottom text
            Text("80% of Cal AI users maintain their weight")
                .font(.system(size: 17))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .opacity(showGraph ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(1.2), value: showGraph)
                .fixedSize(horizontal: false, vertical: true)
                .onChange(of: showGraph) { newValue in
                    // Set animation complete after all animations finish
                    if newValue {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            isAnimationComplete = true
                        }
                    }
                }
            
            Spacer()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showGraph = true
            }
        }
    }
}

struct LongTermResultsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var navigateToGenre = false
    @State private var isGraphAnimationComplete = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * (4.0/34.0), height: 2) // 4/34
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Title
            Text("Build healthy\neating habits early")
                .font(.system(size: 32, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 32)
            
            // Animated graph with binding
            AnimatedGraph(isAnimationComplete: $isGraphAnimationComplete)
                .padding(.top, 60)
                .padding(.horizontal, 24)
            
            Spacer()
            
            // Next button with navigation
            NavigationLink(isActive: $navigateToGenre) {
                HeightWeightView()
                    .horizontalSlideTransition()
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isGraphAnimationComplete ? Color.black : Color(.systemGray5))
                    .foregroundColor(isGraphAnimationComplete ? .white : Color(.systemGray2))
                    .cornerRadius(28)
            }
            .disabled(!isGraphAnimationComplete)
            .simultaneousGesture(TapGesture().onEnded {
                if isGraphAnimationComplete {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    coordinator.nextStep()
                    navigateToGenre = true
                }
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
        .onAppear {
            coordinator.currentStep = 3
            MixpanelService.shared.trackQuestionViewed(questionTitle: "Cal AI creates long-term results", stepNumber: 3)
        }
    }
}

// Height & Weight View
struct HeightWeightView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @ObservedObject var onboardingData = OnboardingDataManager.shared
    @State private var isImperial = true
    @State private var selectedFeet = 5
    @State private var selectedInches = 4
    @State private var selectedCentimeters = 165
    @State private var selectedWeight = 148
    @State private var selectedWeightKg = 67
    @State private var navigateToBirthdate = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * (5.0/32.0), height: 2) // 5/32
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Title and subtitle
            VStack(alignment: .leading, spacing: 8) {
                Text("About your baby")
                    .font(.system(size: 32, weight: .bold))
                Text("We'll use this to recommend age-appropriate portions.")
                    .font(.system(size: 17))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            
            Spacer()
            
            // Imperial/Metric Toggle
            HStack(spacing: 16) {
                Text("Imperial")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(isImperial ? .black : .gray)
                
                Toggle("", isOn: $isImperial)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .gray))
                    .onChange(of: isImperial) { newValue in
                        if newValue {
                            // Converting from Metric to Imperial
                            let totalInches = Double(selectedCentimeters) / 2.54
                            selectedFeet = Int(totalInches / 12)
                            selectedInches = Int(totalInches.truncatingRemainder(dividingBy: 12))
                            selectedWeight = Int(Double(selectedWeightKg) * 2.20462)
                        } else {
                            // Converting from Imperial to Metric
                            let totalInches = (selectedFeet * 12) + selectedInches
                            selectedCentimeters = Int(Double(totalInches) * 2.54)
                            selectedWeightKg = Int(Double(selectedWeight) / 2.20462)
                        }
                    }
                
                Text("Metric")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(!isImperial ? .black : .gray)
            }
            .padding(.bottom, 40)
            
            // Pickers
            HStack(spacing: 40) {
                // Height Section
                VStack(spacing: 16) {
                    Text("Length")
                        .font(.system(size: 17, weight: .semibold))
                    
                    if isImperial {
                        HStack(spacing: 20) {
                            // Feet picker
                            Picker("", selection: $selectedFeet) {
                                ForEach(2..<9) { feet in
                                    Text("\(feet) ft")
                                        .tag(feet)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 70)
                            .clipped()
                            
                            // Inches picker
                            Picker("", selection: $selectedInches) {
                                ForEach(0..<12) { inches in
                                    Text("\(inches) in")
                                        .tag(inches)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 70)
                            .clipped()
                        }
                    } else {
                        // Centimeters picker
                        Picker("", selection: $selectedCentimeters) {
                            ForEach(120..<220) { cm in
                                Text("\(cm) cm")
                                    .tag(cm)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                        .clipped()
                    }
                }
                
                // Weight Section
                VStack(spacing: 16) {
                    Text("Weight")
                        .font(.system(size: 17, weight: .semibold))
                    
                    if isImperial {
                        Picker("", selection: $selectedWeight) {
                            ForEach(100..<301) { weight in
                                Text("\(weight) lb")
                                    .tag(weight)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 90)
                        .clipped()
                    } else {
                        Picker("", selection: $selectedWeightKg) {
                            ForEach(40..<150) { weight in
                                Text("\(weight) kg")
                                    .tag(weight)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 90)
                        .clipped()
                    }
                }
            }
            
            Spacer()
            
            // Continue button
            NavigationLink(isActive: $navigateToBirthdate) {
                BirthdateView()
                    .horizontalSlideTransition()
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .simultaneousGesture(TapGesture().onEnded {
                // Save height and weight to onboarding data
                onboardingData.isImperial = isImperial
                onboardingData.heightFeet = selectedFeet
                onboardingData.heightInches = selectedInches
                onboardingData.heightCm = selectedCentimeters
                onboardingData.weightLbs = Double(selectedWeight)
                onboardingData.weightKg = Double(selectedWeightKg)
                
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                coordinator.nextStep()
                navigateToBirthdate = true
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
    }
}

// Birthdate View
struct BirthdateView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @ObservedObject var onboardingData = OnboardingDataManager.shared
    @State private var selectedMonth = 0 // January
    @State private var selectedDay = 0 // 1st
    @State private var selectedYear = 25 // 1999 (offset from 1974)
    @State private var navigateToNext = false
    
    let months = ["January", "February", "March", "April", "May", "June", 
                  "July", "August", "September", "October", "November", "December"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * (6.0/32.0), height: 2) // 6/32
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Title and subtitle
            VStack(alignment: .leading, spacing: 8) {
                Text("When was your\nbaby born?")
                    .font(.system(size: 32, weight: .bold))
                Text("We'll track milestones alongside new foods.")
                    .font(.system(size: 17))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            
            Spacer()
            
            // Date Pickers
            HStack(spacing: 0) {
                // Month picker
                Picker("", selection: $selectedMonth) {
                    ForEach(0..<months.count, id: \.self) { index in
                        Text(months[index])
                            .tag(index)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 150)
                .clipped()
                
                // Day picker
                Picker("", selection: $selectedDay) {
                    ForEach(0..<31, id: \.self) { day in
                        Text("\(day + 1)")
                            .tag(day)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 80)
                .clipped()
                
                // Year picker
                Picker("", selection: $selectedYear) {
                    ForEach(0..<3, id: \.self) { offset in
                        Text(verbatim: "\(2023 + offset)")
                            .tag(offset)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 100)
                .clipped()
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Continue button
            NavigationLink(isActive: $navigateToNext) {
                PersonalCoachView()
                    .horizontalSlideTransition()
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .simultaneousGesture(TapGesture().onEnded {
                // Save birthdate to onboarding data
                onboardingData.birthMonth = selectedMonth
                onboardingData.birthDay = selectedDay
                onboardingData.birthYear = selectedYear
                
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                coordinator.nextStep()
                navigateToNext = true
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
    }
}

// Personal Coach View
struct PersonalCoachView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var selectedAnswer: String?
    @State private var navigateToGoal = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * (7.0/32.0), height: 2) // 7/32
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("Do you work with a\npediatrician for\nnutrition advice?")
                    .font(.system(size: 32, weight: .bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            
            Spacer()
            
            // Answer options
            VStack(spacing: 16) {
                // Yes button
                Button(action: { 
                    selectedAnswer = "Yes"
                    coordinator.trackQuestionAnswered(answer: "Yes")
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: selectedAnswer == "Yes" ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24))
                        Text("yes")
                            .font(.system(size: 17, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedAnswer == "Yes" ? Color.white : Color(.systemGray6))
                    .foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                // No button
                Button(action: { 
                    selectedAnswer = "No"
                    coordinator.trackQuestionAnswered(answer: "No")
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: selectedAnswer == "No" ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24))
                        Text("No")
                            .font(.system(size: 17, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedAnswer == "No" ? Color.black : Color(.systemGray6))
                    .foregroundColor(selectedAnswer == "No" ? .white : .black)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Continue button
            NavigationLink(isActive: $navigateToGoal) {
                GoalSelectionView()
                    .horizontalSlideTransition()
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedAnswer != nil ? Color.black : Color(.systemGray5))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(selectedAnswer == nil)
            .simultaneousGesture(TapGesture().onEnded {
                if selectedAnswer != nil {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    coordinator.nextStep()
                    navigateToGoal = true
                }
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
    }
}

// Goal Selection View
struct GoalSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @ObservedObject var onboardingData = OnboardingDataManager.shared
    @State private var selectedGoal: String?
    @State private var navigateToWeight = false
    
    let goals = ["Introduce new foods", "Ensure balanced nutrition", "Handle picky eating"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * (8.0/32.0), height: 2) // 8/32
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Title and subtitle
            VStack(alignment: .leading, spacing: 8) {
                Text("What is your main\ngoal?")
                    .font(.system(size: 32, weight: .bold))
                Text("We'll customize your baby's food plan accordingly.")
                    .font(.system(size: 17))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            
            Spacer()
            
            // Goal options
            VStack(spacing: 16) {
                ForEach(goals, id: \.self) { goal in
                    Button(action: { 
                        selectedGoal = goal
                        coordinator.trackQuestionAnswered(answer: goal)
                    }) {
                        Text(goal)
                            .font(.system(size: 17, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(selectedGoal == goal ? Color.black : Color(.systemGray6))
                            .foregroundColor(selectedGoal == goal ? .white : .black)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Continue button
            NavigationLink(isActive: $navigateToWeight) {
                DesiredWeightView(currentWeight: Int(onboardingData.weightLbs), selectedGoal: selectedGoal ?? "Introduce new foods")
                    .horizontalSlideTransition()
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedGoal != nil ? Color.black : Color(.systemGray5))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(selectedGoal == nil)
            .simultaneousGesture(TapGesture().onEnded {
                if let goal = selectedGoal {
                    // Save fitness goal to onboarding data
                    onboardingData.fitnessGoal = goal
                    
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    coordinator.nextStep()
                    navigateToWeight = true
                }
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
    }
}

// Desired Weight View
struct DesiredWeightView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @ObservedObject var onboardingData = OnboardingDataManager.shared
    let currentWeight: Int
    let selectedGoal: String
    @State private var desiredWeight: Double
    @State private var navigateToResult = false
    
    init(currentWeight: Int, selectedGoal: String) {
        self.currentWeight = currentWeight
        self.selectedGoal = selectedGoal
        _desiredWeight = State(initialValue: 10.0)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * (9.0/32.0), height: 2) // 9/32
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("How many new foods\nthis month?")
                    .font(.system(size: 32, weight: .bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            
            Spacer()
            
            // Goal and food count display
            VStack(spacing: 24) {
                Text(selectedGoal)
                    .font(.system(size: 17))
                    .foregroundColor(.gray)
                
                Text("\(Int(desiredWeight)) foods")
                    .font(.system(size: 48, weight: .bold))
                
                // Visual slider representation
                GeometryReader { geometry in
                    let totalBars = 40
                    let filledBars = Int((desiredWeight - 5.0) / 25.0 * Double(totalBars))
                    
                    HStack(spacing: 2) {
                        ForEach(0..<totalBars, id: \.self) { index in
                            Rectangle()
                                .fill(index < filledBars ? Color.gray : Color(.systemGray5))
                                .frame(height: 80)
                        }
                    }
                }
                .frame(height: 80)
                .padding(.horizontal, 24)
            }
            .padding(.horizontal, 24)
            
            // Slider
            Slider(value: $desiredWeight, in: 5.0...30.0, step: 1.0)
                .accentColor(.gray)
                .padding(.horizontal, 24)
                .padding(.top, 20)
            
            Spacer()
            
            // Continue button
            NavigationLink(isActive: $navigateToResult) {
                WeightTargetResultView(
                    currentWeight: Double(currentWeight),
                    desiredWeight: desiredWeight,
                    selectedGoal: selectedGoal
                )
                .horizontalSlideTransition()
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .simultaneousGesture(TapGesture().onEnded {
                // Save desired weight to onboarding data
                onboardingData.desiredWeightLbs = desiredWeight
                onboardingData.desiredWeightKg = desiredWeight / 2.20462
                
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                coordinator.nextStep()
                navigateToResult = true
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
    }
}

// Weight Target Result View
struct WeightTargetResultView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    let currentWeight: Double
    let desiredWeight: Double
    let selectedGoal: String
    @State private var navigateToNext = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * (10.0/32.0), height: 2) // 10/32
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            Spacer()
            
            // Result text
            VStack(spacing: 16) {
                (Text("Introducing ")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.black)
                + Text("\(Int(desiredWeight)) new foods")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Color(red: 0.83, green: 0.69, blue: 0.52))
                + Text(" this month is a perfect pace!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.black))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            }
            
            // Subtitle
            Text("90% of parents say their baby accepts new foods more willingly when introduced gradually with a plan.")
                .font(.system(size: 17))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 24)
            
            Spacer()
            
            // Continue button
            NavigationLink(isActive: $navigateToNext) {
                WeightLossSpeedView(desiredWeight: desiredWeight, currentWeight: currentWeight)
                    .horizontalSlideTransition()
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .simultaneousGesture(TapGesture().onEnded {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                coordinator.nextStep()
                navigateToNext = true
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
    }
}

// Weight Loss Speed View
struct WeightLossSpeedView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @ObservedObject var onboardingData = OnboardingDataManager.shared
    let desiredWeight: Double
    let currentWeight: Double
    @State private var weightLossSpeed: Double = 1.0
    @State private var navigateToComparison = false
    
    var timeToGoal: String {
        let newFoodsPerMonth = weightLossSpeed * 4.0
        return "\(Int(desiredWeight)) new foods in \(Int(ceil(desiredWeight / newFoodsPerMonth))) months"
    }
    
    var dailyCalories: Int {
        // Calorie calculation adapts based on fitness goal
        let isGaining = onboardingData.fitnessGoal == "Gain weight" || onboardingData.fitnessGoal == "gain_weight"
        let isMaintaining = onboardingData.fitnessGoal == "Maintain" || onboardingData.fitnessGoal == "maintain"
        
        if isMaintaining {
            // Maintenance calories
            return 2000
        } else if isGaining {
            // Weight gain requires calorie surplus
            if weightLossSpeed <= 0.5 {
                return 2200  // Slow gain
            } else if weightLossSpeed <= 1.0 {
                return 2500  // Moderate gain
            } else {
                return 2800  // Fast gain
            }
        } else {
            // Weight loss requires calorie deficit
            if weightLossSpeed <= 0.5 {
                return 1800  // Slow loss
            } else if weightLossSpeed <= 1.0 {
                return 1387  // Moderate loss
            } else {
                return 1200  // Fast loss
            }
        }
    }
    
    var macroGoals: (protein: Int, carbs: Int, fats: Int) {
        // Calculate macros based on daily calories
        // 30% protein, 40% carbs, 30% fats
        let proteinCals = Double(dailyCalories) * 0.30
        let carbsCals = Double(dailyCalories) * 0.40
        let fatsCals = Double(dailyCalories) * 0.30
        
        return (
            protein: Int(proteinCals / 4), // 4 cal per gram
            carbs: Int(carbsCals / 4),     // 4 cal per gram
            fats: Int(fatsCals / 9)        // 9 cal per gram
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * (11.0/32.0), height: 2) // 11/32
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("How quickly do you\nwant to introduce\nnew foods?")
                    .font(.system(size: 32, weight: .bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            
            Spacer()
            
            // Introduction pace display
            VStack(spacing: 16) {
                Text("New foods per week")
                    .font(.system(size: 17))
                    .foregroundColor(.gray)
                
                Text(String(format: "%.1f foods", weightLossSpeed))
                    .font(.system(size: 48, weight: .bold))
                
                // Speed indicators
                HStack(spacing: 40) {
                    VStack(spacing: 8) {
                        Text("🐢")
                            .font(.system(size: 40))
                        Text("slow")
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                    }
                    
                    VStack(spacing: 8) {
                        Text("👶")
                            .font(.system(size: 40))
                        Text("recommended")
                            .font(.system(size: 15))
                            .foregroundColor(Color(red: 0.83, green: 0.69, blue: 0.52))
                    }
                    
                    VStack(spacing: 8) {
                        Text("🚀")
                            .font(.system(size: 40))
                        Text("fast")
                            .font(.system(size: 15))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 20)
            }
            .padding(.horizontal, 24)
            
            // Slider
            Slider(value: $weightLossSpeed, in: 0.5...2.0, step: 0.1)
                .accentColor(.black)
                .padding(.horizontal, 24)
                .padding(.top, 40)
            
            // Goal info
            VStack(spacing: 8) {
                Text("Your baby will try ")
                    .font(.system(size: 17))
                    .foregroundColor(.black)
                + Text(timeToGoal)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(red: 0.83, green: 0.69, blue: 0.52))
                
                Text("Pediatricians recommend introducing one new food every 3–5 days to watch for reactions.")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
            
            // Continue button
            NavigationLink(isActive: $navigateToComparison) {
                ThriftingTransitionView()
                    .horizontalSlideTransition()
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .simultaneousGesture(TapGesture().onEnded {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                coordinator.nextStep()
                
                // Save weight loss speed to onboarding data
                onboardingData.weightLossSpeed = weightLossSpeed
                
                // Generate and save nutrition goals using actual user data
                let goals = onboardingData.generateNutritionGoals()
                FoodDataManager.shared.saveNutritionGoals(goals)
                print("✅ Saved personalized nutrition goals based on user data:")
                print("   📊 Daily calories: \(goals.dailyCalories) cal")
                print("   🥩 Protein: \(goals.protein)g")
                print("   🍞 Carbs: \(goals.carbs)g")
                print("   🥑 Fats: \(goals.fats)g")
                print("   ⚖️ Current weight: \(goals.currentWeight) lbs")
                print("   🎯 Target weight: \(goals.targetWeight) lbs")
                
                navigateToComparison = true
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
    }
}

// Cal AI Comparison View
struct CalAIComparisonView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var navigateToObstacles = false
    @State private var showBars = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * (12.0/32.0), height: 2) // 12/32
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("Lose twice as much weight with Cal AI vs on your own")
                    .font(.system(size: 32, weight: .bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            
            Spacer()
            
            // Comparison chart
            HStack(spacing: 40) {
                // Without Cal AI
                VStack(spacing: 16) {
                    Text("Without\nCal AI")
                        .font(.system(size: 17, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.black)
                    
                    VStack {
                        Spacer()
                        Text("20%")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.gray)
                            .opacity(showBars ? 1 : 0)
                    }
                    .frame(width: 100, height: showBars ? 80 : 0)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
                
                // With Cal AI
                VStack(spacing: 16) {
                    Text("With\nCal AI")
                        .font(.system(size: 17, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                    
                    VStack {
                        Spacer()
                        Text("2X")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.bottom, 20)
                            .opacity(showBars ? 1 : 0)
                    }
                    .frame(width: 100, height: showBars ? 200 : 0)
                    .background(Color.black)
                    .cornerRadius(16)
                }
            }
            .padding(.horizontal, 24)
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7, blendDuration: 0)) {
                    showBars = true
                }
            }
            
            // Description
            Text("Cal AI makes it easy and holds you accountable.")
                .font(.system(size: 17))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 40)
            
            Spacer()
            
            // Continue button
            NavigationLink(isActive: $navigateToObstacles) {
                ReachingGoalsObstaclesView()
                    .horizontalSlideTransition()
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .simultaneousGesture(TapGesture().onEnded {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                coordinator.nextStep()
                navigateToObstacles = true
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
    }
}

// Reaching Goals Obstacles View
struct ReachingGoalsObstaclesView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var selectedObstacles: Set<String> = []
    @State private var navigateToDiet = false
    
    let obstacles = [
        ("obstacle_lack_consistency", "chart.bar"),
        ("obstacle_unhealthy_eating", "fork.knife"),
        ("obstacle_lack_support", "diamond"),
        ("obstacle_busy_schedule", "calendar"),
        ("obstacle_lack_meal_inspiration", "lightbulb")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * (13.0/32.0), height: 2) // 13/32
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("What's stopping you from reaching your goals?")
                    .font(.system(size: 32, weight: .bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            
            // Obstacles list
            VStack(spacing: 16) {
                ForEach(obstacles, id: \.0) { obstacle, icon in
                    Button(action: {
                        if selectedObstacles.contains(obstacle) {
                            selectedObstacles.remove(obstacle)
                        } else {
                            selectedObstacles.insert(obstacle)
                        }
                        coordinator.trackQuestionAnswered(answer: obstacle)
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: icon)
                                .font(.system(size: 20))
                                .frame(width: 24)
                            Text(LocalizedStringKey(obstacle))
                                .font(.system(size: 17))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(selectedObstacles.contains(obstacle) ? Color.black : Color(.systemGray6))
                        .foregroundColor(selectedObstacles.contains(obstacle) ? .white : .black)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            
            Spacer()
            
            // Continue button
            NavigationLink(isActive: $navigateToDiet) {
                SpecificDietView()
                    .horizontalSlideTransition()
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(!selectedObstacles.isEmpty ? Color.black : Color(.systemGray5))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(selectedObstacles.isEmpty)
            .simultaneousGesture(TapGesture().onEnded {
                if !selectedObstacles.isEmpty {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    coordinator.nextStep()
                    navigateToDiet = true
                }
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
    }
}

// Specific Diet View
struct SpecificDietView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var selectedDiet: String?
    @State private var navigateToNext = false
    
    let diets = [
        ("Classic", "🍴"),
        ("Pescatarian", "🐟"),
        ("Vegetarian", "🥕"),
        ("Vegan", "🌱")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * (14.0/32.0), height: 2) // 14/32
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("Do you follow a specific diet?")
                    .font(.system(size: 32, weight: .bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            
            Spacer()
            
            // Diet options
            VStack(spacing: 16) {
                ForEach(diets, id: \.0) { diet, emoji in
                    Button(action: {
                        selectedDiet = diet
                        coordinator.trackQuestionAnswered(answer: diet)
                    }) {
                        HStack(spacing: 12) {
                            Text(emoji)
                                .font(.system(size: 24))
                            Text(diet)
                                .font(.system(size: 17, weight: .medium))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(selectedDiet == diet ? Color.black : Color(.systemGray6))
                        .foregroundColor(selectedDiet == diet ? .white : .black)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Continue button
            NavigationLink(isActive: $navigateToNext) {
                AccomplishmentView()
                    .horizontalSlideTransition()
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedDiet != nil ? Color.black : Color(.systemGray5))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(selectedDiet == nil)
            .simultaneousGesture(TapGesture().onEnded {
                if selectedDiet != nil {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    coordinator.nextStep()
                    navigateToNext = true
                }
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
    }
}

// Accomplishment View
struct AccomplishmentView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var selectedAccomplishment: String?
    @State private var navigateToPotential = false
    
    let accomplishments = [
        ("Eat and live healthier", "applelogo"),
        ("Boost my energy and mood", "sun.max"),
        ("Stay motivated and consistent", "flame"),
        ("Feel better about my body", "figure.walk")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * (15.0/32.0), height: 2) // 15/32
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("What would you like to accomplish?")
                    .font(.system(size: 32, weight: .bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            
            Spacer()
            
            // Accomplishment options
            VStack(spacing: 16) {
                ForEach(accomplishments, id: \.0) { accomplishment, icon in
                    Button(action: {
                        selectedAccomplishment = accomplishment
                        coordinator.trackQuestionAnswered(answer: accomplishment)
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: icon)
                                .font(.system(size: 20))
                                .frame(width: 24)
                            Text(accomplishment)
                                .font(.system(size: 17))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(selectedAccomplishment == accomplishment ? Color.black : Color(.systemGray6))
                        .foregroundColor(selectedAccomplishment == accomplishment ? .white : .black)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Continue button
            NavigationLink(isActive: $navigateToPotential) {
                ProgressGraphView()
                    .horizontalSlideTransition()
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedAccomplishment != nil ? Color.black : Color(.systemGray5))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(selectedAccomplishment == nil)
            .simultaneousGesture(TapGesture().onEnded {
                if selectedAccomplishment != nil {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    coordinator.nextStep()
                    navigateToPotential = true
                }
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
    }
}


// Onboarding Coordinator to manage flow and progress
class OnboardingCoordinator: ObservableObject {
    @Published var currentStep: Int = 0
    @Published var totalSteps: Int = 34 // Total number of onboarding steps (all Cal AI screens including custom plan and loading)
    
    // Track step timing for analytics
    private var stepStartTime: Date?
    private var onboardingStartTime: Date?
    
    let steps = [
        "Choose your Gender",
        "How many meals do you eat out per week?", 
        "Have you tried other calorie tracking apps?", 
        "Cal AI creates long-term results",
        "Height & weight",
        "When were you born?",
        "Do you currently work with a personal coach or nutritionist?",
        "What is your goal?",
        "What is your desired weight?",
        "Weight target result",
        "How fast do you want to reach your goal?",
        "Cal AI comparison chart",
        "What's stopping you from reaching your goals?",
        "Do you follow a specific diet?",
        "What would you like to accomplish?",
        "You have great potential to crush your goal",
        "Thank you for trusting us",
        "Give us a rating",
        "Time to generate your custom plan",
        "Setting up your plan",
        "Real-Time Marketplace Data",
        "Do you have a specific eating style?",
        "What are you struggling with?",
        "Goal Confirmation",
        "AI Powered Nutrition Analysis",
        "Cal AI Comparison",
        "What's stopping you from reaching your goals?",
        "What is your ultimate goal?",
        "You have great potential to crush your goal",
        "Thank you for trusting us",
        "Give us rating",
        "Your Custom Plan",
        "Setting up your profile...",
        "Final Congratulations",
        "Plan Summary",
        "Subscription"
    ]
    
    var progress: Double {
        return Double(currentStep + 1) / Double(totalSteps)
    }
    
    // Initialize tracking when onboarding starts
    func startOnboarding() {
        onboardingStartTime = Date()
        stepStartTime = Date()
        MixpanelService.shared.trackOnboardingStarted()
        // FacebookPixelService.shared.trackOnboardingStarted()
        trackStepViewed()
    }
    
    func nextStep() {
        // Track completion of current step
        trackStepCompleted()
        
        if currentStep < totalSteps - 1 {
            currentStep += 1
            stepStartTime = Date() // Start timing the new step
            trackStepViewed()
        } else {
            // Onboarding completed
            trackOnboardingCompleted()
        }
    }
    
    func previousStep() {
        if currentStep > 0 {
            currentStep -= 1
            stepStartTime = Date() // Reset timing for the previous step
            trackStepViewed()
        }
    }
    
    func trackDropoff() {
        let timeSpent = stepStartTime?.timeIntervalSinceNow.magnitude
        MixpanelService.shared.trackOnboardingDropoff(
            step: currentStep,
            stepName: getCurrentStepName(),
            timeSpent: timeSpent
        )
    }
    
    // MARK: - Private Analytics Methods
    private func trackStepViewed() {
        let questionTitle = getCurrentStepName()
        
        // Only track question-specific event (no duplicates)
        MixpanelService.shared.trackQuestionViewed(
            questionTitle: questionTitle,
            stepNumber: currentStep
        )
    }
    
    private func trackStepCompleted() {
        // Don't track step completion separately since we track question answers
        // This reduces duplicate events
    }
    
    // Public method to track when a question is viewed
    func trackQuestionViewed(questionTitle: String, stepNumber: Int) {
        let timeSpent = stepStartTime?.timeIntervalSinceNow.magnitude
        MixpanelService.shared.trackQuestionViewed(
            questionTitle: questionTitle,
            stepNumber: stepNumber,
            timeSpent: timeSpent
        )
    }
    
    // New method to track when user answers a specific question
    func trackQuestionAnswered(answer: String) {
        let timeSpent = stepStartTime?.timeIntervalSinceNow.magnitude
        let questionTitle = getCurrentStepName()
        
        MixpanelService.shared.trackQuestionAnswered(
            questionTitle: questionTitle,
            answer: answer,
            stepNumber: currentStep,
            timeSpent: timeSpent
        )
    }
    
    private func trackOnboardingCompleted() {
        let totalTime = onboardingStartTime?.timeIntervalSinceNow.magnitude ?? 0
        MixpanelService.shared.trackOnboardingCompleted(totalTime: totalTime)
        // FacebookPixelService.shared.trackOnboardingCompleted(totalTime: totalTime, stepsCompleted: currentStep + 1)
    }
    
    private func getCurrentStepName() -> String {
        guard currentStep < steps.count else { return "Unknown" }
        return steps[currentStep]
    }
}

// Onboarding Data Manager to store user's answers
class OnboardingDataManager: ObservableObject {
    static let shared = OnboardingDataManager()
    
    // User's physical data
    @Published var gender: String = "Male"
    @Published var heightFeet: Int = 5
    @Published var heightInches: Int = 4
    @Published var heightCm: Int = 165
    @Published var isImperial: Bool = true
    @Published var weightLbs: Double = 148.0
    @Published var weightKg: Double = 67.0
    @Published var birthMonth: Int = 0  // January
    @Published var birthDay: Int = 0    // 1st
    @Published var birthYear: Int = 25  // 1999 (offset from 1974)
    
    // User's goals
    @Published var fitnessGoal: String = "Lose weight"  // "Lose weight", "Maintain", "Gain weight"
    @Published var desiredWeightLbs: Double = 135.0
    @Published var desiredWeightKg: Double = 61.0
    @Published var weightLossSpeed: Double = 1.0  // lbs per week
    
    // Other preferences
    @Published var hasPersonalCoach: Bool = false
    @Published var dietType: String = "None"
    @Published var obstacles: Set<String> = []
    
    private init() {}
    
    // Calculate age from birth data
    func calculateAge() -> Int {
        let calendar = Calendar.current
        let birthYearActual = 1974 + birthYear
        let birthDate = DateComponents(year: birthYearActual, month: birthMonth + 1, day: birthDay + 1)
        
        if let date = calendar.date(from: birthDate) {
            let ageComponents = calendar.dateComponents([.year], from: date, to: Date())
            return ageComponents.year ?? 25
        }
        return 25
    }
    
    // Calculate height in inches
    func getHeightInInches() -> Double {
        if isImperial {
            return Double(heightFeet * 12 + heightInches)
        } else {
            return Double(heightCm) / 2.54  // Convert cm to inches
        }
    }
    
    // Get current weight in lbs
    func getCurrentWeightLbs() -> Double {
        return isImperial ? weightLbs : weightKg * 2.20462
    }
    
    // Get target weight in lbs
    func getTargetWeightLbs() -> Double {
        return isImperial ? desiredWeightLbs : desiredWeightKg * 2.20462
    }
    
    // Calculate BMR using Mifflin-St Jeor Equation
    func calculateBMR() -> Double {
        let weightKg = getCurrentWeightLbs() / 2.20462
        let heightCm = getHeightInInches() * 2.54
        let age = Double(calculateAge())
        
        // BMR formula: 10 * weight(kg) + 6.25 * height(cm) - 5 * age + s
        // s = +5 for males, -161 for females
        let s = (gender == "Male") ? 5.0 : -161.0
        let bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + s
        
        return bmr
    }
    
    // Calculate TDEE (Total Daily Energy Expenditure)
    func calculateTDEE() -> Double {
        let bmr = calculateBMR()
        // Using moderate activity level (1.55) as default
        // You can make this customizable based on activity level question
        let activityMultiplier = 1.55
        return bmr * activityMultiplier
    }
    
    // Calculate daily calorie target based on goal
    func calculateDailyCalories() -> Int {
        let tdee = calculateTDEE()
        var calorieAdjustment = 0.0
        
        // Handle both localized keys and English strings for backwards compatibility
        switch fitnessGoal {
        case "Lose weight", "lose_weight":
            // 500 calorie deficit per day = 1 lb per week
            calorieAdjustment = -500.0 * weightLossSpeed
        case "Gain weight", "gain_weight":
            // 500 calorie surplus per day = 1 lb per week
            calorieAdjustment = 500.0 * weightLossSpeed
        case "Maintain", "maintain":
            calorieAdjustment = 0.0
        default:
            calorieAdjustment = 0.0
        }
        
        let targetCalories = tdee + calorieAdjustment
        // Ensure minimum of 1200 calories for safety
        return max(1200, Int(targetCalories))
    }
    
    // Calculate macros (protein, carbs, fats)
    func calculateMacros() -> (protein: Int, carbs: Int, fats: Int) {
        let dailyCalories = calculateDailyCalories()
        let weightLbs = getCurrentWeightLbs()
        
        // Protein: 0.8-1.0g per lb of body weight
        let proteinGrams = Int(weightLbs * 0.9)
        let proteinCalories = proteinGrams * 4
        
        // Fat: 25-30% of total calories
        let fatCaloriesRatio = 0.27
        let fatCalories = Int(Double(dailyCalories) * fatCaloriesRatio)
        let fatGrams = fatCalories / 9
        
        // Carbs: remaining calories
        let remainingCalories = dailyCalories - proteinCalories - fatCalories
        let carbGrams = max(0, remainingCalories / 4)
        
        return (protein: proteinGrams, carbs: carbGrams, fats: fatGrams)
    }
    
    // Generate complete nutrition goals
    func generateNutritionGoals() -> NutritionGoals {
        let dailyCalories = calculateDailyCalories()
        let macros = calculateMacros()
        let currentWeight = getCurrentWeightLbs()
        let targetWeight = getTargetWeightLbs()
        
        // Calculate fiber goal based on calories (14g per 1000 calories)
        let fiberGoal = Int((Double(dailyCalories) / 1000.0) * 14.0)
        
        // Sugar goal: max 10% of daily calories (WHO recommendation)
        let sugarGoal = Int(Double(dailyCalories) * 0.10 / 4) // divide by 4 for grams
        
        // Sodium: standard 2300mg recommendation
        let sodiumGoal = 2300
        
        return NutritionGoals(
            dailyCalories: dailyCalories,
            protein: macros.protein,
            carbs: macros.carbs,
            fats: macros.fats,
            fiber: fiberGoal,
            sugar: sugarGoal,
            sodium: sodiumGoal,
            currentWeight: currentWeight,
            targetWeight: targetWeight,
            weightLossSpeed: weightLossSpeed
        )
    }
    
    // Reset all data
    func reset() {
        gender = "Male"
        heightFeet = 5
        heightInches = 4
        heightCm = 165
        isImperial = true
        weightLbs = 148.0
        weightKg = 67.0
        birthMonth = 0
        birthDay = 0
        birthYear = 25
        fitnessGoal = "Lose weight"
        desiredWeightLbs = 135.0
        desiredWeightKg = 61.0
        weightLossSpeed = 1.0
        hasPersonalCoach = false
        dietType = "None"
        obstacles = []
    }
}

// Gender Selection View
struct GenderSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @ObservedObject var onboardingData = OnboardingDataManager.shared
    @State private var selectedGender: String?
    @State private var navigateToFrequency = false
    
    let genders = ["First-time parent", "Second child", "Third child or more"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * (1.0/34.0), height: 2)
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Title and subtitle
            VStack(alignment: .leading, spacing: 8) {
                Text("Is this your first time\nintroducing solids?")
                    .font(.system(size: 32, weight: .bold))
                Text("We'll personalize your baby's feeding journey.")
                    .font(.system(size: 17))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            
            // Gender options
            VStack(spacing: 16) {
                ForEach(genders, id: \.self) { gender in
                    Button(action: { 
                        selectedGender = gender
                        coordinator.trackQuestionAnswered(answer: gender)
                    }) {
                        Text(gender)
                            .font(.system(size: 17, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(selectedGender == gender ? Color.black : Color(.systemGray6))
                            .foregroundColor(selectedGender == gender ? .white : .black)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            
            Spacer()
            
            // Continue button
            NavigationLink(isActive: $navigateToFrequency) {
                SongFrequencyView()
                    .horizontalSlideTransition()
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedGender != nil ? Color.black : Color(.systemGray5))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(selectedGender == nil)
            .simultaneousGesture(TapGesture().onEnded {
                if let gender = selectedGender {
                    // Save gender to onboarding data
                    onboardingData.gender = gender
                    coordinator.nextStep()
                    navigateToFrequency = true
                }
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .navigationBarHidden(true)
        .background(Color.white.edgesIgnoringSafeArea(.all))
    }
}

// Update SongFrequencyView to include navigation
struct SongFrequencyView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var selectedFrequency: String?
    @State private var navigateToResults = false
    
    let frequencies = [
        ("4–6 months", "Just starting to explore solids", "leaf.fill"),
        ("6–9 months", "Learning to eat purees & soft foods", "fork.knife"),
        ("9–12 months", "Ready for more textures & finger foods", "star.fill")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * (2.0/34.0), height: 2) // 2/34
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Title and subtitle
            VStack(alignment: .leading, spacing: 8) {
                Text("How old is your baby?")
                    .font(.system(size: 32, weight: .bold))
                Text("We'll tailor food recommendations to your baby's stage.")
                    .font(.system(size: 17))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            
            // Frequency options
            VStack(spacing: 16) {
                ForEach(frequencies, id: \.0) { frequency, descriptionKey, icon in
                    Button(action: { 
                        selectedFrequency = frequency
                        // Track question-specific answer
                        coordinator.trackQuestionAnswered(answer: frequency)
                    }) {
                        HStack {
                            Image(systemName: icon)
                                .font(.system(size: 24))
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(frequency)
                                    .font(.system(size: 17))
                                Text(LocalizedStringKey(descriptionKey))
                                    .font(.system(size: 15))
                                    .foregroundColor(selectedFrequency == frequency ? .white.opacity(0.7) : .gray)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                        .frame(height: 72)
                        .background(selectedFrequency == frequency ? Color.black : Color(.systemGray6))
                        .foregroundColor(selectedFrequency == frequency ? .white : .black)
                        .clipShape(
                        RoundedCorner(radius: 16, corners: [.topLeft, .topRight, .bottomLeft, .bottomRight])
                    )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            
            Spacer()
            
            // Continue button
            NavigationLink(isActive: $navigateToResults) {
                TriedOtherAppsView()
                    .horizontalSlideTransition()
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedFrequency != nil ? Color.black : Color(.systemGray5))
                    .foregroundColor(selectedFrequency != nil ? .white : Color(.systemGray2))
                    .cornerRadius(28)
            }
            .disabled(selectedFrequency == nil)
            .simultaneousGesture(TapGesture().onEnded {
                if selectedFrequency != nil {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    coordinator.nextStep()
                    navigateToResults = true
                }
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
        .onAppear {
            coordinator.currentStep = 0
        }
    }
}

// Tried Other Apps View
struct TriedOtherAppsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var selectedAnswer: String?
    @State private var navigateToResults = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * (3.0/34.0), height: 2) // 3/34
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("Has your baby started\nsolid foods yet?")
                    .font(.system(size: 32, weight: .bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            
            Spacer()
            
            // Answer options
            VStack(spacing: 16) {
                // Yes button
                Button(action: { 
                    selectedAnswer = "Yes"
                    coordinator.trackQuestionAnswered(answer: "Yes")
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                        Text("Yes, we've started")
                            .font(.system(size: 17, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedAnswer == "Yes" ? Color.black : Color(.systemGray6))
                    .foregroundColor(selectedAnswer == "Yes" ? .white : .black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.clear, lineWidth: 0)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                
                // No button
                Button(action: { 
                    selectedAnswer = "No"
                    coordinator.trackQuestionAnswered(answer: "No")
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 24))
                        Text("Not yet, getting ready")
                            .font(.system(size: 17, weight: .medium))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedAnswer == "No" ? Color.black : Color(.systemGray6))
                    .foregroundColor(selectedAnswer == "No" ? .white : .black)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Continue button
            NavigationLink(isActive: $navigateToResults) {
                LongTermResultsView()
                    .horizontalSlideTransition()
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(selectedAnswer != nil ? Color.black : Color(.systemGray5))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(selectedAnswer == nil)
            .simultaneousGesture(TapGesture().onEnded {
                if selectedAnswer != nil {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    coordinator.nextStep()
                    navigateToResults = true
                }
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
    }
}

// Central blush emoji with wiggle animation
struct WiggleBlushEmoji: View {
    @State private var offsetX: CGFloat = 0
    @State private var offsetY: CGFloat = 0
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0
    
    var body: some View {
        Text("😊")
            .font(.system(size: 32))
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .offset(x: offsetX, y: offsetY)
            .onAppear {
                // Horizontal wiggle
                withAnimation(
                    .easeInOut(duration: 2.5)
                    .repeatForever(autoreverses: true)
                ) {
                    offsetX = 8
                }
                
                // Vertical wiggle (different timing)
                withAnimation(
                    .easeInOut(duration: 3.2)
                    .repeatForever(autoreverses: true)
                ) {
                    offsetY = 6
                }
                
                // Gentle scale animation
                withAnimation(
                    .easeInOut(duration: 2.8)
                    .repeatForever(autoreverses: true)
                ) {
                    scale = 1.15
        }
                
                // Subtle rotation wiggle
            withAnimation(
                    .easeInOut(duration: 4.0)
                .repeatForever(autoreverses: true)
            ) {
                    rotation = 8
            }
        }
    }
}

struct CustomPlanView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var showContent = false
    @State private var animationProgress: CGFloat = 0
    @State private var navigateToNext = false
    @State private var gradientRotation: Double = 0
    @State private var isAnimationComplete = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 16))
                        )
                }
                
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 2)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .opacity(showContent ? 1 : 0)
            .animation(.easeOut(duration: 0.6).delay(0.3), value: showContent)
            
            Spacer()
            
            // Animated Circle with Gradient and Emojis
            ZStack {
                // Animated gradient background circle
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.95, green: 0.9, blue: 1.0),
                                Color(red: 0.9, green: 0.95, blue: 1.0),
                                Color(red: 0.85, green: 0.9, blue: 0.95),
                                Color(red: 0.95, green: 0.9, blue: 1.0)
                            ]),
                            center: .center,
                            startAngle: .degrees(gradientRotation),
                            endAngle: .degrees(gradientRotation + 360)
                        )
                    )
                    .frame(width: 200, height: 200)
                    .scaleEffect(showContent ? 1 : 0.5)
                    .opacity(showContent ? 1 : 0)
                
                // Dots around the circle
                ForEach(0..<12) { index in
                    Circle()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: 4, height: 4)
                        .offset(y: -90)
                        .rotationEffect(.degrees(Double(index) * 30))
                        .opacity(showContent ? 1 : 0)
                }
                
                // Central wiggling blush emoji
                WiggleBlushEmoji()
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.8), value: showContent)
            }
            .padding(.bottom, 60)
            
            // "All done!" badge
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(red: 0.83, green: 0.69, blue: 0.52))
                    .font(.system(size: 18))
                
                Text("All done!")
                    .font(.system(size: 17, weight: .medium))
            }
            .padding(.top, 32)
            .opacity(showContent ? 1 : 0)
            .animation(.easeOut(duration: 0.6).delay(0.6), value: showContent)
            
            // Title
            Text("Time to generate your custom plan!")
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.8), value: showContent)
            
            Spacer()
            
            // Continue button
            NavigationLink(isActive: $navigateToNext) {
                LoadingView()
                    .horizontalSlideTransition()
            } label: {
                Text("continue")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .simultaneousGesture(TapGesture().onEnded {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                coordinator.nextStep()
                navigateToNext = true
            })
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .opacity(showContent ? 1 : 0)
            .animation(.easeOut(duration: 0.6).delay(1.0), value: showContent)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
        .onAppear {
            coordinator.currentStep = 19
            // Start the animations sequence
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showContent = true
            }
            
            // Rotate gradient continuously
            withAnimation(
                .linear(duration: 10)
                .repeatForever(autoreverses: false)
            ) {
                gradientRotation = 360
            }
            
            // Enable continue button after animations complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                isAnimationComplete = true
            }
        }
    }
}

// MARK: - Google Maps View (DISABLED - Removed GoogleMaps dependency)
/* Commented out to remove GoogleMaps dependency
struct GoogleMapsView: UIViewRepresentable {
    @ObservedObject var mapService: ThriftStoreMapService
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject var mapController: MapViewController
    
    func makeUIView(context: Context) -> GMSMapView {
        print("🗺️ Creating Google Maps view...")
        
        // Create map view with default frame - SwiftUI will handle sizing
        let mapView = GMSMapView()
        mapView.delegate = context.coordinator
        
        // Configure map settings
        mapView.settings.compassButton = false // We have custom zoom controls
        mapView.settings.myLocationButton = false // We have custom location tracking
        mapView.isMyLocationEnabled = true
        mapView.settings.scrollGestures = true
        mapView.settings.zoomGestures = true
        mapView.settings.tiltGestures = false
        mapView.settings.rotateGestures = false
        
        // Configure map appearance
        mapView.mapType = .normal
        mapView.isBuildingsEnabled = true
        mapView.isTrafficEnabled = false
        mapView.isIndoorEnabled = false
        
        // Add custom map style to hide street names and labels
        let styleJSON = """
        [
          {
            "featureType": "all",
            "elementType": "labels.text",
            "stylers": [
              {
                "visibility": "off"
              }
            ]
          },
          {
            "featureType": "road",
            "elementType": "labels",
            "stylers": [
              {
                "visibility": "off"
              }
            ]
          },
          {
            "featureType": "poi",
            "elementType": "labels",
            "stylers": [
              {
                "visibility": "off"
              }
            ]
          },
          {
            "featureType": "transit",
            "elementType": "labels",
            "stylers": [
              {
                "visibility": "off"
              }
            ]
          }
        ]
        """
        
        if let style = try? GMSMapStyle(jsonString: styleJSON) {
            mapView.mapStyle = style
            print("🗺️ Applied custom map style to hide labels")
        } else {
            print("⚠️ Failed to apply custom map style")
        }
        
        // Set initial camera position
        let defaultLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // San Francisco
        let initialLocation = locationManager.location?.coordinate ?? defaultLocation
        
            let camera = GMSCameraPosition.camera(
                withLatitude: initialLocation.latitude,
                longitude: initialLocation.longitude,
                zoom: 12.0
            )
            mapView.camera = camera
        
        print("📍 Initial map location set to: \(initialLocation)")
        
        // Setup coordinator with map view
        context.coordinator.setup(mapView: mapView)
        
        return mapView
    }
    
    func updateUIView(_ mapView: GMSMapView, context: Context) {
        // Update store markers
        context.coordinator.updateStores(stores: mapService.thriftStores)
        
        // Update user location if available and trigger search if needed
        if let location = locationManager.location {
            context.coordinator.updateUserLocation(location: location, mapView: mapView)
            
            // If we haven't searched for stores yet and now have location, search now
            if mapService.thriftStores.isEmpty && !context.coordinator.hasSearchedForStores {
                print("🔍 Location now available - searching for thrift stores...")
                context.coordinator.hasSearchedForStores = true
                Task {
                    await mapService.searchNearbyThriftStores(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapsView
        var mapView: GMSMapView?
        var markers: [GMSMarker] = []
        var hasInitializedLocation = false
        var hasSearchedForStores = false
        
        init(_ parent: GoogleMapsView) {
            self.parent = parent
            super.init()
        }
        
        func setup(mapView: GMSMapView) {
            self.mapView = mapView
            parent.mapController.setMapView(mapView)
            
            // Start location tracking
            parent.locationManager.startLocationTracking()
            
            // Load nearby stores if location is available immediately
            if let location = parent.locationManager.location {
                performInitialSearch(location: location)
            } else {
                // Set up a timer to retry getting location periodically
                setupLocationRetryTimer()
            }
        }
        
        private func performInitialSearch(location: CLLocation) {
            guard !hasSearchedForStores else { return }
            hasSearchedForStores = true
            
            Task {
                print("🔍 Performing initial search for thrift stores...")
                await parent.mapService.searchNearbyThriftStores(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            }
        }
        
        private func setupLocationRetryTimer() {
            // Reduced frequency: Check for location every 5 seconds for up to 15 seconds
            var attempts = 0
            Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { timer in
                attempts += 1
                
                if let location = self.parent.locationManager.location {
                    self.performInitialSearch(location: location)
                    timer.invalidate()
                } else if attempts >= 3 { // Stop after 15 seconds (3 attempts * 5 seconds)
                    timer.invalidate()
                    print("❌ Failed to get location after 15 seconds, giving up")
                }
            }
        }
        
        func updateStores(stores: [ThriftStore]) {
            guard let mapView = mapView else { 
                print("❌ MapView not available for updating stores")
                return 
            }
            
            // Clear existing markers
            markers.forEach { $0.map = nil }
            markers.removeAll()
            
            // Add new markers
            for store in stores {
                let marker = GMSMarker()
                marker.position = CLLocationCoordinate2D(
                    latitude: store.latitude,
                    longitude: store.longitude
                )
                marker.title = store.title.lowercased() + " 🔗"
                marker.snippet = store.address
                marker.userData = store
                marker.map = mapView
                marker.icon = createCustomMarkerIcon(for: store)
                markers.append(marker)
            }
            
            print("🗺️ Updated Google Maps with \(stores.count) store markers")
            
            // If we have markers, adjust camera to show them
            if !markers.isEmpty && !hasInitializedLocation {
                var bounds = GMSCoordinateBounds()
                markers.forEach { marker in
                    bounds = bounds.includingCoordinate(marker.position)
                }
                
                let update = GMSCameraUpdate.fit(bounds, withPadding: 50.0)
                mapView.animate(with: update)
                print("📍 Adjusted camera to show all \(markers.count) store markers")
            }
        }
        
        func updateUserLocation(location: CLLocation, mapView: GMSMapView) {
            guard !hasInitializedLocation else { return }
            
            let camera = GMSCameraPosition.camera(
                withLatitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                zoom: 12.0
            )
            
            mapView.animate(to: camera)
            hasInitializedLocation = true
        }
        
        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            handleMarkerTap(marker: marker)
            return true
        }
        
        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            handleCoordinateTap(coordinate: coordinate, mapView: mapView)
        }
        
        private func handleMarkerTap(marker: GMSMarker) {
            guard let store = marker.userData as? ThriftStore,
                  !store.address.isEmpty else {
                print("❌ No valid store data found")
                return
            }
            
            // Track map interaction for consumption data
            // COMMENTED OUT - ConsumptionRequestService not needed for calorie tracking app
            // DispatchQueue.main.async {
            //     ConsumptionRequestService.shared.markSubscriptionAsUsed()
            //     ConsumptionRequestService.shared.trackMapInteraction(interactionType: "map_viewed")
            //     ConsumptionRequestService.shared.trackFeatureUsed("map_interaction")
            // }
            
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            UIPasteboard.general.string = store.address
            print("✅ Address copied to clipboard: \(store.address)")
            
            showCopyAlert(store: store)
        }
        
        private func handleCoordinateTap(coordinate: CLLocationCoordinate2D, mapView: GMSMapView) {
            let tapTolerance: Double = 0.001
            
            for marker in markers {
                let distance = abs(marker.position.latitude - coordinate.latitude) + 
                              abs(marker.position.longitude - coordinate.longitude)
                
                if distance < tapTolerance {
                    handleMarkerTap(marker: marker)
                    return
                }
            }
        }
        
        private func showCopyAlert(store: ThriftStore) {
            let alert = UIAlertController(
                title: "✨ Address Copied!",
                message: "\n\(store.title)\n\(store.address)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Got it!", style: .default))
            
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    
                    var topController = rootViewController
                    while let presented = topController.presentedViewController {
                        topController = presented
                    }
                    
                    topController.present(alert, animated: true)
                }
            }
        }
        
        private func createCustomMarkerIcon(for store: ThriftStore) -> UIImage {
            // Prepare text with emoji and lowercase
            let baseText = store.title.lowercased()
            let linkEmoji = " 🔗"
            let maxWidth: CGFloat = 200 // Maximum width for text
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.black
            ]
            
            // Check if text needs truncation
            let fullText = baseText + linkEmoji
            let fullTextSize = fullText.size(withAttributes: attributes)
            
            let finalText: String
            if fullTextSize.width > maxWidth {
                // Truncate and add ellipsis + emoji
                var truncatedText = baseText
                let ellipsisEmoji = "..." + linkEmoji
                let ellipsisSize = ellipsisEmoji.size(withAttributes: attributes)
                let availableWidth = maxWidth - ellipsisSize.width
                
                // Keep removing characters until it fits
                while truncatedText.size(withAttributes: attributes).width > availableWidth && !truncatedText.isEmpty {
                    truncatedText = String(truncatedText.dropLast())
                }
                finalText = truncatedText + ellipsisEmoji
            } else {
                finalText = fullText
            }
            
            // Calculate final text size and container dimensions
            let finalTextSize = finalText.size(withAttributes: attributes)
            let padding: CGFloat = 8 // Tighter padding on left/right
            let containerWidth = finalTextSize.width + (padding * 2)
            let containerHeight: CGFloat = 32
            let totalHeight: CGFloat = 48 // More space for pin to prevent cropping
            
            let size = CGSize(width: containerWidth, height: totalHeight)
            let renderer = UIGraphicsImageRenderer(size: size)
            
            return renderer.image { context in
                let cgContext = context.cgContext
                
                // Create rounded rectangle with less rounded corners
                let backgroundRect = CGRect(x: 0, y: 0, width: containerWidth, height: containerHeight)
                let cornerRadius: CGFloat = 8.0 // Less rounded
                
                // Draw rounded rectangle background (no border)
                cgContext.setFillColor(UIColor.white.cgColor)
                let roundedPath = UIBezierPath(roundedRect: backgroundRect, cornerRadius: cornerRadius)
                cgContext.addPath(roundedPath.cgPath)
                cgContext.fillPath()
                
                // Draw text centered in container
                let textRect = CGRect(
                    x: padding,
                    y: (containerHeight - finalTextSize.height) / 2,
                    width: finalTextSize.width,
                    height: finalTextSize.height
                )
                
                finalText.draw(in: textRect, withAttributes: attributes)
                
                // Add iPhone pin emoji instead of gray rectangle
                let pinEmoji = "📍"
                let pinAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 16),
                    .foregroundColor: UIColor.black
                ]
                let pinSize = pinEmoji.size(withAttributes: pinAttributes)
                let pinRect = CGRect(
                    x: (containerWidth - pinSize.width) / 2,
                    y: containerHeight,
                    width: pinSize.width,
                    height: pinSize.height
                )
                
                pinEmoji.draw(in: pinRect, withAttributes: pinAttributes)
            }
        }
    }
}
*/
// End of commented out GoogleMapsView

// Modern Featured Post Card Component
struct FeaturedPostCard: View {
    let username: String
    let title: String
    let imageName: String
    let upvotes: Int
    let likes: Int
    
    var body: some View {
        VStack(spacing: 0) {
            // Post image as main content
            ZStack(alignment: .topLeading) {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 280)
                    .clipped()
                
                // Gradient overlay for text readability - only at top
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.6),
                        Color.clear
                    ]),
                    startPoint: .top,
                    endPoint: .center
                )
                
                // Top content
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        // User avatar
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(String(username.dropFirst().prefix(1).uppercased()))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                        
                        Text(username)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
                        
                        Spacer()
                    }
                }
                .padding(18)
            }
            
            // Bottom content area
            VStack(alignment: .leading, spacing: 8) {
                // Post title
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Upvote and like section
                HStack(spacing: 16) {
                    Button(action: {}) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.orange)
                            
                            Text("\(upvotes)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {}) {
                        HStack(spacing: 8) {
                            Image(systemName: "heart")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                            
                            Text("\(likes)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .background(Color.white)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.04), radius: 1, x: 0, y: 1)
    }
}

// Tinder-style Card Stack Component
struct TinderCardStack: View {
    @State private var cards: [CardData] = [
        CardData(id: 0, username: "u/deal_seeker22", title: "Goodwill bins haul - $12 investment, $340 profit this week! 🛍️", imageName: "goodwill-bins", upvotes: 198),
        CardData(id: 1, username: "u/luxe_hunter", title: "This Gucci bag from estate sale - paid $40, worth $850! 👜", imageName: "found-this-purse", upvotes: 289),
        CardData(id: 2, username: "u/retro_mike", title: "Found this Pokémon Blue at Goodwill for $3, sold for $85! 🎮", imageName: "pokemon", upvotes: 342),
        CardData(id: 3, username: "u/vintage_finds", title: "Toy lot from garage sale - $25 in, $280 out! 🧸", imageName: "toy-lot", upvotes: 234),
        CardData(id: 4, username: "u/sarah_thrifts", title: "Mid-century lamp for $8, sold for $120 on FB Marketplace 💡", imageName: "lamp-find", upvotes: 167)
    ]
    
    @State private var dragOffset = CGSize.zero
    @State private var dragRotation: Double = 0
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background cards (staggered)
            ForEach(0..<cards.count, id: \.self) { index in
                cardView(for: index)
            }
        }
    }
    
    private func cardView(for index: Int) -> some View {
        let card = cards[index]
        let isTopCard = index == cards.count - 1
        let cardIndex = cards.count - 1 - index
        
        // Cleaner staggering effects
        let scaleValue = isTopCard ? 1.0 : 1.0 - (Double(cardIndex) * 0.04)
        let xOffset = isTopCard ? dragOffset.width : CGFloat(cardIndex * -6)
        let yOffset = isTopCard ? dragOffset.height : CGFloat(cardIndex * 8)
        let rotation = isTopCard ? dragRotation : Double(cardIndex) * -1.5
        let opacityValue = cardIndex > 2 ? 0 : 1.0 - (Double(cardIndex) * 0.15)
        
        return FeaturedPostCard(
            username: card.username,
            title: card.title,
            imageName: card.imageName,
            upvotes: card.upvotes,
            likes: card.likes
        )
        .scaleEffect(scaleValue)
        .offset(x: xOffset, y: yOffset)
        .rotationEffect(.degrees(rotation))
        .opacity(opacityValue)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: dragOffset)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: cards.count) // Smoother card transitions
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: isTopCard) // Smooth scale/opacity transitions
        .gesture(isTopCard ? createDragGesture() : nil)
        .zIndex(isTopCard ? 100 : Double(index))
    }
    
    private func createDragGesture() -> some Gesture {
        DragGesture(minimumDistance: 20) // Increased minimum distance
            .onChanged { value in
                // Only respond to significantly horizontal drags (more than 2:1 ratio)
                if abs(value.translation.width) > abs(value.translation.height) * 2 {
                    dragOffset = value.translation
                    dragRotation = Double(value.translation.width / 10)
                }
            }
            .onEnded { value in
                // Only handle swipe if it's significantly horizontal
                if abs(value.translation.width) > abs(value.translation.height) * 2 {
                    handleDragEnd(value)
                } else {
                    // Reset if it was a vertical scroll
                    dragOffset = .zero
                    dragRotation = 0
                }
            }
    }
    
    private func handleDragEnd(_ value: DragGesture.Value) {
        // Prevent multiple simultaneous swipes
        guard !isAnimating else { return }
        
        let swipeThreshold: CGFloat = 100
        
        if abs(value.translation.width) > swipeThreshold {
            // Mark as animating to prevent multiple swipes
            isAnimating = true
            
            // Swipe away animation
            let direction: CGFloat = value.translation.width > 0 ? 1 : -1
            
            withAnimation(.easeOut(duration: 0.3)) {
                dragOffset = CGSize(width: direction * 500, height: value.translation.height)
                dragRotation = Double(direction * 20)
            }
            
            // Remove card after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                removeTopCard()
            }
        } else {
            // Snap back with animation
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                dragOffset = .zero
                dragRotation = 0
            }
        }
    }
    
    private func removeTopCard() {
        guard !cards.isEmpty else { return }
        
        let removedCard = cards.removeLast()
        
        // Reset drag state immediately to prevent double appearance
        dragOffset = .zero
        dragRotation = 0
        
        // Wait for the UI to settle before adding card back
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.none) {
                cards.insert(removedCard, at: 0)
            }
            
            // Reset animation state to allow next swipe
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isAnimating = false
            }
        }
    }
}

// Animated Info Bubble Component
struct InfoBubble: View {
    @Binding var showingInfo: Bool
    @State private var isPulsating = false
    
    var body: some View {
        Button(action: {
            showingInfo = true
        }) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.blue)
                .opacity(isPulsating ? 0.6 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isPulsating)
        }
        .onAppear {
            isPulsating = true
        }
    }
}

// Card Data Model
struct CardData: Identifiable {
    let id: Int
    let username: String
    let title: String
    let imageName: String
    let upvotes: Int
    let likes: Int
    
    init(id: Int, username: String, title: String, imageName: String, upvotes: Int) {
        self.id = id
        self.username = username
        self.title = title
        self.imageName = imageName
        self.upvotes = upvotes
        self.likes = Int.random(in: 15...89) // Random likes between 15-89
    }
}


// MARK: - Recent Finds Models
struct RecentFind: Identifiable, Codable {
    let id: UUID
    let name: String
    let category: String
    let estimatedValue: Double
    let condition: String
    let brand: String?
    let location: String // Store location
    let dateFound: Date
    let notes: String?
    let imageData: Data? // Captured image data
    
}

class RecentFindsManager: ObservableObject {
    @Published var recentFinds: [RecentFind] = []
    
    func addRecentFind(_ find: RecentFind) {
        recentFinds.insert(find, at: 0) // Add to beginning for recency
        saveFinds()
    }
    
    func saveFinds() {
        do {
            let encoded = try JSONEncoder().encode(recentFinds)
            UserDefaults.standard.set(encoded, forKey: "RecentFinds")
            print("💾 Successfully saved \(recentFinds.count) recent finds")
        } catch {
            print("❌ Failed to save recent finds: \(error)")
        }
    }
    
    init() {
        loadFinds()
        // Add sample data if empty
        if recentFinds.isEmpty {
            addSampleData()
        }
    }
    
    private func loadFinds() {
        guard let data = UserDefaults.standard.data(forKey: "RecentFinds") else {
            print("📂 No saved recent finds data found")
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode([RecentFind].self, from: data)
            recentFinds = decoded
            print("📂 Successfully loaded \(decoded.count) recent finds")
        } catch {
            print("❌ Failed to decode recent finds: \(error)")
            // Clear corrupted data and start fresh
            UserDefaults.standard.removeObject(forKey: "RecentFinds")
        }
    }
    
    private func addSampleData() {
        let sampleFinds = [
            RecentFind(
                id: UUID(),
                name: "Nike Air Jordan 1's - T-Scott",
                category: "Sneakers",
                estimatedValue: 215.00,
                condition: "8/10",
                brand: "Nike",
                location: "Goodwill",
                dateFound: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
                notes: "Size 10.5 - popular size, light creasing, OG all with box (missing lid), slight yellowing on midsole",
                imageData: nil
            ),
            RecentFind(
                id: UUID(),
                name: "Vintage Ecko Navy Blue Hoodie",
                category: "Clothing",
                estimatedValue: 85.00,
                condition: "8/10",
                brand: "Ecko Unltd",
                location: "Thrift Store",
                dateFound: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                notes: "Vintage Y2K style, navy blue with rhino logo, size XL",
                imageData: nil
            ),
            RecentFind(
                id: UUID(),
                name: "Coach Legacy Shoulder Bag",
                category: "Accessories",
                estimatedValue: 100.00,
                condition: "9/10",
                brand: "Coach",
                location: "Estate Sale",
                dateFound: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
                notes: "Model 9966 - discontinued style, black pebbled leather, silver hardware, dust bag included",
                imageData: nil
            ),
            RecentFind(
                id: UUID(),
                name: "Jordan 4 White Cement",
                category: "Sneakers",
                estimatedValue: 215.00,
                condition: "8/10",
                brand: "Nike",
                location: "Goodwill",
                dateFound: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                notes: "2016 release, size 10.5, OG all with box, light creasing, no major flaws",
                imageData: nil
            ),
            RecentFind(
                id: UUID(),
                name: "Vintage Levi's Denim Jacket",
                category: "Clothing",
                estimatedValue: 45.00,
                condition: "7/10",
                brand: "Levi's",
                location: "Garage Sale",
                dateFound: Calendar.current.date(byAdding: .day, value: -4, to: Date()) ?? Date(),
                notes: "Classic blue wash, size Large, some fading adds to vintage appeal",
                imageData: nil
            )
        ]
        
        recentFinds = sampleFinds
        saveFinds()
    }
}


struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var showingSignIn = false
    @State private var showingOnboarding = false
    @State private var navigateToTryForFree = false
    @State private var showLanguagePicker = false
    @State private var refreshID = UUID()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Language Toggle - Fixed at top
                HStack {
                    #if DEBUG
                    // Debug button — bypasses auth, onboarding, and paywall
                    Button(action: {
                        // Set onboarding first so the onChange(of: isLoggedIn)
                        // handler doesn't re-trigger the onboarding flow
                        authManager.hasCompletedOnboarding = true
                        authManager.hasCompletedSubscription = true
                        authManager.isLoggedIn = true
                        print("🐛 DEBUG: Jumped straight to main app")
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 13))
                            Text("Debug")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.2, green: 0.5, blue: 1.0))
                        .clipShape(Capsule())
                        .shadow(color: Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.4), radius: 6, x: 0, y: 3)
                    }
                    #endif
                    
                    Spacer()
                    
                    // Language Picker Button (right side)
                    Button(action: {
                        showLanguagePicker = true
                    }) {
                        HStack(spacing: 6) {
                            Text(languageManager.currentLanguage.flag)
                                .font(.system(size: 20))
                            Text(languageManager.currentLanguage.code.uppercased())
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 32)
                .background(Color.white)
                .zIndex(100)
                
                // Main Video (commented out — main.mp4 not in bundle yet)
                // MainVideoPlayer(videoName: "main")
                //     .frame(maxWidth: .infinity)
                //     .clipped()
                //     .padding(.bottom, 30)
                
                // Title Text
                Text("Tracking\nmade easy")
                    .font(.system(size: 42, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 40)
                
                Spacer()
                
                // Bottom Buttons
                VStack(spacing: 16) {
                    // Get Started - Static button
                    GetStartedButton(showingOnboarding: $showingOnboarding)
                    
                    // Only show sign in option if user is not logged in
                    if !authManager.isLoggedIn {
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .font(.system(size: 15))
                            Button(action: { showingSignIn = true }) {
                                Text("Sign In")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color.white)
            .ignoresSafeArea(.all, edges: .top)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: Binding(
            get: { showingSignIn && !authManager.isLoggedIn },
            set: { showingSignIn = $0 }
        )) {
            SignInView()
                .presentationDetents([.height(UIScreen.main.bounds.height * 0.52)])
                .presentationDragIndicator(.hidden)
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            NavigationView {
                // Show complete onboarding from start for logged-in users
                // or from SongFrequencyView for anonymous users
                if authManager.isLoggedIn {
                    GenderSelectionView()
                        .horizontalSlideTransition()
                        .onDisappear {
                            // Mark onboarding as completed when dismissed
                            if authManager.isLoggedIn {
                                authManager.markOnboardingCompleted()
                            }
                        }
                } else {
                    SongFrequencyView()
                        .horizontalSlideTransition()
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .preferredColorScheme(.light)
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerSheet()
        }
        .onChange(of: languageManager.currentLanguage) { _ in
            // Force view refresh when language changes
            refreshID = UUID()
        }
        .id(refreshID)
        .onChange(of: authManager.isLoggedIn) { isLoggedIn in
                if isLoggedIn {
                    // User became authenticated, dismiss any open sheets
                    showingSignIn = false
                    
                    // If user hasn't completed onboarding, show onboarding flow
                    if !authManager.hasCompletedOnboarding {
                        showingOnboarding = true
                    }
                }
            }
            .onAppear {
                // Check on app launch if user is already logged in but hasn't completed onboarding
                if authManager.isLoggedIn && !authManager.hasCompletedOnboarding {
                    showingOnboarding = true
                }
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// PaywallResumeView - Shows subscription screen directly when user returns to app
struct PaywallResumeView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    
    var body: some View {
        NavigationView {
            SubscriptionView()
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.light)
    }
}

// FirstTimeCongratsPopup - Shows congratulations popup for first-time users
struct FirstTimeCongratsPopup: View {
    @Binding var isPresented: Bool
    let onDismiss: () -> Void
    @State private var confettiTrigger = 0
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPopup()
                }
            
            // Popup content
            VStack(spacing: 20) {
                // Celebration emoji
                Text("🎉")
                    .font(.system(size: 60))
                    .scaleEffect(isPresented ? 1.2 : 1.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isPresented)
                
                // Title
                Text("Congrats on your 1-day streak!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                
                // Description
                Text("You've unlocked the Thrifty Map — your new shortcut to finding stores faster so you can profit with ease.")
                    .font(.system(size: 16))
                    .foregroundColor(.black.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                
                // Thanks button
                Button(action: {
                    dismissPopup()
                }) {
                    Text("Thanks!")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.black)
                        .cornerRadius(25)
                }
                .buttonStyle(PlainButtonStyle()) // Prevent default button style interference
                .contentShape(Rectangle()) // Ensure entire button area is tappable
                .padding(.top, 10)
            }
            .padding(30)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 40)
            .scaleEffect(isPresented ? 1.0 : 0.8)
            .opacity(isPresented ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isPresented)
        }
        .confettiCannon(
            trigger: $confettiTrigger,
            num: 35,
            colors: [.red, .yellow, .blue, .green, .purple, .pink, .orange, .cyan],
            confettiSize: 3.5,
            radius: 200
        )
        .onAppear {
            // Start confetti animation shortly after popup appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                confettiTrigger += 1
            }
        }
        .onChange(of: isPresented) { presented in
            if presented {
                // Start confetti when popup is presented
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    confettiTrigger += 1
                }
            }
        }
    }
    
    private func dismissPopup() {
        // Immediate haptic feedback for better user experience
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = false
        }
        // Reduced delay for faster response
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// Onboarding View for logged-in users who haven't completed onboarding
struct OnboardingView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var showingOnboarding = false
    
    var body: some View {
        NavigationView {
            GenderSelectionView()
                .horizontalSlideTransition()
            .onAppear {
                    // Start tracking when onboarding begins
                coordinator.startOnboarding()
            }
            .onDisappear {
                // Track dropoff if user exits onboarding early
                if !authManager.hasCompletedSubscription {
                    coordinator.trackDropoff()
                }
                // When onboarding is dismissed, mark it as completed
                authManager.markOnboardingCompleted()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.light)
    }
}

// Loading View with realistic progress animation
struct LoadingView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @ObservedObject var onboardingData = OnboardingDataManager.shared
    @State private var progress: CGFloat = 0.0
    @State private var progressText = "0%"
    @State private var statusText = "Initializing your profile..."
    @State private var showChecklist = false
    @State private var checkItems: [Bool] = [false, false, false, false, false]
    @State private var navigateToFinal = false
    
    let checklistItems = [
        "Food introduction schedule",
        "Allergen tracking",
        "Texture progression",
        "Nutrient balance",
        "Milestone plan"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 18))
                        )
                }
                
                // Progress bar
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: UIScreen.main.bounds.width * (20.0/34.0), height: 2) // 20/34
                    
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            Spacer()
            
            // Percentage
            Text(progressText)
                .font(.system(size: 80, weight: .bold))
                .padding(.bottom, 32)
            
            // Status text
            Text("setting_up_plan")
                .font(.system(size: 24, weight: .medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            
            // Progress bar
            VStack(spacing: 16) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        Rectangle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 1.0, green: 0.4, blue: 0.7), // Pink
                                    Color(red: 0.4, green: 0.6, blue: 1.0)  // Blue
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geometry.size.width * progress, height: 4)
                            .cornerRadius(2)
                    }
                }
                .frame(height: 4)
                
                Text(statusText)
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
            
            // Recommendations checklist
            VStack(alignment: .leading, spacing: 0) {
                Text("custom_profile_analysis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.leading, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                
                ForEach(Array(checklistItems.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Text("• \(item)")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if checkItems[index] {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
                .padding(.bottom, 20)
            }
            .background(Color.black)
            .cornerRadius(20)
            .padding(.horizontal, 24)
            .opacity(showChecklist ? 1 : 0)
            .animation(.easeOut(duration: 0.6), value: showChecklist)
            
            Spacer()
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
        .onAppear {
            coordinator.currentStep = 17
            MixpanelService.shared.trackQuestionViewed(questionTitle: "Setting up your profile...", stepNumber: 17)
            startLoadingSequence()
        }
        .background(
            NavigationLink(isActive: $navigateToFinal) {
                FinalCongratulationsView()
            } label: {
                EmptyView()
            }
            .hidden()
        )
    }
    
    private func startLoadingSequence() {
        // Show checklist
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showChecklist = true
        }
        
        // Start counting from 1% 
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            countUp()
        }
    }
    
    private func countUp() {
        var currentCount = 0
        let freezePoints: [Int: (String, Int)] = [
            18: ("Building introduction schedule...", 0),
            34: ("Setting up allergen tracker...", 1),
            56: ("Planning texture progression...", 2),
            78: ("Balancing nutrients for baby...", 3),
            92: ("Finalizing milestone plan...", 4)
        ]
        
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            currentCount += 1
            
            // Update progress and text
            DispatchQueue.main.async {
                self.progress = CGFloat(currentCount) / 100.0
                self.progressText = "\(currentCount)%"
            }
            
            // Check for freeze points
            if let (statusMessage, checkIndex) = freezePoints[currentCount] {
                timer.invalidate()
                
                DispatchQueue.main.async {
                    self.statusText = statusMessage
                    self.checkItems[checkIndex] = true
                }
                
                // Resume counting after freeze
                let freezeDuration: Double = currentCount == 92 ? 1.5 : 1.0
                DispatchQueue.main.asyncAfter(deadline: .now() + freezeDuration) {
                    self.resumeCountingFrom(currentCount + 1, freezePoints: freezePoints)
                }
                return
            }
            
            // Final completion
            if currentCount >= 100 {
                timer.invalidate()
                DispatchQueue.main.async {
                    self.statusText = "Complete!"
                    if !self.checkItems[4] {
                        self.checkItems[4] = true
                    }
                }
                
                // Navigate to final screen
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.navigateToFinal = true
                }
            }
        }
    }
    
    private func resumeCountingFrom(_ startCount: Int, freezePoints: [Int: (String, Int)]) {
        var currentCount = startCount - 1
        
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            currentCount += 1
            
            // Update progress and text
            DispatchQueue.main.async {
                self.progress = CGFloat(currentCount) / 100.0
                self.progressText = "\(currentCount)%"
            }
            
            // Check for freeze points
            if let (statusMessage, checkIndex) = freezePoints[currentCount] {
                timer.invalidate()
                
                DispatchQueue.main.async {
                    self.statusText = statusMessage
                    self.checkItems[checkIndex] = true
                }
                
                // Resume counting after freeze
                let freezeDuration: Double = currentCount == 92 ? 1.5 : 1.0
                DispatchQueue.main.asyncAfter(deadline: .now() + freezeDuration) {
                    self.resumeCountingFrom(currentCount + 1, freezePoints: freezePoints)
                }
                return
            }
            
            // Final completion
            if currentCount >= 100 {
                timer.invalidate()
                DispatchQueue.main.async {
                    self.statusText = "Complete!"
                    if !self.checkItems[4] {
                        self.checkItems[4] = true
                    }
                    
                    // Save nutrition goals as backup (in case it wasn't saved earlier)
                    let goals = self.onboardingData.generateNutritionGoals()
                    FoodDataManager.shared.saveNutritionGoals(goals)
                    print("🎯 LoadingView: Saved nutrition goals backup to Firebase")
                }
                
                // Navigate to final screen
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.navigateToFinal = true
                }
            }
        }
    }
}

// Final congratulations view with confetti
struct FinalCongratulationsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var showContent = false
    @State private var confettiTrigger = 0
    @State private var navigateToSummary = false
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with back button and progress
                HStack(spacing: 16) {
                    Button(action: { dismiss() }) {
                        Circle()
                            .fill(Color(.systemGray6))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "arrow.left")
                                    .foregroundColor(.black)
                                    .font(.system(size: 16))
                            )
                    }
                    
                    Rectangle()
                        .fill(Color.black)
                        .frame(height: 2)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer()
                
                // Success checkmark circle
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(showContent ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.3), value: showContent)
                .padding(.bottom, 48)
                
                // Congratulations text
                Text("congratulations")
                    .font(.system(size: 36, weight: .bold))
                    .padding(.bottom, 16)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.6), value: showContent)
                
                // Subtitle
                Text("your custom profile is ready!")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.8), value: showContent)
                
                Spacer()
                
                // Let's get started button
                NavigationLink(isActive: $navigateToSummary) {
                    CustomPlanSummaryView()
                } label: {
                    HStack {
                        Text("Let's get started!")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .cornerRadius(28)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    navigateToSummary = true
                })
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(1.0), value: showContent)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .confettiCannon(trigger: $confettiTrigger)
        .navigationBarHidden(true)
        .onAppear {
            coordinator.currentStep = 18
            MixpanelService.shared.trackQuestionViewed(questionTitle: "Final Congratulations", stepNumber: 18)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showContent = true
                confettiTrigger += 1
            }
        }
    }
}

// Custom Plan Summary View
struct CustomPlanSummaryView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @State private var showContent = false
    @State private var navigateToSubscription = false
    
    // Calculate date 3 days from now
    private var targetDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        let futureDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        return formatter.string(from: futureDate)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "arrow.left")
                                .foregroundColor(.black)
                                .font(.system(size: 16))
                        )
                }
                
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 2)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Success checkmark and title
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .scaleEffect(showContent ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.3), value: showContent)
                        
                        VStack(spacing: 4) {
                            Text("congratulations")
                                .font(.system(size: 24, weight: .bold))
                        }
                        .multilineTextAlignment(.center)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.6).delay(0.6), value: showContent)
                    }
                    .padding(.top, 12)
                    
                    Spacer(minLength: 4)
                    
                    // Stats rings
                    VStack(spacing: 12) {
                        // Stats circles grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            
                            // Foods to try
                            RecommendationCircle(
                                icon: "fork.knife",
                                title: "Foods to Try",
                                value: "50+",
                                color: Color.purple,
                                delay: 1.2
                            )
                            
                            // Allergy safety
                            RecommendationCircle(
                                icon: "shield.fill",
                                title: "Allergy Safe",
                                value: "100%",
                                color: Color.green,
                                delay: 1.4
                            )
                            
                            // Time saved
                            RecommendationCircle(
                                icon: "clock.fill",
                                title: "Meals Planned",
                                value: "30",
                                color: Color.blue,
                                delay: 1.6
                            )
                            
                            // Confidence boost
                            RecommendationCircle(
                                icon: "heart.fill",
                                title: "Mom Confidence",
                                value: "95%",
                                color: Color.orange,
                                delay: 1.8
                            )
                        }
                    }
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(1.2), value: showContent)
                    .padding(.horizontal, 24)
                    
                    // Your custom prediction (moved to bottom)
                    VStack(spacing: 12) {
                        Text("Your baby's food journey")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Based on your answers, your baby is on track to try 50+ nutritious foods in their first year. Early exposure to diverse flavors and textures reduces picky eating by up to 3x and supports lifelong healthy habits.")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(2.0), value: showContent)
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    
                    Spacer(minLength: 60)
                }
            }
            
            // Let's get started button
            NavigationLink(isActive: $navigateToSubscription) {
                TryForFreeView()
            } label: {
                Text("lets_get_started")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.black)
                    .cornerRadius(26)
            }
            .simultaneousGesture(TapGesture().onEnded {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                navigateToSubscription = true
            })
            .opacity(showContent ? 1 : 0)
            .animation(.easeOut(duration: 0.6).delay(2.2), value: showContent)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
        .onAppear {
            coordinator.currentStep = 19
            MixpanelService.shared.trackQuestionViewed(questionTitle: "Plan Summary", stepNumber: 19)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showContent = true
            }
        }
    }
}

// Recommendation Circle Component
struct RecommendationCircle: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    let delay: Double
    
    @State private var showCircle = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Centered heading with icon
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            }
            
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)
                    .frame(width: 120, height: 120)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: showCircle ? 0.75 : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 1.0).delay(delay), value: showCircle)
                
                // Value text
                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .opacity(showCircle ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(delay + 0.5), value: showCircle)
            }
            

        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showCircle = true
            }
        }
    }
}

// Simple and reliable video player for main.mp4
struct MainVideoPlayer: UIViewRepresentable {
    let videoName: String
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.white
        
        // Try to find video in main bundle
        var videoURL: URL?
        
        if let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") {
            print("✅ Found video in main bundle: \(url)")
            videoURL = url
        } else if let path = Bundle.main.path(forResource: videoName, ofType: "mp4") {
            videoURL = URL(fileURLWithPath: path)
            print("✅ Found video at path: \(path)")
        } else {
            print("❌ \(videoName).mp4 not found in project bundle")
            return containerView
        }
        
        guard let url = videoURL else { return containerView }
        
        // Create AVPlayer and AVPlayerLayer
        let player = AVPlayer(url: url)
        player.isMuted = true
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect // Maintain aspect ratio without cropping
        playerLayer.backgroundColor = UIColor.white.cgColor
        
        // Add player layer to container
        containerView.layer.addSublayer(playerLayer)
        
        // Set initial frame - important for immediate visibility
        playerLayer.frame = CGRect(x: 0, y: 0, width: 100, height: 100) // Temporary size
        
        // Store references for later access
        containerView.layer.setValue(player, forKey: "player")
        containerView.layer.setValue(playerLayer, forKey: "playerLayer")
        
        // Update frame after a short delay when container has proper bounds
        DispatchQueue.main.async {
            if containerView.bounds != .zero {
                playerLayer.frame = containerView.bounds
                print("🔧 Set initial player layer frame to: \(containerView.bounds)")
            }
        }
        
        // Start playing
                        player.play()
        print("🎬 MainVideoPlayer started playing: \(videoName)")
        
        // Set up looping
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
                            player.seek(to: .zero)
                            player.play()
                        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        print("🔄 updateUIView called with bounds: \(uiView.bounds)")
        
        if let playerLayer = uiView.layer.value(forKey: "playerLayer") as? AVPlayerLayer {
            // Always update the frame, even if bounds are the same
            playerLayer.frame = uiView.bounds
            print("🔧 Updated player layer frame to: \(uiView.bounds)")
            
            // Force a redraw
            playerLayer.setNeedsDisplay()
        } else {
            print("❌ Could not find playerLayer in updateUIView")
        }
    }
}

struct VideoPlayerView: UIViewRepresentable {
    let videoName: String
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        
        // Get video URL from bundle
        guard let path = Bundle.main.path(forResource: "spin", ofType: "mp4") else {
            print("❌ Failed to find video file: spin.mp4")
            return view
        }
        
        print("✅ Found video at path:", path)
        let videoURL = URL(fileURLWithPath: path)
        
        // Create AVPlayer and layer
        let player = AVPlayer(url: videoURL)
        let playerLayer = AVPlayerLayer(player: player)
        
        // Calculate size based on screen width
        let width = UIScreen.main.bounds.width - 40
        playerLayer.frame = CGRect(x: 0, y: 0, width: width, height: width) // Make it square
        playerLayer.videoGravity = .resizeAspect
        
        // Add player layer to view
        view.layer.addSublayer(playerLayer)
        
        // Play video and loop
        player.play()
        
        // Remove any existing observers before adding new one
        NotificationCenter.default.removeObserver(self)
        
        // Add loop observer
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                            object: player.currentItem, queue: .main) { _ in
            player.seek(to: .zero)
            player.play()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Handle any view updates if needed
    }
}

struct SpinnerView: View {
    @State private var rotation: Double = 0
    @State private var isSpinning = false
    
    // Segments arranged exactly like the Figma design - gift box positioned where the golden arrow points
    let segments = [
        ("50%", [Color(red: 0.4, green: 0.7, blue: 1.0), Color(red: 0.6, green: 0.8, blue: 1.0)]),    // Light blue gradient 
        ("No LUCK", [Color.white, Color(red: 0.95, green: 0.95, blue: 0.95)]),                         // White gradient
        ("30%", [Color(red: 0.95, green: 0.4, blue: 0.7), Color(red: 1.0, green: 0.6, blue: 0.8)]),   // Pink gradient
        ("90%", [Color(red: 0.6, green: 0.3, blue: 0.9), Color(red: 0.8, green: 0.5, blue: 1.0)]),    // Purple gradient
        ("70%", [Color.white, Color(red: 0.95, green: 0.95, blue: 0.95)]),                              // White gradient
        ("🎁", [Color(red: 0.6, green: 0.3, blue: 0.9), Color(red: 0.8, green: 0.5, blue: 1.0)])      // Purple gradient - WINNER POSITION
    ]
    
    var body: some View {
        ZStack {
            // Main wheel container with shadow
            ZStack {
                // Segments
                ForEach(0..<6) { index in
                    SpinnerSegment(
                        text: segments[index].0,
                        gradientColors: segments[index].1,
                        index: index
                    )
                }
                .rotationEffect(.degrees(rotation))
                
                // Outer blue gradient border (thicker, more prominent)
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.1, green: 0.3, blue: 0.8),
                                Color(red: 0.2, green: 0.5, blue: 1.0),
                                Color(red: 0.3, green: 0.6, blue: 1.0),
                                Color(red: 0.1, green: 0.3, blue: 0.8)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 12
                    )
                    .frame(width: 320, height: 320)
                
                // Inner gold gradient ring
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.0, green: 0.84, blue: 0.0),
                                Color(red: 1.0, green: 0.92, blue: 0.2),
                                Color(red: 0.9, green: 0.75, blue: 0.0),
                                Color(red: 1.0, green: 0.88, blue: 0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 296, height: 296)
                
                // Center circle with music emoji
                Circle()
                    .fill(Color.white)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.2, green: 0.4, blue: 0.9),
                                        Color(red: 0.3, green: 0.5, blue: 1.0)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                    .overlay(
                        Text("🛒")
                            .font(.system(size: 32))
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
            
            // Golden triangle pointer (positioned to point at gift segment)
            HStack {
                Spacer()
                ZStack {
                    // Shadow behind triangle
                    Triangle()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: 28, height: 32)
                        .rotationEffect(.degrees(-90))
                        .offset(x: 11, y: 2)
                    
                    // Main golden triangle
                    Triangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 1.0, green: 0.84, blue: 0.0),
                                    Color(red: 1.0, green: 0.92, blue: 0.2),
                                    Color(red: 0.9, green: 0.75, blue: 0.0),
                                    Color(red: 1.0, green: 0.88, blue: 0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 32)
                        .rotationEffect(.degrees(-90)) // Point toward center
                        .overlay(
                            Triangle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 1.0, green: 0.84, blue: 0.0),
                                            Color(red: 0.9, green: 0.75, blue: 0.0)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                                .frame(width: 28, height: 32)
                                .rotationEffect(.degrees(-90))
                        )
                        .offset(x: 10)
                }
            }
            .frame(width: 320, height: 320)
        }
        .frame(width: 320, height: 320)
        .onAppear {
            // Start spinning after a brief delay, land exactly on gift box
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 3.5)) {
                    // Multiple spins + precise landing on gift box center (240 degrees -> 0 degrees = 120 degree rotation)
                    rotation = 1800 + 120 // 5 full rotations + exact center landing on gift box
                }
            }
        }
    }
}

struct SpinnerSegment: View {
    let text: String
    let gradientColors: [Color]
    let index: Int
    
    var body: some View {
        ZStack {
            // Segment path with enhanced gradients
            Path { path in
                let center = CGPoint(x: 160, y: 160)
                path.move(to: center)
                path.addArc(center: center,
                          radius: 148,
                          startAngle: .degrees(Double(index) * 60 - 90),
                          endAngle: .degrees(Double(index + 1) * 60 - 90),
                          clockwise: false)
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: gradientColors),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            // Segment divider lines (more subtle)
            Path { path in
                let angle = Double(index) * 60 - 90
                let startRadius: CGFloat = 30
                let endRadius: CGFloat = 148
                let startX = 160 + startRadius * cos(angle * .pi / 180)
                let startY = 160 + startRadius * sin(angle * .pi / 180)
                let endX = 160 + endRadius * cos(angle * .pi / 180)
                let endY = 160 + endRadius * sin(angle * .pi / 180)
                
                path.move(to: CGPoint(x: startX, y: startY))
                path.addLine(to: CGPoint(x: endX, y: endY))
            }
            .stroke(Color.black.opacity(0.1), lineWidth: 1)
            
            // Text with better positioning and styling
            Text(text)
                .font(.system(size: text == "🎁" ? 36 : (text == "No LUCK" ? 16 : 22), weight: .bold))
                .foregroundColor(isWhiteSegment ? .black : .white)
                .shadow(color: isWhiteSegment ? Color.clear : Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
                .rotationEffect(.degrees(Double(index) * 60 + 30)) // Rotate text to follow segment
                .position(textPosition(for: index))
        }
        .frame(width: 320, height: 320)
    }
    
    private var isWhiteSegment: Bool {
        return gradientColors.first == .white
    }
    
    private func textPosition(for index: Int) -> CGPoint {
        let angle = Double(index) * 60 + 30 - 90 // Center of segment
        let radius: CGFloat = 110 // Distance from center
        let x = 160 + radius * cos(angle * .pi / 180)
        let y = 160 + radius * sin(angle * .pi / 180)
        return CGPoint(x: x, y: y)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }
}

struct WinbackView: View {
    @Binding var isPresented: Bool
    @State private var showOneTimeOffer = false
    @State private var spinnerCompleted = false
    let storeManager: StoreManager // Add this parameter
    @StateObject private var remoteConfig = RemoteConfigManager.shared
    
    var body: some View {
        ZStack {
            if showOneTimeOffer {
                OneTimeOfferView(isPresented: $showOneTimeOffer, parentPresented: $isPresented, storeManager: storeManager) // Pass storeManager
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else {
                VStack(spacing: 32) {
                    // Win exclusive offers title
                    Text("Win exclusive offers")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.top, 40)
                    
                    // Title with proper line breaks and gradient
                    VStack(spacing: 8) {
                        Text("Grab your permanent")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text("Discount")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.3, green: 0.5, blue: 1.0),  // Blue
                                        Color(red: 0.9, green: 0.4, blue: 0.7)   // Pink
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    
                    Spacer()
                    
                    // Centered Spinner (only show in hard paywall mode)
                    if remoteConfig.hardPaywall {
                    SpinnerView()
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .onAppear {
                    if remoteConfig.hardPaywall {
                    // Show one time offer after spinner completes (0.8s delay + 3.5s animation = 4.3s total)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.3) {
                        if !spinnerCompleted {
                            spinnerCompleted = true
                            withAnimation(.easeInOut(duration: 0.5)) {
                                showOneTimeOffer = true
                                }
                            }
                        }
                    } else {
                        // Soft paywall mode - show offer immediately without spinner
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if !spinnerCompleted {
                                spinnerCompleted = true
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    showOneTimeOffer = true
                                }
                            }
                        }
                    }
                }
            }
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
    }
}

// TimelineItem component with separate elements
struct TimelineItem: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let isLast: Bool
    let showContent: Bool
    let lineColor: Color
    let lineHeight: CGFloat // Individual line height control
    let iconTopPadding: CGFloat // Individual icon positioning
    let textTopPadding: CGFloat // Individual text positioning
    let showLine: Bool // Control whether to show the line
    
    var body: some View {
        HStack(spacing: 0) {
            // Left side: Spacer for layout
            VStack(spacing: 0) {
                // Spacer for text spacing - independent of line
                Spacer()
                    .frame(height: 20)
            }
            .frame(width: 24)
            
            // Right side: Text content - independently positioned
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.black.opacity(0.7))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)
            .padding(.bottom, isLast ? 0 : 20)
            .padding(.top, textTopPadding)
        }
        .overlay(
            // Line segment centered with icon
            Group {
                if showLine {
                    Rectangle()
                        .fill(lineColor)
                        .frame(width: 6, height: lineHeight)
                        .offset(y: 24 + iconTopPadding) // Position below icon
                        .offset(x: 9) // Center horizontally with icon (24/2 - 6/2 = 9)
                }
            }
            , alignment: .topLeading
        )
        .overlay(
            // Icon positioned at the top of the line segment
            ZStack {
                Circle()
                    .fill(iconColor)
                    .frame(width: 24, height: 24)
                
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            .offset(y: iconTopPadding)
            , alignment: .topLeading
        )
        .opacity(showContent ? 1 : 0)
        .animation(.easeOut(duration: 0.6).delay(0.6), value: showContent)
    }
}

// Try For Free View - new page before bell notification
struct TryForFreeView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showContent = false
    @State private var navigateToSubscription = false
    @StateObject private var remoteConfig = RemoteConfigManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - removed restore button
            HStack {
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            // Main content
            VStack(spacing: 0) {
                // Title
                Text(remoteConfig.hardPaywall ? "We want you to try\nCal AI for free" : "We want you to try\nCal AI")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.black)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 20)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.3), value: showContent)
                
                // Main Video (commented out — main.mp4 not in bundle yet)
                // MainVideoPlayer(videoName: "main")
                //     .frame(maxWidth: .infinity, maxHeight: 500)
                //     .clipped()
                //     .padding(.bottom, 30)
                //     .opacity(showContent ? 1 : 0)
                //     .animation(.easeOut(duration: 0.6).delay(0.6), value: showContent)
            }
            
            // Bottom section with button and payment text
            VStack(spacing: 16) {
                // Payment info (conditional based on paywall mode)
                if remoteConfig.hardPaywall {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("No Payment Due Now")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                }
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(1.0), value: showContent)
                }
                
                // Try button (conditional text based on paywall mode)
                NavigationLink(isActive: $navigateToSubscription) {
                    SubscriptionView()
                } label: {
                    Text(remoteConfig.hardPaywall ? "Try for $0.00" : "Try Thrifty")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black)
                        .clipShape(
                        RoundedCorner(radius: 16, corners: [.topLeft, .topRight, .bottomLeft, .bottomRight])
                    )
                }
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(1.2), value: showContent)
                
                // Legal text (conditional based on paywall mode)
                if !remoteConfig.hardPaywall {
                Text("Just $12 per month (billed yearly)")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(1.4), value: showContent)
                }
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
        .background(Color.white)
        .navigationBarHidden(true)
        .onAppear {
            showContent = true
            // Track winback subscription view
            MixpanelService.shared.trackSubscriptionViewed(planType: "winback_offer")
            // FacebookPixelService.shared.trackSubscriptionViewed(planType: "winback_offer")
        }
    }
}

// Update SubscriptionView to use new WinbackView
struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var coordinator = OnboardingCoordinator()
    @StateObject private var storeManager = StoreManager()
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var remoteConfig = RemoteConfigManager.shared
    @State private var showContent = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showWinback = false
    @State private var navigateToCreateAccount = false
    @State private var currentStep = 1 // 1 = bell reminder, 2 = subscription details
    @State private var bellAnimating = false
    @State private var showingPrivacyPolicy = false
    @State private var isPurchasing = false // Loading state for purchase button
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            // Main content
            VStack(spacing: 20) {
                if currentStep == 1 {
                    step1Content
                } else {
                    step2Content
                }
                
                // Bottom section with button and payment text
                VStack(spacing: 12) {
                    if currentStep == 1 {
                        // Step 1: No payment due now text
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                            
                            Text("No Payment Due Now")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                        }
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.6).delay(1.0), value: showContent)
                        
                        // Step 1: Try button (conditional text based on paywall mode)
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep = 2
                            }
                        }) {
                            Text(remoteConfig.hardPaywall ? "Try For $0.00" : "Try Thrifty")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.black)
                                .clipShape(
                        RoundedCorner(radius: 16, corners: [.topLeft, .topRight, .bottomLeft, .bottomRight])
                    )
                        }
                        .padding(.horizontal, 24)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.6).delay(1.2), value: showContent)
                        
                        // Step 1: Legal text (conditional based on paywall mode)
                        if !remoteConfig.hardPaywall {
                            Text("Annual subscription")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.6).delay(1.4), value: showContent)
                        }
                        
                        // No commitment text for Step 1
                        Text("No commitment, cancel anytime.")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.6).delay(1.6), value: showContent)
                    } else {
                        // Step 2: Payment info (conditional based on paywall mode)
                        if remoteConfig.hardPaywall {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                
                                Text("No Payment Due Now")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)
                            }
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.6).delay(1.0), value: showContent)
                        }
                            
                        // Step 2: Purchase button - same position as step 1 button
                            Button(action: {
                                // Prevent multiple taps
                                guard !isPurchasing else { return }
                                
                                Task {
                                    // Set loading state
                                    isPurchasing = true
                                    
                                    do {
                                        // Track subscription attempt
                                        MixpanelService.shared.trackSubscriptionViewed(planType: "yearly")
                                        // FacebookPixelService.shared.trackSubscriptionViewed(planType: "yearly")
                                        
                                        print("🔍 Attempting to purchase yearly subscription...")
                                        print("📦 Available products: \(storeManager.subscriptions.count)")
                                        for product in storeManager.subscriptions {
                                            print("   - \(product.id): \(product.displayPrice)")
                                        }
                                        print("🎯 Looking for yearly subscription product...")
                                        
                        // Find the subscription product (try yearly first for best value, then fallback to monthly)
                        guard let subscription = storeManager.subscriptions.first(where: { 
                            $0.id == "com.thrifty.thrifty.unlimited.yearly149" || 
                            $0.id == "com.thrifty.thrifty.unlimited.monthly" 
                        }) else {
                                            print("❌ Subscription product not found")
                                            errorMessage = "Subscription product not available. Please try again."
                                            showError = true
                                            isPurchasing = false // Reset loading state
                                            return
                                        }
                                        
                                        print("✅ Found subscription: \(subscription.id) - \(subscription.displayPrice)")
                                        let result = try await subscription.purchase()
                                        
                                        switch result {
                                        case .success(let verification):
                                            switch verification {
                                            case .verified(let transaction):
                                                print("✅ Successfully purchased yearly subscription: \(transaction.productID)")
                                                
                                                // Track successful subscription purchase
                                                let price = Double(truncating: subscription.price as NSNumber)
                                                MixpanelService.shared.trackSubscriptionPurchased(planType: "yearly", price: price)
                                                
                                                // Record transaction for Apple consumption tracking
                                                // COMMENTED OUT - ConsumptionRequestService not needed for calorie tracking app
                                                // let userEmail = AuthenticationManager.shared.currentUser?.email
                                                // let userId = AuthenticationManager.shared.currentUser?.id ?? "unknown"
                                                // ConsumptionRequestService.shared.recordTransaction(
                                                //     transactionId: String(transaction.id),
                                                //     originalTransactionId: String(transaction.originalID),
                                                //     productId: transaction.productID,
                                                //     purchaseDate: transaction.purchaseDate,
                                                //     expiresDate: transaction.expirationDate,
                                                //     price: price,
                                                //     currency: "USD",
                                                //     userId: userId,
                                                //     userEmail: userEmail,
                                                //     revenueCatUserId: userEmail
                                                // )
                                                
                                                // Send conversion to SKAdNetwork for Meta Ads attribution
                                                if #available(iOS 15.4, *) {
                                                    // Yearly subscriptions = highest value (63) regardless of price
                                                    // They have the highest LTV and are most valuable conversions
                                                    let conversionValue = 63
                                                    SKAdNetwork.updatePostbackConversionValue(conversionValue) { error in
                                                        if let error = error {
                                                            print("⚠️ SKAdNetwork error: \(error)")
                                                        } else {
                                                            print("✅ SKAdNetwork conversion value updated: \(conversionValue) for yearly subscription ($\(price))")
                                                        }
                                                    }
                                                } else if #available(iOS 14.0, *) {
                                                    // Fallback for iOS 14.0-15.3
                                                    let conversionValue = 63
                                                    SKAdNetwork.updateConversionValue(conversionValue)
                                                    print("✅ SKAdNetwork conversion value updated: \(conversionValue) for yearly subscription ($\(price))")
                                                }
                                                
                                                // Store purchase event to send AFTER user logs in (to capture email)
                                                // This ensures accurate user tracking per Meta CAPI requirements
                                                PendingMetaEventService.shared.storePendingPurchase(
                                                    transactionId: String(transaction.id),
                                                    price: price,
                                                    planType: "yearly",
                                                    currency: "USD"
                                                )
                                                
                                                // Successful purchase - mark subscription as completed
                                                await transaction.finish()
                                                await storeManager.updateSubscriptionStatus()
                                                authManager.markSubscriptionCompleted()
                                                isPurchasing = false // Reset loading state
                                                // Only show create account if user is not already logged in
                                                if !authManager.isLoggedIn {
                                                    navigateToCreateAccount = true
                                                }
                                            case .unverified:
                                                throw StoreError.failedVerification
                                            }
                                        case .pending:
                                            throw StoreError.pending
                                                                case .userCancelled:
                            // Show winback for both hard and soft paywall modes
                            // The difference is only in the wheel animation (handled in WinbackView)
                                showWinback = true
                                isPurchasing = false // Reset loading state
                                        @unknown default:
                                            isPurchasing = false // Reset loading state
                                            throw StoreError.unknown
                                        }
                                                        } catch StoreError.userCancelled {
                        // Show winback for both hard and soft paywall modes
                        // The difference is only in the wheel animation (handled in WinbackView)
                            showWinback = true
                            isPurchasing = false // Reset loading state
                                    } catch StoreError.pending {
                                        errorMessage = "Purchase is pending"
                                        showError = true
                                        isPurchasing = false // Reset loading state
                                    } catch {
                                        errorMessage = "Failed to make purchase"
                                        showError = true
                                        isPurchasing = false // Reset loading state
                                    }
                                }
                            }) {
                                HStack(spacing: 8) {
                                    if isPurchasing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    }
                                    
                                    Text(isPurchasing ? "Processing..." : "Start my 3-Day Free Trial")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                .background(isPurchasing ? Color.gray : Color.black)
                                    .clipShape(
                        RoundedCorner(radius: 16, corners: [.topLeft, .topRight, .bottomLeft, .bottomRight])
                    )
                            }
                            .disabled(isPurchasing)
                            .padding(.horizontal, 24)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.6).delay(1.2), value: showContent)
                            
                            // Add pricing text under the button (always show)
                            Text("Just $12 per month (billed yearly)")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .opacity(showContent ? 1 : 0)
                                .animation(.easeOut(duration: 0.6).delay(1.4), value: showContent)
                    }
                    
                    if currentStep == 2 {
                        // Legal text for step 2 (conditional based on paywall mode)
                        if !remoteConfig.hardPaywall {
                            Text("Annual subscription")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.6).delay(1.4), value: showContent)
                        }
                        
                        // Terms & Privacy links for soft paywall compliance
                        if !remoteConfig.hardPaywall {
                            TermsAndPrivacyText(showingPrivacyPolicy: $showingPrivacyPolicy)
                                .padding(.top, 16)
                                .opacity(showContent ? 1 : 0)
                                .animation(.easeOut(duration: 0.6).delay(1.6), value: showContent)
                            
                            // Restore Purchases Button (required by Apple)
                            Button(action: {
                                Task {
                                    do {
                                        try await AppStore.sync()
                                        print("✅ Purchases restored successfully")
                                    } catch {
                                        print("❌ Failed to restore purchases: \(error)")
                                        errorMessage = "Failed to restore purchases"
                                        showError = true
                                    }
                                }
                            }) {
                                Text("Restore Purchases")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                                    .underline()
                            }
                            .padding(.top, 12)
                            .opacity(showContent ? 1 : 0)
                            .animation(.easeOut(duration: 0.6).delay(1.8), value: showContent)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .preferredColorScheme(.light)
        .edgesIgnoringSafeArea(.bottom) // Only ignore bottom safe area, keep top safe area for proper restore button positioning
        .onAppear {
            coordinator.currentStep = 20
            MixpanelService.shared.trackQuestionViewed(questionTitle: "Subscription", stepNumber: 20)
            // FacebookPixelService.shared.trackOnboardingStepViewed(questionTitle: "Subscription", stepNumber: 20)
            // Track subscription view appearance
            MixpanelService.shared.trackSubscriptionViewed(planType: "yearly_subscription_page")
            // FacebookPixelService.shared.trackSubscriptionViewed(planType: "yearly_subscription_page")
            
            // Set paywall screen state to true when user reaches subscription screen
            authManager.setPaywallScreenState(true)
            
            showContent = true
            // Load products when view appears
            Task {
                await storeManager.loadProducts()
            }
            
                    // Note: Both hard and soft paywall modes show winback when user cancels
        // The difference is only in the wheel animation and pricing transparency
        }
        .onDisappear {
            // Clear paywall state when user leaves subscription screen by going back
            if !authManager.hasCompletedSubscription {
                authManager.setPaywallScreenState(false)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $showWinback) {
                WinbackView(isPresented: $showWinback, storeManager: storeManager)
        }
        .background(
            NavigationLink(isActive: $navigateToCreateAccount) {
                CreateAccountView()
            } label: {
                EmptyView()
            }
            .hidden()
        )
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
                .presentationDetents([.height(UIScreen.main.bounds.height * 0.8)])
                .presentationDragIndicator(.visible)
        }

    }
    
    // MARK: - Helper Views
    
    private var step1Content: some View {
        VStack(spacing: 0) {
            // Reminder text at the top
            Text("We'll send you a reminder\nbefore your free trial ends")
                .font(.system(size: 24, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundColor(.black)
                .padding(.top, 40)
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.3), value: showContent)
            
            Spacer()
            
            // Bell icon with notification badge in the middle
            ZStack {
                // Bell with advanced realistic shake animation
                Image(systemName: "bell")
                    .font(.system(size: 200, weight: .light))
                    .foregroundColor(.black)
                    .rotationEffect(.degrees(bellAnimating ? -15 : 0))
                    .animation(
                        Animation.easeInOut(duration: 0.25)
                            .repeatForever(autoreverses: true),
                        value: bellAnimating
                    )
                    .scaleEffect(bellAnimating ? 0.98 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.1)
                            .repeatForever(autoreverses: true),
                        value: bellAnimating
                    )
                
                // Notification badge
                Circle()
                    .fill(Color.black)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text("1")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .offset(x: 55, y: -60)
                    .rotationEffect(.degrees(bellAnimating ? -15 : 0))
                    .animation(
                        Animation.easeInOut(duration: 0.25)
                            .repeatForever(autoreverses: true),
                        value: bellAnimating
                    )
                    .scaleEffect(bellAnimating ? 0.98 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.1)
                            .repeatForever(autoreverses: true),
                        value: bellAnimating
                    )
            }
            .opacity(showContent ? 1 : 0)
            .animation(.easeOut(duration: 0.6).delay(0.6), value: showContent)
            .onAppear {
                // Start bell animation after content appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    bellAnimating = true
                }
            }
            
            Spacer()
        }
    }
    
    private var step2Content: some View {
        VStack(spacing: 0) {
            // Title - positioned higher (conditional based on paywall mode)
            Text(remoteConfig.hardPaywall ? "Start your 3-Day FREE trial to continue." : "Subscribe to Thrifty Unlimited")
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundColor(.black)
                .lineLimit(nil) // Allow unlimited lines to prevent truncation
                .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion
                .padding(.top, 20)
                .padding(.bottom, 30)
                .padding(.horizontal, 24) // Add horizontal padding to ensure proper spacing
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.3), value: showContent)
            
            // Add more space between title and timeline
            Spacer()
                .frame(height: 40)
            
            // Proper timeline structure - each item is self-contained
            VStack(spacing: 0) {
                // Today item - top line (you can adjust lineHeight individually)
                TimelineItem(
                    icon: "lock.fill",
                    iconColor: .green,
                    title: "Today",
                    description: "Unlock all the app's features and reach your goals faster with AI-powered nutrition tracking daily.",
                    isLast: false,
                    showContent: showContent,
                    lineColor: .green,
                    lineHeight: 100, // Adjust this for top line length
                    iconTopPadding: 15,
                    textTopPadding: 25,
                    showLine: true
                )
                
                // In 2 days item - middle line (you can adjust lineHeight individually)
                TimelineItem(
                    icon: "bell.fill",
                    iconColor: .green,
                    title: "In 2 days - Reminder",
                    description: "We'll send you a reminder that your trial is ending soon.",
                    isLast: false,
                    showContent: showContent,
                    lineColor: .green,
                    lineHeight: 80, // Adjust this for middle line length
                    iconTopPadding: 15,
                    textTopPadding: 25,
                    showLine: true
                )
                    
                // In 3 days item - bottom line (you can adjust lineHeight individually)
                TimelineItem(
                    icon: "plus",
                    iconColor: .gray,
                    title: "In 3 days - Billing Starts",
                    description: "You'll be charged, unless you cancel anytime before.",
                    isLast: true,
                    showContent: showContent,
                    lineColor: .gray,
                    lineHeight: 80, // Adjust this for bottom line length
                    iconTopPadding: 15,
                    textTopPadding: 25,
                    showLine: true
                )
            }
            .padding(.horizontal, 24)
            .opacity(showContent ? 1 : 0)
            .animation(.easeOut(duration: 0.6).delay(0.6), value: showContent)
            
            Spacer()
        }
    }
    
    private var headerView: some View {
        HStack {
            // Skip button on the left
            Button(action: {
                // Skip paywall and let user into the app
                // Onboarding data is preserved in OnboardingDataManager.shared
                print("🚀 User skipped paywall - preserving onboarding data")
                
                // Mark subscription as completed to allow app access
                authManager.markSubscriptionCompleted()
                
                // If user is not logged in, navigate to account creation
                // This preserves the onboarding flow
                if !authManager.isLoggedIn {
                    navigateToCreateAccount = true
                } else {
                    // User is logged in, dismiss to main app
                    dismiss()
                }
            }) {
                Text("Skip")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Button(action: {
                Task {
                    do {
                        try await storeManager.restorePurchases()
                    } catch {
                        errorMessage = "Failed to restore purchases"
                        showError = true
                    }
                }
            }) {
                Text("Restore")
                    .font(.system(size: 17))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
}

struct OneTimeOfferView: View {
    @Binding var isPresented: Bool
    @Binding var parentPresented: Bool
    let storeManager: StoreManager // Accept StoreManager instance as a parameter
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var remoteConfig = RemoteConfigManager.shared
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var navigateToCreateAccount = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with X button
            HStack {
                Button(action: {
                    parentPresented = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
            
            VStack(spacing: 32) {
                // ONE TIME OFFER title
                Text("ONE TIME OFFER")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                
                // 80% OFF FOREVER box with sparkles (made bigger with shadow and white border)
                ZStack {
                    // Sparkle decorations around the box
                    VStack {
                        HStack {
                            Image(systemName: "sparkle")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .offset(x: -30, y: -15)
                            Spacer()
                            Image(systemName: "sparkle")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .offset(x: 30, y: -20)
                        }
                        Spacer()
                        HStack {
                            Image(systemName: "sparkle")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .offset(x: -35, y: 15)
                            Spacer()
                            Image(systemName: "sparkle")
                                .font(.system(size: 18))
                                .foregroundColor(.gray)
                                .offset(x: 35, y: 20)
                        }
                    }
                    .frame(width: 320, height: 160)
                    
                    // Main offer box (with shadow and white border)
                    VStack(spacing: 12) {
                        Text("50% OFF")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                        Text("FOREVER")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(width: 280, height: 140)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white, lineWidth: 3)
                            )
                            .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 8)
                    )
                }
                
                // Pricing
                HStack(spacing: 8) {
                    Text("$149.00")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                        .strikethrough()
                }
                
                // Warning text with black triangle and exclamation mark
                HStack {
                    ZStack {
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                        Image(systemName: "exclamationmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .offset(y: 1)
                    }
                    Text("This offer won't be there once you close it!")
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 24)
                
                // Combined LOWEST PRICE EVER with yearly plan box - only show when NOT hardPaywall
                if !remoteConfig.hardPaywall {
                VStack(spacing: 0) {
                    // LOWEST PRICE EVER header
                    Text("LOWEST PRICE EVER")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.black)
                        .cornerRadius(12, corners: [.topLeft, .topRight])
                    
                    // Yearly plan box (seamlessly connected to header with no top corners)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Yearly")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                            Text("Winback Offer • $79.99")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text("$79.99 /yearly")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
                    .overlay(
                        RoundedCorner(radius: 12, corners: [.bottomLeft, .bottomRight])
                            .stroke(Color.black, lineWidth: 2)
                    )
                    .offset(y: -1) // Slight overlap to create seamless connection
                }
                .padding(.horizontal, 24)
                .padding(.top, 16) // Move closer to button
                }
                
                // CLAIM YOUR ONE TIME OFFER button
                Button(action: {
                    // Prevent multiple taps
                    guard !isPurchasing else { return }
                    
                    Task {
                        await purchaseSubscription()
                    }
                }) {
                    HStack(spacing: 8) {
                        if storeManager.subscriptions.isEmpty || isPurchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text(isPurchasing ? "Processing..." : 
                             storeManager.subscriptions.isEmpty ? "Loading..." : "CLAIM YOUR ONE TIME OFFER")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background((storeManager.subscriptions.isEmpty || isPurchasing) ? Color.gray : Color.black)
                    .cornerRadius(28)
                }
                .disabled(storeManager.subscriptions.isEmpty || isPurchasing)
                .padding(.horizontal, 24)
                .padding(.top, 24) // Reduced spacing from top elements
                
                // Retry button if products failed to load
                if storeManager.subscriptions.isEmpty {
                    Button(action: {
                        Task {
                            await storeManager.loadProducts()
                        }
                    }) {
                        Text("Retry Loading Products")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .alert("Purchase Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $navigateToCreateAccount) {
            CreateAccountView()
        }
    }
    
    private func purchaseSubscription() async {
        isPurchasing = true
        
        print("🔍 Attempting to purchase special subscription...")
        print("📦 Available products: \(storeManager.subscriptions.count)")
        for product in storeManager.subscriptions {
            print("   - \(product.id): \(product.displayPrice)")
        }
        
        do {
            // Find the winback product for one-time offer (try yearly winback first, then fallback to monthly)
            guard let specialSubscription = storeManager.subscriptions.first(where: { 
                $0.id == "com.thrifty.thrifty.unlimited.yearly.winback79" ||
                $0.id == "com.thrifty.thrifty.unlimited.monthly.winback" 
            }) else {
                print("❌ Winback offer product not found in available products")
                print("🔍 Looking for: com.thrifty.thrifty.unlimited.yearly.winback79 or monthly.winback")
                print("📦 Available products:")
                for product in storeManager.subscriptions {
                    print("   - \(product.id)")
                }
                errorMessage = "Special offer not available. Please try again or contact support."
                showError = true
                isPurchasing = false
                return
            }
            
            let result = try await specialSubscription.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    print("✅ Successfully purchased $79.00 winback offer: \(transaction.productID)")
                    
                    // Track successful winback subscription purchase
                    MixpanelService.shared.trackSubscriptionPurchased(planType: "winback_79.00", price: 79.00)
                    
                    // Record transaction for Apple consumption tracking
                    // COMMENTED OUT - ConsumptionRequestService not needed for calorie tracking app
                    // let userEmail = AuthenticationManager.shared.currentUser?.email
                    // let userId = AuthenticationManager.shared.currentUser?.id ?? "unknown"
                    // ConsumptionRequestService.shared.recordTransaction(
                    //     transactionId: String(transaction.id),
                    //     originalTransactionId: String(transaction.originalID),
                    //     productId: transaction.productID,
                    //     purchaseDate: transaction.purchaseDate,
                    //     expiresDate: transaction.expirationDate,
                    //     price: 79.00,
                    //     currency: "USD",
                    //     userId: userId,
                    //     userEmail: userEmail,
                    //     revenueCatUserId: userEmail
                    // )
                    
                    // Send conversion to SKAdNetwork for Meta Ads attribution
                    if #available(iOS 15.4, *) {
                        let conversionValue = 55  // $79 winback = high value
                        SKAdNetwork.updatePostbackConversionValue(conversionValue) { error in
                            if let error = error {
                                print("⚠️ SKAdNetwork error: \(error)")
                            } else {
                                print("✅ SKAdNetwork conversion value updated: \(conversionValue) for winback offer ($79)")
                            }
                        }
                    } else if #available(iOS 14.0, *) {
                        // Fallback for iOS 14.0-15.3
                        let conversionValue = 55
                        SKAdNetwork.updateConversionValue(conversionValue)
                        print("✅ SKAdNetwork conversion value updated: \(conversionValue) for winback offer ($79)")
                    }
                    
                    // Store purchase event to send AFTER user logs in (to capture email)
                    // This ensures accurate user tracking per Meta CAPI requirements
                    let productPrice = Double(truncating: specialSubscription.price as NSNumber)
                    PendingMetaEventService.shared.storePendingPurchase(
                        transactionId: String(transaction.id),
                        price: productPrice,
                        planType: "winback_\(specialSubscription.displayPrice)",
                        currency: "USD"
                    )
                    
                    await transaction.finish()
                    await storeManager.updateSubscriptionStatus()
                    authManager.markSubscriptionCompleted()
                    isPurchasing = false // Reset loading state
                    // Only show create account if user is not already logged in
                    if !authManager.isLoggedIn {
                        navigateToCreateAccount = true
                    }
                case .unverified:
                    errorMessage = "Purchase verification failed"
                    showError = true
                }
            case .userCancelled:
                // User cancelled, no error needed
                break
            case .pending:
                errorMessage = "Purchase is pending approval"
                showError = true
            @unknown default:
                errorMessage = "Unknown purchase error"
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isPurchasing = false
    }
}

// Create Account View - appears after successful purchase
struct CreateAccountView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var authManager = AuthenticationManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and progress bar
            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18))
                        .foregroundColor(.black)
                }
                
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 2)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            // Title
            Text("Create an account")
                .font(.system(size: 32, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 32)
            
            Spacer()
            
            // Static sign in buttons
            VStack(spacing: 20) {
                // Sign in with Apple - Static button
                AppleSignInButton(authManager: AuthenticationManager.shared)
                
                // Google Sign In - RE-ENABLED with real CLIENT_ID
                GoogleSignInButton(authManager: AuthenticationManager.shared)
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .onAppear {
            // If user is already logged in, dismiss this screen immediately
            if authManager.isLoggedIn {
                authManager.markSubscriptionCompleted()
                dismiss()
            }
        }
        .onChange(of: authManager.isLoggedIn) { isLoggedIn in
            if isLoggedIn {
                // User successfully signed in, mark subscription as completed
                authManager.markSubscriptionCompleted()
                dismiss()
            }
        }
    }
}

// Define custom colors for white theme design
extension Color {
    static let thriftyBackground = Color.white
    static let thriftyTopBanner = Color.white
    static let thriftySecondaryText = Color(hex: "6B6B6B")
    static let thriftyDeleteRed = Color(hex: "FF453A")
    static let thriftyAccent = Color.black // Black accent color for buttons
}

// Helper for hex color initialization
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Tool Response Manager for persisting generated responses
@MainActor
class ToolResponseManager: ObservableObject {
    static let shared = ToolResponseManager()
    
    private init() {
        loadAllResponses()
    }
    
    @Published var toolResponses: [String: ToolResponse] = [:]
    
    struct ToolResponse: Codable {
        var userInput: String
        var generatedText: String
        var timestamp: Date
        
        init(userInput: String = "", generatedText: String = "") {
            self.userInput = userInput
            self.generatedText = generatedText
            self.timestamp = Date()
        }
    }
    
    func getResponse(for toolTitle: String) -> ToolResponse {
        return toolResponses[toolTitle] ?? ToolResponse()
    }
    
    func saveResponse(for toolTitle: String, userInput: String, generatedText: String) {
        toolResponses[toolTitle] = ToolResponse(userInput: userInput, generatedText: generatedText)
        saveToUserDefaults()
    }
    
    func updateUserInput(for toolTitle: String, userInput: String) {
        var response = toolResponses[toolTitle] ?? ToolResponse()
        response.userInput = userInput
        toolResponses[toolTitle] = response
        saveToUserDefaults()
    }
    
    func clearResponse(for toolTitle: String) {
        toolResponses.removeValue(forKey: toolTitle)
        saveToUserDefaults()
    }
    
    private func saveToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(toolResponses) {
            UserDefaults.standard.set(encoded, forKey: "ToolResponses")
        }
    }
    
    private func loadAllResponses() {
        if let data = UserDefaults.standard.data(forKey: "ToolResponses"),
           let decoded = try? JSONDecoder().decode([String: ToolResponse].self, from: data) {
            toolResponses = decoded
        }
    }
}

// User Data Model
struct UserData: Codable {
    let id: String
    let email: String?
    let name: String?
    let profileImageURL: String?
    let authProvider: AuthProvider
    
    enum AuthProvider: String, Codable {
        case apple = "apple"
        case google = "google"
        case email = "email"
    }
}

// Remote Config Manager for controlling app features using Firestore
@MainActor
class RemoteConfigManager: NSObject, ObservableObject {
    static let shared = RemoteConfigManager()
    
    @Published var hardPaywall: Bool = true // Default to true (hard paywall)
    
    private let hardPaywallKey = "hardpaywall"
    private let configCollection = "app_config"
    private var hasAttemptedLoad = false
    
    private override init() {
        super.init()
        // Don't load immediately - wait for Firebase to be configured
    }
    
    private func loadConfigFromFirestore() {
        // Ensure we only try to load once Firebase is configured
        guard FirebaseApp.app() != nil else {
            print("⚠️ Firebase not configured yet, delaying config loag d...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.loadConfigFromFirestore()
            }
            return
        }
        
        guard !hasAttemptedLoad else { return }
        hasAttemptedLoad = true
        
        let db = Firestore.firestore()
        print("🔍 Attempting to read from Firestore: \(configCollection)/paywall_config")
        
        db.collection(configCollection).document("paywall_config").getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error loading config from Firestore: \(error.localizedDescription)")
                    print("🔍 Error details: \(error)")
                    print("🔍 Error code: \((error as NSError).code)")
                    
                    // Check for specific error types
                    if (error as NSError).code == -1009 { // Network offline
                        print("📱 Device appears to be offline")
                    } else if (error as NSError).code == 7 { // Permission denied
                        print("🔒 Permission denied - check Firestore rules")
                    }
                    
                    // Keep default value (true) and retry after delay
                    print("🔄 Will retry in 5 seconds...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self?.hasAttemptedLoad = false
                        self?.loadConfigFromFirestore()
                    }
                    return
                }
                
                if let document = document, document.exists,
                   let data = document.data(),
                   let hardPaywall = data[self?.hardPaywallKey ?? ""] as? Bool {
                    self?.hardPaywall = hardPaywall
                    print("✅ Config loaded from Firestore - hardPaywall: \(hardPaywall)")
                } else {
                    print("ℹ️ No config found in Firestore, using default (hardPaywall: true)")
                    print("🔍 Document exists: \(document?.exists ?? false)")
                    print("🔍 Document path: \(self?.configCollection ?? "")/paywall_config")
                    print("🔍 Expected field: \(self?.hardPaywallKey ?? "")")
                    
                    if let data = document?.data() {
                        print("🔍 Document data: \(data)")
                        print("🔍 Available fields: \(Array(data.keys))")
                    } else {
                        print("❌ Document data is nil")
                    }
                    
                    // Provide setup instructions
                    print("📝 To fix this:")
                    print("   1. Go to Firebase Console → Firestore")
                    print("   2. Create collection: app_config")
                    print("   3. Create document: paywall_config")
                    print("   4. Add field: hardpaywall (boolean) = true")
                }
            }
        }
    }
    
    // Call this after Firebase is configured
    func initializeConfig() {
        loadConfigFromFirestore()
    }

    
    func refreshConfig() {
        hasAttemptedLoad = false
        loadConfigFromFirestore()
    }
    
    func togglePaywallMode() {
        hardPaywall.toggle()
        print("🎛️ Paywall mode changed to: \(hardPaywall ? "HARD" : "SOFT")")
    }
}

// Authentication Manager for handling real authentication
@MainActor
class AuthenticationManager: NSObject, ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: UserData?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var hasCompletedOnboarding: Bool = false
    @Published var hasCompletedSubscription: Bool = false
    @Published var isOnPaywallScreen: Bool = false
    @Published var hasSeenFirstTimeCongratsPopup: Bool = false
    
    private let isLoggedInKey = "AuthenticationManager_IsLoggedIn"
    private let userDataKey = "AuthenticationManager_UserData"
    private let hasCompletedOnboardingKey = "AuthenticationManager_HasCompletedOnboarding"
    private let hasCompletedSubscriptionKey = "AuthenticationManager_HasCompletedSubscription"
    private let isOnPaywallScreenKey = "AuthenticationManager_IsOnPaywallScreen"
    private let hasSeenFirstTimeCongratsPopupKey = "AuthenticationManager_HasSeenFirstTimeCongratsPopup"
    private var currentNonce: String?
    
    private override init() {
        super.init()
        
        // Initialize with default values
        isLoggedIn = false
        currentUser = nil
        isLoading = false
        errorMessage = nil
        hasCompletedOnboarding = false
        hasCompletedSubscription = false
        isOnPaywallScreen = false
        hasSeenFirstTimeCongratsPopup = false
        
        // Load saved authentication state
        loadAuthenticationState()
        
        print("🔐 AuthenticationManager initialized - isLoggedIn: \(isLoggedIn), hasCompletedOnboarding: \(hasCompletedOnboarding), hasCompletedSubscription: \(hasCompletedSubscription), isOnPaywallScreen: \(isOnPaywallScreen)")
    }
    
    // Apple Sign In
    func signInWithApple() {
        isLoading = true
        errorMessage = nil
        
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    // Google Sign In with Firebase - RE-ENABLED with real CLIENT_ID
    func signInWithGoogle() {
        isLoading = true
        errorMessage = nil
        
        guard let presentingViewController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows
            .first?.rootViewController else {
            errorMessage = "Unable to find presenting view controller"
            isLoading = false
            return
        }
        
        GoogleSignIn.GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    // Check if user cancelled (this is normal behavior, not an error)
                    if error.localizedDescription.contains("cancelled") || error.localizedDescription.contains("canceled") {
                        print("🔐 Google Sign In cancelled by user")
                        self.isLoading = false
                        return // Don't show error message for cancellation
                    }
                    
                    self.errorMessage = "Google Sign In failed: \(error.localizedDescription)"
                    self.isLoading = false
                    return
                }
                
                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    self.errorMessage = "Failed to get Google ID token"
                    self.isLoading = false
                    return
                }
                
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
                
                Auth.auth().signIn(with: credential) { authResult, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.errorMessage = "Firebase authentication failed: \(error.localizedDescription)"
                            self.isLoading = false
                            return
                        }
                        
                        guard let firebaseUser = authResult?.user else {
                            self.errorMessage = "Failed to get Firebase user"
                            self.isLoading = false
                            return
                        }
                        
                        let userData = UserData(
                            id: firebaseUser.uid,
                            email: firebaseUser.email,
                            name: firebaseUser.displayName,
                            profileImageURL: firebaseUser.photoURL?.absoluteString,
                            authProvider: .google
                        )
                        
                        self.completeSignIn(with: userData)
                    }
                }
            }
        }
    }
    
    // Email Sign In (placeholder - requires Firebase setup)
    func signInWithEmail(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        // Basic validation
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter both email and password"
            isLoading = false
            return
        }
        
        guard email.contains("@") && email.contains(".") else {
            errorMessage = "Please enter a valid email address"
            isLoading = false
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            isLoading = false
            return
        }
        
        // TODO: Implement Email Sign In with Firebase
        // For now, show error that Firebase is needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.errorMessage = "Email Sign In requires Firebase setup. Please use Apple Sign In for now."
            self.isLoading = false
        }
    }
    
    // MARK: - Email Verification Methods
    
    // Store verification data temporarily
    @Published var pendingVerificationEmail: String?
    @Published var verificationCodeSent: Bool = false
    private var generatedVerificationCode: String?
    private var codeGenerationTime: Date?
    
    // Send verification code to email using Firebase Cloud Functions
    func sendEmailVerificationCode(email: String, completion: @escaping (Bool, String?) -> Void) {
        // Validate email format
        guard email.contains("@") && email.contains(".") && !email.isEmpty else {
            completion(false, "Please enter a valid email address")
            return
        }
        
        // Check for Apple employee - skip actual email sending
        if email.lowercased() == "apple@test.com" {
            isLoading = true
            errorMessage = nil
            
            // Set up verification data for Apple employee
            generatedVerificationCode = "1234" // Hardcoded code
            codeGenerationTime = Date()
            pendingVerificationEmail = email
            
            DispatchQueue.main.async {
                self.isLoading = false
                self.verificationCodeSent = true
                completion(true, "Apple employee verification ready - use code: 1234")
            }
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Generate 4-digit verification code
        let verificationCode = String(format: "%04d", Int.random(in: 1000...9999))
        generatedVerificationCode = verificationCode
        codeGenerationTime = Date()
        pendingVerificationEmail = email
        
        // Call Firebase Cloud Function to send email
        let functions = Functions.functions()
        let sendVerificationEmail = functions.httpsCallable("sendVerificationEmail")
        
        sendVerificationEmail.call([
            "email": email,
            "verificationCode": verificationCode,
            "appName": "Thrifty"
        ]) { (result: HTTPSCallableResult?, error: Error?) in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("❌ Failed to send verification email: \(error.localizedDescription)")
                    
                    // Fallback to development mode
                    print("🔐 FALLBACK MODE: Verification code for \(email): \(verificationCode)")
                    print("📧 Email would contain: Your verification code is \(verificationCode)")
                    
                    self.verificationCodeSent = true
                    completion(true, "Verification code sent (check console for development code: \(verificationCode))")
                } else {
                    print("✅ Verification email sent successfully to \(email)")
                    self.verificationCodeSent = true
                    completion(true, "Verification code sent to \(email)")
                }
            }
        }
    }
    
    // Verify the email code
    func verifyEmailCode(email: String, code: String, completion: @escaping (Bool, String?) -> Void) {
        isLoading = true
        errorMessage = nil
        
    // Check for Apple employee hardcoded credentials
        if email.lowercased() == "apple@test.com" && code == "1234" {
            // Apple employee login - bypass normal verification
            let userData = UserData(
                id: "apple_employee_\(email.replacingOccurrences(of: "@", with: "_").replacingOccurrences(of: ".", with: "_"))",
                email: email,
                name: "Apple Employee",
                profileImageURL: nil,
                authProvider: .email
            )
            self.completeSignIn(with: userData)
            // Note: completeSignIn now handles resetting hasCompletedOnboarding
            self.clearVerificationData()
            completion(true, "Welcome Apple Employee!")
            return
        }
        
        // Check if we have a pending verification for this email
        guard let pendingEmail = pendingVerificationEmail,
              pendingEmail.lowercased() == email.lowercased() else {
            isLoading = false
            completion(false, "No verification code sent for this email")
            return
        }
        
        // Check if code matches and is not expired (valid for 10 minutes)
        guard let generatedCode = generatedVerificationCode,
              let generationTime = codeGenerationTime else {
            isLoading = false
            completion(false, "No verification code generated")
            return
        }
        
        // Check if code is expired (10 minutes)
        let timeElapsed = Date().timeIntervalSince(generationTime)
        if timeElapsed > 600 { // 10 minutes
            isLoading = false
            completion(false, "Verification code has expired. Please request a new one.")
            return
        }
        
        // Verify the code
        if code == generatedCode {
            // Code is correct, create user account or sign in
            Auth.auth().createUser(withEmail: email, password: UUID().uuidString) { [weak self] authResult, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if let error = error {
                        // If user already exists, try to sign in instead
                        if error.localizedDescription.contains("already in use") {
                            // User exists, treat as sign in
                            let userData = UserData(
                                id: "email_\(email.replacingOccurrences(of: "@", with: "_").replacingOccurrences(of: ".", with: "_"))",
                                email: email,
                                name: email.components(separatedBy: "@").first?.capitalized,
                                profileImageURL: nil,
                                authProvider: .email
                            )
                            self.completeSignIn(with: userData)
                            self.clearVerificationData()
                            completion(true, "Successfully signed in!")
                        } else {
                            self.isLoading = false
                            completion(false, "Failed to create account: \(error.localizedDescription)")
                        }
                    } else {
                        // Successfully created account
                        guard let firebaseUser = authResult?.user else {
                            self.isLoading = false
                            completion(false, "Failed to get user data")
                            return
                        }
                        
                        let userData = UserData(
                            id: firebaseUser.uid,
                            email: firebaseUser.email,
                            name: firebaseUser.email?.components(separatedBy: "@").first?.capitalized,
                            profileImageURL: nil,
                            authProvider: .email
                        )
                        
                        self.completeSignIn(with: userData)
                        self.clearVerificationData()
                        completion(true, "Account created successfully!")
                    }
                }
            }
        } else {
            isLoading = false
            completion(false, "Invalid verification code. Please try again.")
        }
    }
    
    // Resend verification code
    func resendVerificationCode(completion: @escaping (Bool, String?) -> Void) {
        guard let email = pendingVerificationEmail else {
            completion(false, "No email address for resending code")
            return
        }
        
        sendEmailVerificationCode(email: email, completion: completion)
    }
    
    // Clear verification data
    private func clearVerificationData() {
        pendingVerificationEmail = nil
        generatedVerificationCode = nil
        codeGenerationTime = nil
        verificationCodeSent = false
    }
    
    func completeSignIn(with userData: UserData) {
        currentUser = userData
        isLoggedIn = true
        isLoading = false
        // Load onboarding status from Firebase instead of resetting it
        loadOnboardingStatusFromFirebase()
        // Reset subscription status for new user - will be updated by Firebase call
        hasCompletedSubscription = false
        saveAuthenticationState()
        loadSubscriptionStatusFromFirebase()

        print("🔐 User signed in: \(userData.name ?? userData.email ?? "Unknown")")
        
        // Cache user email for future use
        if let email = userData.email {
            UserDefaults.standard.set(email, forKey: "recent_user_email")
            print("📧 Cached user email: \(email)")
            
            // Send pending Meta CAPI events now that we have user email
            // This ensures accurate conversion tracking with proper attribution
            PendingMetaEventService.shared.sendPendingPurchaseIfExists(userEmail: email)
        }
    }
    
    func markOnboardingCompleted() {
        hasCompletedOnboarding = true
        saveAuthenticationState()
        saveOnboardingStatusToFirebase()
        print("✅ Onboarding marked as completed")
    }
    
    func markSubscriptionCompleted() {
        hasCompletedSubscription = true
        isOnPaywallScreen = false  // Clear paywall state when subscription is completed
        saveAuthenticationState()
        saveSubscriptionStatusToFirebase()
        print("✅ Subscription marked as completed")
    }
    
    func setPaywallScreenState(_ isOnPaywall: Bool) {
        isOnPaywallScreen = isOnPaywall
        saveAuthenticationState()
        print("💳 Paywall screen state set to: \(isOnPaywall)")
    }
    
    func markFirstTimeCongratsPopupSeen() {
        hasSeenFirstTimeCongratsPopup = true
        saveAuthenticationState()
        print("🎉 First time congrats popup marked as seen")
    }
    
    func setGuestMode() {
        isLoggedIn = true
        currentUser = UserData(
            id: "guest_\(UUID().uuidString)",
            email: nil,
            name: "Guest User",
            profileImageURL: nil,
            authProvider: .email
        )
        saveAuthenticationState()
        print("👤 Set guest mode - user is now logged in")
    }
    
    private func saveOnboardingStatusToFirebase() {
        guard let email = currentUser?.email else {
            print("❌ No email available to save onboarding status")
            return
        }
        
        let db = Firestore.firestore()
        let onboardingData: [String: Any] = [
            "hasCompletedOnboarding": true,
            "completedAt": FieldValue.serverTimestamp(),
            "email": email,
            "userID": currentUser?.id ?? "unknown"
        ]
        
        // Use email as the document ID for cross-auth provider compatibility
        let emailKey = email.lowercased().replacingOccurrences(of: ".", with: "_").replacingOccurrences(of: "@", with: "_")
        db.collection("user_onboarding").document(emailKey).setData(onboardingData) { error in
            if let error = error {
                print("❌ Error saving onboarding status to Firebase: \(error.localizedDescription)")
            } else {
                print("✅ Successfully saved onboarding completion to Firebase for email: \(email)")
            }
        }
    }
    
    private func saveSubscriptionStatusToFirebase() {
        guard let email = currentUser?.email else {
            print("❌ No email available to save subscription status")
            return
        }
        
        let db = Firestore.firestore()
        let subscriptionData: [String: Any] = [
            "hasCompletedSubscription": true,
            "completedAt": FieldValue.serverTimestamp(),
            "email": email,
            "userID": currentUser?.id ?? "unknown"
        ]
        
        // Use email as the document ID for cross-auth provider compatibility
        let emailKey = email.lowercased().replacingOccurrences(of: ".", with: "_").replacingOccurrences(of: "@", with: "_")
        db.collection("user_subscriptions").document(emailKey).setData(subscriptionData) { error in
            if let error = error {
                print("❌ Error saving subscription status to Firebase: \(error.localizedDescription)")
            } else {
                print("✅ Successfully saved subscription completion to Firebase for email: \(email)")
            }
        }
    }
    
    private func loadOnboardingStatusFromFirebase() {
        guard let email = currentUser?.email else {
            print("❌ No email available to load onboarding status")
            hasCompletedOnboarding = false
            saveAuthenticationState()
            return
        }
        
        let db = Firestore.firestore()
        // Use email as the document ID for cross-auth provider compatibility
        let emailKey = email.lowercased().replacingOccurrences(of: ".", with: "_").replacingOccurrences(of: "@", with: "_")
        db.collection("user_onboarding").document(emailKey).getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error loading onboarding status from Firebase: \(error.localizedDescription)")
                    // On error, default to false (show onboarding)
                    self?.hasCompletedOnboarding = false
                    self?.saveAuthenticationState()
                    return
                }
                
                if let document = document, document.exists,
                   let data = document.data(),
                   let hasCompleted = data["hasCompletedOnboarding"] as? Bool {
                    self?.hasCompletedOnboarding = hasCompleted
                    self?.saveAuthenticationState()
                    print("✅ Loaded onboarding status from Firestore for email \(email): \(hasCompleted)")
                } else {
                    // No onboarding record found - user hasn't completed onboarding
                    print("📝 No onboarding status found in Firestore for email: \(email) - defaulting to false")
                    self?.hasCompletedOnboarding = false
                    self?.saveAuthenticationState()
                }
            }
        }
    }
    
    private func loadSubscriptionStatusFromFirebase() {
        guard let email = currentUser?.email else {
            print("❌ No email available to load subscription status")
            return
        }
        
        let db = Firestore.firestore()
        // Use email as the document ID for cross-auth provider compatibility
        let emailKey = email.lowercased().replacingOccurrences(of: ".", with: "_").replacingOccurrences(of: "@", with: "_")
        db.collection("user_subscriptions").document(emailKey).getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error loading subscription status from Firebase: \(error.localizedDescription)")
                    // On error, default to false (show onboarding)
                    self?.hasCompletedSubscription = false
                    self?.saveAuthenticationState()
                    return
                }
                
                if let document = document, document.exists,
                   let data = document.data(),
                   let hasCompleted = data["hasCompletedSubscription"] as? Bool {
                    self?.hasCompletedSubscription = hasCompleted
                    self?.saveAuthenticationState()
                    print("✅ Loaded subscription status from Firestore for email \(email): \(hasCompleted)")
                } else {
                    // No subscription record found - user hasn't completed subscription
                    print("📝 No subscription status found in Firestore for email: \(email) - defaulting to false")
                    self?.hasCompletedSubscription = false
                    self?.saveAuthenticationState()
                }
            }
        }
    }
    
    func deleteAccount(completion: @escaping (Bool, String?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(false, "No user is currently signed in")
            return
        }
        
        guard let email = currentUser?.email else {
            completion(false, "No email found for current user")
            return
        }
        
        isLoading = true
        
        let db = Firestore.firestore()
        let emailKey = email.lowercased().replacingOccurrences(of: ".", with: "_").replacingOccurrences(of: "@", with: "_")
        let userId = user.uid
        
        // Create a dispatch group to handle multiple async operations
        let group = DispatchGroup()
        var firestoreError: Error?
        
        // Delete user_onboarding document
        group.enter()
        db.collection("user_onboarding").document(emailKey).delete { error in
            if let error = error {
                print("❌ Error deleting onboarding data: \(error.localizedDescription)")
                firestoreError = error
            } else {
                print("✅ Deleted onboarding data for \(email)")
            }
            group.leave()
        }
        
        // Delete user_subscriptions document
        group.enter()
        db.collection("user_subscriptions").document(emailKey).delete { error in
            if let error = error {
                print("❌ Error deleting subscription data: \(error.localizedDescription)")
                firestoreError = error
            } else {
                print("✅ Deleted subscription data for \(email)")
            }
            group.leave()
        }
        
        // Delete all user data from users collection (nutrition goals, meals, profile, etc.)
        group.enter()
        db.collection("users").document(userId).delete { error in
            if let error = error {
                print("❌ Error deleting user profile data: \(error.localizedDescription)")
                firestoreError = error
            } else {
                print("✅ Deleted user profile data for \(userId)")
            }
            group.leave()
        }
        
        // Delete all subcollections under users/{userId}
        // Delete nutrition goals
        group.enter()
        db.collection("users").document(userId).collection("profile").document("nutrition_goals").delete { error in
            if let error = error {
                print("⚠️ Error deleting nutrition goals: \(error.localizedDescription)")
            } else {
                print("✅ Deleted nutrition goals")
            }
            group.leave()
        }
        
        // Delete streak data
        group.enter()
        db.collection("users").document(userId).collection("profile").document("streak").delete { error in
            if let error = error {
                print("⚠️ Error deleting streak data: \(error.localizedDescription)")
            } else {
                print("✅ Deleted streak data")
            }
            group.leave()
        }
        
        // Delete all meals (this requires getting all meal documents first)
        group.enter()
        db.collection("users").document(userId).collection("meals").getDocuments { snapshot, error in
            if let error = error {
                print("⚠️ Error fetching meals for deletion: \(error.localizedDescription)")
                group.leave()
                return
            }
            
            let mealDocs = snapshot?.documents ?? []
            if mealDocs.isEmpty {
                print("ℹ️ No meals to delete")
                group.leave()
                return
            }
            
            let mealGroup = DispatchGroup()
            for doc in mealDocs {
                mealGroup.enter()
                doc.reference.delete { error in
                    if let error = error {
                        print("⚠️ Error deleting meal document: \(error.localizedDescription)")
                    }
                    mealGroup.leave()
                }
            }
            
            mealGroup.notify(queue: .main) {
                print("✅ Deleted all meal documents (\(mealDocs.count) meals)")
                group.leave()
            }
        }
        
        // Wait for Firestore deletions to complete, then delete Firebase Auth account
        group.notify(queue: .main) { [weak self] in
            // Delete the Firebase Auth account
            user.delete { error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        print("❌ Error deleting Firebase Auth account: \(error.localizedDescription)")
                        self?.errorMessage = "Failed to delete account: \(error.localizedDescription)"
                        completion(false, error.localizedDescription)
                    } else {
                        print("✅ Successfully deleted Firebase Auth account for \(email)")
                        
                        // Sign out from Google if needed
                        GoogleSignIn.GIDSignIn.sharedInstance.signOut()
                        
                        // Clear all local data
                        self?.currentUser = nil
                        self?.isLoggedIn = false
                        self?.isLoading = false
                        self?.errorMessage = nil
                        self?.hasCompletedOnboarding = false
                        self?.hasCompletedSubscription = false
                        self?.isOnPaywallScreen = false
                        self?.hasSeenFirstTimeCongratsPopup = false
                        
                        // Clear cached data
                        UserDefaults.standard.removeObject(forKey: "recent_user_email")
                        UserDefaults.standard.removeObject(forKey: "pending_subscription")
                        self?.saveAuthenticationState()
                        
                        print("🗑️ Account deleted successfully")
                        completion(true, "Account deleted successfully")
                    }
                }
            }
        }
    }
    
    func logOut() {
        do {
            try Auth.auth().signOut()
            GoogleSignIn.GIDSignIn.sharedInstance.signOut() // Re-enabled with real CLIENT_ID
            
            currentUser = nil
            isLoggedIn = false
            isLoading = false
            errorMessage = nil
            hasCompletedOnboarding = false
            hasCompletedSubscription = false
            isOnPaywallScreen = false  // Clear paywall state on sign out
            hasSeenFirstTimeCongratsPopup = false  // Reset popup state on sign out
            
            // Clear cached email and pending subscription to prevent cross-user contamination
            UserDefaults.standard.removeObject(forKey: "recent_user_email")
            UserDefaults.standard.removeObject(forKey: "pending_subscription")
            print("📧 Cleared cached email and pending subscription on sign out")
            
            saveAuthenticationState()
            print("🚪 User logged out - redirecting to sign in")
        } catch {
            errorMessage = "Failed to log out: \(error.localizedDescription)"
        }
    }
    
    private func saveAuthenticationState() {
        UserDefaults.standard.set(isLoggedIn, forKey: isLoggedInKey)
        UserDefaults.standard.set(hasCompletedOnboarding, forKey: hasCompletedOnboardingKey)
        UserDefaults.standard.set(hasCompletedSubscription, forKey: hasCompletedSubscriptionKey)
        UserDefaults.standard.set(isOnPaywallScreen, forKey: isOnPaywallScreenKey)
        UserDefaults.standard.set(hasSeenFirstTimeCongratsPopup, forKey: hasSeenFirstTimeCongratsPopupKey)
        
        if let userData = currentUser,
           let encoded = try? JSONEncoder().encode(userData) {
            UserDefaults.standard.set(encoded, forKey: userDataKey)
        } else {
            UserDefaults.standard.removeObject(forKey: userDataKey)
        }
    }
    
    private func loadAuthenticationState() {
        // Default to false - users must sign in every time
        isLoggedIn = UserDefaults.standard.bool(forKey: isLoggedInKey)
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
        hasCompletedSubscription = UserDefaults.standard.bool(forKey: hasCompletedSubscriptionKey)
        isOnPaywallScreen = UserDefaults.standard.bool(forKey: isOnPaywallScreenKey)
        hasSeenFirstTimeCongratsPopup = UserDefaults.standard.bool(forKey: hasSeenFirstTimeCongratsPopupKey)
        
        if let data = UserDefaults.standard.data(forKey: userDataKey),
           let userData = try? JSONDecoder().decode(UserData.self, from: data) {
            currentUser = userData
        }
        
        // If we have user data but are not logged in, clear the user data
        if !isLoggedIn {
            currentUser = nil
        }
        

    }
    
    // Helper functions for Apple Sign In
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: Array<Character> =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// Apple Sign In Delegate
extension AuthenticationManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                errorMessage = "Invalid state: A login callback was received, but no login request was sent."
                isLoading = false
                return
            }
            
            guard let appleIDToken = appleIDCredential.identityToken else {
                errorMessage = "Unable to fetch Apple ID token"
                isLoading = false
                return
            }
            
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                errorMessage = "Unable to serialize Apple ID token"
                isLoading = false
                return
            }
            
            // Create Firebase credential with Apple ID token
            let credential = OAuthProvider.credential(withProviderID: "apple.com", idToken: idTokenString, rawNonce: nonce)
            
            // Sign in to Firebase with Apple credential
            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if let error = error {
                        self.errorMessage = "Firebase authentication failed: \(error.localizedDescription)"
                        self.isLoading = false
                        return
                    }
                    
                    guard let firebaseUser = authResult?.user else {
                        self.errorMessage = "Failed to get Firebase user"
                        self.isLoading = false
                        return
                    }
                    
                    // Create UserData with Firebase user info
                    let userData = UserData(
                        id: firebaseUser.uid,
                        email: firebaseUser.email ?? appleIDCredential.email,
                        name: firebaseUser.displayName ?? appleIDCredential.fullName?.formatted(),
                        profileImageURL: firebaseUser.photoURL?.absoluteString,
                        authProvider: .apple
                    )
                    
                    self.completeSignIn(with: userData)
                    print("✅ Apple Sign In successful - Firebase user created: \(firebaseUser.uid)")
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        isLoading = false
        
        // Check if error is user cancellation (error code 1001)
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                // User cancelled - this is normal, don't show error
                print("🔐 Apple Sign In cancelled by user")
                return
            case .unknown:
                errorMessage = "Apple Sign In failed: Unknown error occurred"
            case .invalidResponse:
                errorMessage = "Apple Sign In failed: Invalid response received"
            case .notHandled:
                errorMessage = "Apple Sign In failed: Request not handled"
            case .failed:
                errorMessage = "Apple Sign In failed: Authentication failed"
            default:
                errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
            }
        } else {
            errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
        }
        
        print("❌ Apple Sign In error: \(error)")
    }
}

// Presentation Context Provider
extension AuthenticationManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available")
        }
        return window
    }
}

// Enhanced ProfileManager for user data tracking
@MainActor
class ProfileManager: ObservableObject {
    static let shared = ProfileManager()
    
    @Published var profilePicture: String = "tool-bg4"
    @Published var customProfileImage: UIImage?
    @Published var userName: String = "@thriftuser438"
    @Published var totalWordsWritten: Int = 0
    @Published var profitRefreshTrigger: Int = 0
    
    private let userNameKey = "ProfileManager_UserName"
    private let profilePictureKey = "ProfileManager_ProfilePicture"
    private let totalWordsKey = "ProfileManager_TotalWords"
    private let customImageKey = "ProfileManager_CustomImage"
    
    private init() {
        // Load immediately since this is a singleton
        loadUserData()
    }
    
    func updateUserName(_ name: String) {
        // Clean the input: lowercase, alphanumeric only
        let cleanedName = name.lowercased().filter { $0.isLetter || $0.isNumber }
        
        // Ensure username always starts with @
        if cleanedName.isEmpty {
            userName = "@thriftuser438"
        } else {
            userName = "@" + cleanedName
        }
        saveUserData()
    }
    
    func addWordsWritten(_ wordCount: Int) {
        totalWordsWritten += wordCount
        saveUserData()
    }
    
    func countWordsInText(_ text: String) -> Int {
        // Handle empty or whitespace-only text
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty {
            return 0
        }
        
        // Split by whitespace and newlines, filter out empty strings
        let words = trimmedText.components(separatedBy: .whitespacesAndNewlines)
        let validWords = words.filter { !$0.isEmpty }
        
        return validWords.count
    }
    
    func calculateTotalProfit(from songManager: SongManager) -> Double {
        var totalProfit: Double = 0.0
        
        for song in songManager.songs {
            // Get saved values for this song
            let savedAvgPrice = UserDefaults.standard.double(forKey: "avgPrice_\(song.id)")
            let savedSellPrice = UserDefaults.standard.double(forKey: "sellPrice_\(song.id)")
            let savedProfitOverride = UserDefaults.standard.string(forKey: "profitOverride_\(song.id)") ?? ""
            let savedUseCustomProfit = UserDefaults.standard.bool(forKey: "useCustomProfit_\(song.id)")
            
            // Calculate profit for this song
            if savedUseCustomProfit && !savedProfitOverride.isEmpty {
                totalProfit += Double(savedProfitOverride) ?? 0
            } else if savedAvgPrice > 0 && savedSellPrice > 0 {
                totalProfit += savedSellPrice - savedAvgPrice
            }
        }
        
        return totalProfit
    }
    
    func triggerProfitRefresh() {
        profitRefreshTrigger += 1
    }
    
    func saveUserData() {
        UserDefaults.standard.set(userName, forKey: userNameKey)
        UserDefaults.standard.set(profilePicture, forKey: profilePictureKey)
        UserDefaults.standard.set(totalWordsWritten, forKey: totalWordsKey)
        
        // Save custom image data
        if let customImage = customProfileImage,
           let imageData = customImage.jpegData(compressionQuality: 0.7) {
            UserDefaults.standard.set(imageData, forKey: customImageKey)
        }
    }
    
    private func loadUserData() {
        let loadedName = UserDefaults.standard.string(forKey: userNameKey) ?? "@thriftuser438"
        // Clean and validate loaded username
        let nameWithoutAt = loadedName.hasPrefix("@") ? String(loadedName.dropFirst()) : loadedName
        let cleanedName = nameWithoutAt.lowercased().filter { $0.isLetter || $0.isNumber }
        
        if cleanedName.isEmpty {
            userName = "@thriftuser438"
        } else {
            userName = "@" + cleanedName
        }
        
        profilePicture = UserDefaults.standard.string(forKey: profilePictureKey) ?? "tool-bg4"
        totalWordsWritten = UserDefaults.standard.integer(forKey: totalWordsKey)
        
        // Load custom image
        if let imageData = UserDefaults.standard.data(forKey: customImageKey),
           let image = UIImage(data: imageData) {
            customProfileImage = image
        }
    }
}




// MARK: - Meal Plans

struct DayMealPlan: Identifiable {
    let id = UUID()
    let day: String
    let breakfast: String
    let lunch: String
    let dinner: String
    let snack: String
}

class MealPlanService: ObservableObject {
    static let shared = MealPlanService()

    @Published var mealPlan: [DayMealPlan] = []
    @Published var shoppingList: [String] = []
    @Published var isGeneratingPlan = false
    @Published var isGeneratingList = false

    private let apiKey = FoodAnalysisService.openAIKey
    private let endpoint = "https://api.openai.com/v1/chat/completions"

    func generateMealPlan(ageStage: String, restrictions: [String]) async {
        await MainActor.run {
            isGeneratingPlan = true
            mealPlan = []
            shoppingList = []
        }

        let restrictionText = restrictions.isEmpty
            ? "No dietary restrictions."
            : "Dietary restrictions: \(restrictions.joined(separator: ", "))."

        let textureGuide: String
        switch ageStage {
        case "4–6 months": textureGuide = "Smooth, single-ingredient purees only (no chunks, no combos)."
        case "6–9 months": textureGuide = "Mashed and lightly lumpy foods, simple 2-ingredient combos."
        case "9–12 months": textureGuide = "Soft finger foods and bite-sized pieces, more complex flavours."
        default: textureGuide = "Soft family foods in baby-appropriate portions, varied textures."
        }

        let prompt = """
        Generate a 7-day meal plan for a \(ageStage) baby. \(restrictionText)
        Texture guide: \(textureGuide)

        Return ONLY valid JSON, no markdown, no explanation:
        {
          "days": [
            { "day": "Monday", "breakfast": "...", "lunch": "...", "dinner": "...", "snack": "..." },
            { "day": "Tuesday", "breakfast": "...", "lunch": "...", "dinner": "...", "snack": "..." },
            { "day": "Wednesday", "breakfast": "...", "lunch": "...", "dinner": "...", "snack": "..." },
            { "day": "Thursday", "breakfast": "...", "lunch": "...", "dinner": "...", "snack": "..." },
            { "day": "Friday", "breakfast": "...", "lunch": "...", "dinner": "...", "snack": "..." },
            { "day": "Saturday", "breakfast": "...", "lunch": "...", "dinner": "...", "snack": "..." },
            { "day": "Sunday", "breakfast": "...", "lunch": "...", "dinner": "...", "snack": "..." }
          ]
        }

        Rules:
        - Each meal: max 7 words, descriptive and appetising
        - Never include honey, added salt, added sugar, whole nuts, or raw hard vegetables
        - Vary proteins, colours, and food groups across the week
        - Include iron-rich foods at least 3 times per week
        """

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 800,
            "temperature": 0.7
        ]

        guard let json = try? JSONSerialization.data(withJSONObject: body),
              let url = URL(string: endpoint) else {
            await MainActor.run { isGeneratingPlan = false }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = json

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let resp = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = resp["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let msg = first["message"] as? [String: Any],
                  let content = msg["content"] as? String else {
                await MainActor.run { isGeneratingPlan = false }
                return
            }

            let cleaned = content
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let planData = cleaned.data(using: .utf8),
                  let planJson = try? JSONSerialization.jsonObject(with: planData) as? [String: Any],
                  let days = planJson["days"] as? [[String: Any]] else {
                await MainActor.run { isGeneratingPlan = false }
                return
            }

            let parsed = days.compactMap { d -> DayMealPlan? in
                guard let day = d["day"] as? String,
                      let breakfast = d["breakfast"] as? String,
                      let lunch = d["lunch"] as? String,
                      let dinner = d["dinner"] as? String,
                      let snack = d["snack"] as? String else { return nil }
                return DayMealPlan(day: day, breakfast: breakfast, lunch: lunch, dinner: dinner, snack: snack)
            }

            await MainActor.run {
                mealPlan = parsed
                isGeneratingPlan = false
            }
        } catch {
            await MainActor.run { isGeneratingPlan = false }
        }
    }

    func generateShoppingList() async {
        guard !mealPlan.isEmpty else { return }
        await MainActor.run { isGeneratingList = true }

        let planText = mealPlan.map {
            "\($0.day): Breakfast: \($0.breakfast) | Lunch: \($0.lunch) | Dinner: \($0.dinner) | Snack: \($0.snack)"
        }.joined(separator: "\n")

        let prompt = """
        Based on this 7-day baby meal plan:
        \(planText)

        Generate a consolidated shopping list with quantities.
        Return ONLY valid JSON, no markdown:
        {
          "items": [
            "Sweet potatoes (4 medium)",
            "Avocado (3)",
            "Rolled oats (1 cup)"
          ]
        }

        Rules:
        - Group by category: Produce first, then Grains, Proteins, Dairy/Alternatives, Pantry
        - Consolidate duplicates across the week
        - 15–25 items maximum
        - Include realistic quantities for a baby (small amounts)
        """

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 400,
            "temperature": 0.3
        ]

        guard let json = try? JSONSerialization.data(withJSONObject: body),
              let url = URL(string: endpoint) else {
            await MainActor.run { isGeneratingList = false }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = json

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let resp = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = resp["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let msg = first["message"] as? [String: Any],
                  let content = msg["content"] as? String else {
                await MainActor.run { isGeneratingList = false }
                return
            }

            let cleaned = content
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let listData = cleaned.data(using: .utf8),
                  let listJson = try? JSONSerialization.jsonObject(with: listData) as? [String: Any],
                  let items = listJson["items"] as? [String] else {
                await MainActor.run { isGeneratingList = false }
                return
            }

            await MainActor.run {
                shoppingList = items
                isGeneratingList = false
            }
        } catch {
            await MainActor.run { isGeneratingList = false }
        }
    }
}

struct MealPlanView: View {
    @StateObject private var service = MealPlanService.shared
    @State private var selectedAgeStage = "6–9 months"
    @State private var selectedRestrictions: Set<String> = []
    @State private var showShoppingList = false
    @State private var checkedItems: Set<String> = []

    private let ageStages = ["4–6 months", "6–9 months", "9–12 months", "12+ months"]
    private let restrictions = ["Vegetarian", "Dairy-free", "Gluten-free", "Nut-free", "Egg-free"]
    private let mealIcons = ["breakfast": "☀️", "lunch": "🌤️", "dinner": "🌙", "snack": "🍎"]

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.98, green: 0.94, blue: 0.96),
                    Color(red: 0.96, green: 0.93, blue: 0.98)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("🍽️ Meal Plans")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.black)
                            Text("AI-generated, age-appropriate weekly plans")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Age stage selector
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Baby's age stage")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(ageStages, id: \.self) { stage in
                                    Button(action: { selectedAgeStage = stage }) {
                                        Text(stage)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(selectedAgeStage == stage ? .white : .black)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 9)
                                            .background(
                                                selectedAgeStage == stage
                                                    ? Color(red: 0.15, green: 0.15, blue: 0.20)
                                                    : Color.white
                                            )
                                            .clipShape(Capsule())
                                            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    // Dietary restrictions
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Dietary needs")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(restrictions, id: \.self) { r in
                                    Button(action: {
                                        if selectedRestrictions.contains(r) {
                                            selectedRestrictions.remove(r)
                                        } else {
                                            selectedRestrictions.insert(r)
                                        }
                                    }) {
                                        HStack(spacing: 5) {
                                            if selectedRestrictions.contains(r) {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 11, weight: .bold))
                                            }
                                            Text(r)
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                        .foregroundColor(selectedRestrictions.contains(r) ? .white : .black)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 9)
                                        .background(
                                            selectedRestrictions.contains(r)
                                                ? Color(red: 0.83, green: 0.69, blue: 0.52)
                                                : Color.white
                                        )
                                        .clipShape(Capsule())
                                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }

                    // Generate button
                    Button(action: {
                        Task {
                            await service.generateMealPlan(
                                ageStage: selectedAgeStage,
                                restrictions: Array(selectedRestrictions)
                            )
                        }
                    }) {
                        HStack(spacing: 10) {
                            if service.isGeneratingPlan {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                                Text("Generating your plan...")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(service.mealPlan.isEmpty ? "Generate Week Plan" : "Regenerate Plan")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            service.isGeneratingPlan
                                ? Color.gray.opacity(0.5)
                                : Color(red: 0.15, green: 0.15, blue: 0.20)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                    }
                    .disabled(service.isGeneratingPlan)
                    .padding(.horizontal, 20)

                    // Meal plan cards
                    if !service.mealPlan.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(service.mealPlan) { day in
                                DayMealCard(day: day)
                            }
                        }
                        .padding(.horizontal, 20)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))

                        // Shopping list button
                        Button(action: {
                            if service.shoppingList.isEmpty {
                                Task { await service.generateShoppingList() }
                            } else {
                                showShoppingList = true
                            }
                        }) {
                            HStack(spacing: 10) {
                                if service.isGeneratingList {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.9)
                                    Text("Building shopping list...")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                } else {
                                    Text("🛒")
                                        .font(.system(size: 18))
                                    Text(service.shoppingList.isEmpty ? "Get Shopping List" : "View Shopping List (\(service.shoppingList.count))")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color(red: 0.83, green: 0.69, blue: 0.52))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color(red: 0.83, green: 0.69, blue: 0.52).opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .disabled(service.isGeneratingList)
                        .padding(.horizontal, 20)
                        .onChange(of: service.shoppingList.count) { count in
                            if count > 0 {
                                checkedItems = []
                                showShoppingList = true
                            }
                        }
                    }

                    Spacer(minLength: 100)
                }
            }
        }
        .sheet(isPresented: $showShoppingList) {
            ShoppingListSheet(
                items: service.shoppingList,
                checkedItems: $checkedItems
            )
        }
        .preferredColorScheme(.light)
    }
}

struct DayMealCard: View {
    let day: DayMealPlan

    var body: some View {
        VStack(spacing: 0) {
            // Day header
            HStack {
                Text(day.day.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(red: 0.15, green: 0.15, blue: 0.20))

            // Meals
            VStack(spacing: 0) {
                MealRow(icon: "☀️", label: "Breakfast", meal: day.breakfast)
                Divider().padding(.horizontal, 16)
                MealRow(icon: "🌤️", label: "Lunch", meal: day.lunch)
                Divider().padding(.horizontal, 16)
                MealRow(icon: "🌙", label: "Dinner", meal: day.dinner)
                Divider().padding(.horizontal, 16)
                MealRow(icon: "🍎", label: "Snack", meal: day.snack)
            }
            .background(Color.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
    }
}

struct MealRow: View {
    let icon: String
    let label: String
    let meal: String

    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 18))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(meal)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct ShoppingListSheet: View {
    let items: [String]
    @Binding var checkedItems: Set<String>
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(items, id: \.self) { item in
                    Button(action: {
                        if checkedItems.contains(item) {
                            checkedItems.remove(item)
                        } else {
                            checkedItems.insert(item)
                        }
                    }) {
                        HStack(spacing: 14) {
                            Image(systemName: checkedItems.contains(item) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundColor(checkedItems.contains(item) ? Color(red: 0.83, green: 0.69, blue: 0.52) : .gray)

                            Text(item)
                                .font(.system(size: 15))
                                .foregroundColor(checkedItems.contains(item) ? .gray : .black)
                                .strikethrough(checkedItems.contains(item))
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("🛒 Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !checkedItems.isEmpty {
                        Button("Clear") { checkedItems = [] }
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

struct MainAppView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var selectedDay = 5 // Tuesday is selected (index 5 in the week)
    @State private var selectedTab = 0 // Start with Home tab
    @State private var streakCount = 0
    @State private var showAddMenu = false
    @State private var showScanFlow = false
    @State private var showFoodDatabase = false
    @State private var confettiTrigger = 0
    @State private var refreshID = UUID()
    @AppStorage("hasSeenMainAppConfetti") private var hasSeenMainAppConfetti = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.97, green: 0.97, blue: 0.98),
                        Color(red: 0.96, green: 0.96, blue: 0.97)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Tab Content
                if selectedTab == 0 {
                    HomeView(selectedDay: $selectedDay, streakCount: $streakCount)
                } else if selectedTab == 1 {
                    MealPlanView()
                } else if selectedTab == 2 {
                    BabyFoodChatView()
                } else if selectedTab == 3 {
                    ProfileView()
                        .environmentObject(authManager)
                }
                
                // Bottom Navigation
                VStack {
                    Spacer()
                    
                    ZStack {
                        // Tab Bar Background - solid white for consistency
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: -4)
                            .frame(height: 82 + geometry.safeAreaInsets.bottom)
                        
                        HStack(spacing: 0) {
                            // Home Tab
                            TabButton(icon: "house.fill", label: NSLocalizedString("Home", comment: ""), isSelected: selectedTab == 0) {
                                selectedTab = 0
                            }
                            
                            // Meal Plans Tab
                            TabButton(icon: "fork.knife", label: "Meals", isSelected: selectedTab == 1) {
                                selectedTab = 1
                            }
                            
                            // Chat Tab
                            TabButton(icon: "bubble.left.and.bubble.right.fill", label: "AI Chat", isSelected: selectedTab == 2) {
                                selectedTab = 2
                            }
                            
                            // Profile Tab
                            TabButton(icon: "person.fill", label: NSLocalizedString("Profile", comment: ""), isSelected: selectedTab == 3) {
                                selectedTab = 3
                            }
                            
                            // Add Button
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showAddMenu.toggle()
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.15, green: 0.15, blue: 0.20))
                                        .frame(width: 56, height: 56)
                                    
                                    Image(systemName: showAddMenu ? "xmark" : "plus")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .offset(x: -8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 18))
                    }
                }
                .ignoresSafeArea(edges: .bottom)
                
                // Add Menu Overlay
                if showAddMenu {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showAddMenu = false
                            }
                        }
                    
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                // Food Database Button
                                Button(action: {
                                    // Open food database
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        showAddMenu = false
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showFoodDatabase = true
                                    }
                                }) {
                                    VStack(spacing: 16) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 48, weight: .regular))
                                            .foregroundColor(.black)
                                        
                                        Text("food_database")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(.black)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                    .background(Color.white)
                                    .cornerRadius(24)
                                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                                }
                                
                                // Scan Food Button
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        showAddMenu = false
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showScanFlow = true
                                    }
                                }) {
                                    VStack(spacing: 16) {
                                        Image(systemName: "camera.viewfinder")
                                            .font(.system(size: 48, weight: .regular))
                                            .foregroundColor(.black)
                                        
                                        Text("scan_food")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(.black)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                    .background(Color.white)
                                    .cornerRadius(24)
                                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 120)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Scan Flow Overlay
                if showScanFlow {
                    FoodScanFlow(isPresented: $showScanFlow)
                        .transition(.move(edge: .bottom))
                }
            }
        }
        .fullScreenCover(isPresented: $showFoodDatabase) {
            LegacyFoodDatabaseView(isPresented: $showFoodDatabase)
        }
        .confettiCannon(
            trigger: $confettiTrigger,
            num: 50,
            colors: [.red, .yellow, .blue, .green, .purple, .pink, .orange, .cyan],
            confettiSize: 10,
            radius: 400
        )
        .id(refreshID)
        .onChange(of: languageManager.currentLanguage) { _ in
            // Force complete view refresh when language changes
            refreshID = UUID()
        }
        .onAppear {
            // Show confetti only on first time entering main app
            if !hasSeenMainAppConfetti {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    confettiTrigger += 1
                    hasSeenMainAppConfetti = true
                }
            }
        }
    }
    
    func requestCameraAccess() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    print("Camera access granted")
                    // Open camera scanner here
                } else {
                    print("Camera access denied")
                    // Show alert or message to user
                }
            }
        }
    }
}

// MARK: - Baby Food Chat

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
    let timestamp: Date
    var isUser: Bool { role == "user" }
}

class BabyFoodChatService: ObservableObject {
    static let shared = BabyFoodChatService()
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false

    private let apiKey = FoodAnalysisService.openAIKey
    private let endpoint = "https://api.openai.com/v1/chat/completions"

    private let systemPrompt = """
    You are a warm, knowledgeable baby nutrition expert and chef. You help mothers confidently introduce solid foods to their babies.

    Your expertise includes:
    - Age-appropriate food introductions:
      • 4–6 months: smooth single-ingredient purees (sweet potato, peas, banana)
      • 6–9 months: mashed/lumpy foods, soft combinations
      • 9–12 months: soft finger foods, bite-sized pieces
      • 12+ months: most family foods in appropriate textures
    - Safe textures for each developmental stage
    - Allergen introduction (eggs, peanuts, dairy, tree nuts, wheat, soy, fish, shellfish) — introduce one at a time, wait 3–5 days between new allergens
    - Nutritional priorities: iron, zinc, vitamin D, B12, calcium, omega-3s
    - Baby-led weaning vs spoon feeding approaches
    - Foods to AVOID under 12 months: honey, added salt, added sugar, cow's milk as main drink, whole nuts, hard raw vegetables, popcorn, large chunks
    - Batch cooking and leftover tips
    - Signs of food allergies: hives, vomiting, swelling — always refer to pediatrician for concerns

    Tone: warm, encouraging, and practical. Keep responses concise (2–4 short paragraphs or bullet points). Format recipes clearly with an ingredients list and numbered steps. Always end allergy/safety advice with "When in doubt, check with your pediatrician. 👨‍⚕️"
    """

    func sendMessage(_ content: String) async {
        let userMsg = ChatMessage(role: "user", content: content, timestamp: Date())
        let history: [ChatMessage] = await MainActor.run {
            messages.append(userMsg)
            isLoading = true
            return messages
        }

        var apiMessages: [[String: String]] = [["role": "system", "content": systemPrompt]]
        for msg in history { apiMessages.append(["role": msg.role, "content": msg.content]) }

        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": apiMessages,
            "max_tokens": 600,
            "temperature": 0.7
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody),
              let url = URL(string: endpoint) else {
            await MainActor.run { isLoading = false }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let message = first["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                await MainActor.run { isLoading = false }
                return
            }
            let aiMsg = ChatMessage(role: "assistant", content: content.trimmingCharacters(in: .whitespacesAndNewlines), timestamp: Date())
            await MainActor.run {
                messages.append(aiMsg)
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    func reset() { messages = [] }
}

struct BabyFoodChatView: View {
    @StateObject private var chatService = BabyFoodChatService.shared
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool

    private let quickPrompts = [
        "What can my 6-month-old eat?",
        "Iron-rich foods for babies",
        "How to introduce peanuts safely",
        "Butternut squash puree recipe",
        "Foods to avoid under 12 months",
        "Baby-led weaning tips"
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.98, green: 0.94, blue: 0.96),
                    Color(red: 0.96, green: 0.93, blue: 0.98)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    HStack(spacing: 10) {
                        Text("👶")
                            .font(.system(size: 30))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Baby Food AI")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                            Text("Your personal nutrition guide")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                    Spacer()
                    if !chatService.messages.isEmpty {
                        Button(action: { withAnimation { chatService.reset() } }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.gray)
                                .frame(width: 36, height: 36)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Message area
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if chatService.messages.isEmpty {
                                // Empty state
                                VStack(spacing: 28) {
                                    Spacer(minLength: 20)
                                    VStack(spacing: 12) {
                                        Text("🥣")
                                            .font(.system(size: 64))
                                        Text("Ask me anything about\nbaby food & nutrition")
                                            .font(.system(size: 18, weight: .semibold))
                                            .multilineTextAlignment(.center)
                                            .foregroundColor(.black)
                                        Text("I'll help you introduce foods safely\nand confidently at every stage.")
                                            .font(.system(size: 14))
                                            .multilineTextAlignment(.center)
                                            .foregroundColor(.gray)
                                    }
                                    // Quick prompts grid
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Try asking:")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.gray)
                                            .padding(.horizontal, 20)
                                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                            ForEach(quickPrompts, id: \.self) { prompt in
                                                Button(action: {
                                                    inputText = prompt
                                                    sendMessage()
                                                }) {
                                                    Text(prompt)
                                                        .font(.system(size: 13, weight: .medium))
                                                        .multilineTextAlignment(.leading)
                                                        .foregroundColor(.black)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                        .padding(.horizontal, 14)
                                                        .padding(.vertical, 12)
                                                        .background(Color.white)
                                                        .cornerRadius(14)
                                                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                    Spacer(minLength: 120)
                                }
                            } else {
                                ForEach(chatService.messages) { msg in
                                    ChatBubbleView(message: msg)
                                        .id(msg.id)
                                }
                                if chatService.isLoading {
                                    TypingIndicatorView()
                                        .id("typing")
                                }
                                Color.clear.frame(height: 20).id("bottom")
                            }
                        }
                    }
                    .onChange(of: chatService.messages.count) { _ in
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                    .onChange(of: chatService.isLoading) { _ in
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }

                // Input bar
                VStack(spacing: 0) {
                    Divider().opacity(0.3)
                    HStack(spacing: 10) {
                        TextField("Ask about baby food...", text: $inputText, axis: .vertical)
                            .font(.system(size: 15))
                            .lineLimit(1...4)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .background(Color.white)
                            .cornerRadius(22)
                            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                            .focused($isInputFocused)
                            .onSubmit { sendMessage() }

                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(
                                    inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatService.isLoading
                                        ? Color.gray.opacity(0.35)
                                        : Color(red: 0.15, green: 0.15, blue: 0.20)
                                )
                                .clipShape(Circle())
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatService.isLoading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.98, green: 0.94, blue: 0.96))
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !chatService.isLoading else { return }
        inputText = ""
        isInputFocused = false
        Task { await chatService.sendMessage(text) }
    }
}

struct ChatBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom) {
            if message.isUser {
                Spacer(minLength: 64)
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.15, green: 0.15, blue: 0.20))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
                Spacer(minLength: 64)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

struct TypingIndicatorView: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animating ? 1.3 : 0.7)
                        .animation(
                            .easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
            Spacer(minLength: 64)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onAppear { animating = true }
    }
}

// MARK: - Home View
struct HomeView: View {
    @Binding var selectedDay: Int
    @Binding var streakCount: Int
    @StateObject private var foodDataManager = FoodDataManager.shared
    @State private var selectedDate: Date = Date()
    @State private var weekDays: [Date] = []
    @State private var daysWithMeals: Set<String> = []
    @State private var macroPageIndex = 0
    
    private let calendar = Calendar.current
    
    // Get actual week days starting from Sunday
    private func getWeekDays() -> [Date] {
        let today = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek)
        }
    }
    
    // Check if date is today
    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }
    
    // Get day number from date
    private func dayNumber(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    // Get day name from date
    private func dayName(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        let fullName = formatter.string(from: date)
        return String(fullName.prefix(1))
    }
    
    // Check if date has logged meals
    private func hasLoggedMeals(_ date: Date) -> Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        return daysWithMeals.contains(dateString)
    }
    
    // Load which days in the week have meals
    private func loadWeekMeals() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        var mealsSet: Set<String> = []
        let group = DispatchGroup()
        
        for date in weekDays {
            let dateString = dateFormatter.string(from: date)
            group.enter()
            
            db.collection("users")
                .document(userId)
                .collection("meals")
                .document(dateString)
                .collection("items")
                .getDocuments { snapshot, error in
                    if let documents = snapshot?.documents, !documents.isEmpty {
                        mealsSet.insert(dateString)
                    }
                    group.leave()
                }
        }
        
        group.notify(queue: .main) {
            daysWithMeals = mealsSet
        }
    }
    
    var body: some View {
        ZStack {
            // Soft gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.98, green: 0.94, blue: 0.96),
                    Color(red: 0.96, green: 0.93, blue: 0.98)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
        VStack(spacing: 0) {
            // Top Header
            HStack {
                HStack(spacing: 7) {
                    Text("👶")
                        .font(.system(size: 28))
                    Text("Little Bites")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                // Streak counter
                HStack(spacing: 5) {
                    Text("🔥")
                        .font(.system(size: 15))
                    Text("\(foodDataManager.streakCount)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(Color.white)
                .cornerRadius(22)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .onAppear {
                weekDays = getWeekDays()
                selectedDate = Date()
                loadWeekMeals()
                foodDataManager.loadMealsForToday()
                foodDataManager.loadStreak()
                streakCount = foodDataManager.streakCount
            }
            .onChange(of: foodDataManager.streakCount) { newValue in
                streakCount = newValue
            }
            .onChange(of: foodDataManager.todaysMeals) { _ in
                // Reload week meals when meals change
                loadWeekMeals()
            }
            
            // Week View
            HStack(spacing: 0) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { index, date in
                    let isTodayDate = isToday(date)
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    let hasMeals = hasLoggedMeals(date)
                    
                    VStack(spacing: 7) {
                        Text(dayName(from: date))
                            .font(.system(size: 12, weight: .regular))
                            .kerning(0.2)
                            .foregroundColor(isSelected ? .black : Color.black.opacity(0.35))
                        
                            ZStack {
                            if isSelected {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 30, height: 30)
                                
                                Circle()
                                    .stroke(Color(red: 0.92, green: 0.58, blue: 0.65), lineWidth: 2)
                                    .frame(width: 30, height: 30)
                            } else if isTodayDate {
                                // Today but not selected - show subtle indicator
                                Circle()
                                    .stroke(Color(red: 0.92, green: 0.58, blue: 0.65), lineWidth: 1.5)
                                    .frame(width: 30, height: 30)
                            } else {
                                DashedCircle(lineWidth: 1.5, dashLength: 3, color: Color(red: 0.92, green: 0.58, blue: 0.65).opacity(0.5))
                                    .frame(width: 30, height: 30)
                            }
                            
                            Text(dayNumber(from: date))
                                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                                .foregroundColor(isSelected ? .black : Color.black.opacity(0.3))
                            
                            // Checkmark indicator for days with logged meals
                            if hasMeals && !isSelected {
                                Circle()
                                    .fill(Color(red: 0.92, green: 0.58, blue: 0.65))
                                    .frame(width: 8, height: 8)
                                    .offset(x: 12, y: -12)
                            }
                        }
                    }
                    .padding(.vertical, isSelected ? 10 : 0)
                    .padding(.horizontal, isSelected ? 6 : 0)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isSelected ? Color.white : Color.clear)
                            .shadow(color: isSelected ? Color.black.opacity(0.06) : Color.clear, radius: 8, x: 0, y: 2)
                    )
                    .frame(maxWidth: .infinity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            selectedDate = date
                            // Load meals for selected date
                            Task {
                                let meals = await foodDataManager.loadMealsForDate(date)
                                await MainActor.run {
                                    foodDataManager.todaysMeals = meals
                                    foodDataManager.calculateDailyTotals()
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    // Main Calorie Card
                    ZStack {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.white)
                            .opacity(1.0) // Ensure fully opaque
                            .shadow(color: Color.black.opacity(0.04), radius: 20, x: 0, y: 6)
                        
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 10) {
                                let remainingCalories = foodDataManager.getRemainingNutrition().calories
                                let isOverLimit = remainingCalories < 0
                                
                                Text("\(remainingCalories)")
                                    .font(.system(size: 45, weight: .bold))
                                    .kerning(-2.5)
                                    .foregroundColor(isOverLimit ? Color(red: 0.90, green: 0.50, blue: 0.55) : .black)
                                
                                HStack(spacing: 8) {
                                    Text(isOverLimit ? "Calories over" : "Calories left")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(isOverLimit ? Color(red: 0.90, green: 0.50, blue: 0.55).opacity(0.7) : Color.black.opacity(0.5))
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "brain.head.profile")
                                            .font(.system(size: 11))
                                            .foregroundColor(Color.black.opacity(0.5))
                                        Text("+\(foodDataManager.todaysMeals.count)")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color.black.opacity(0.5))
                                    }
                                }
                            }
                            .padding(.leading, 34)
                            
                            Spacer()
                            
                            ZStack {
                                let progress = min(1.0, CGFloat(foodDataManager.dailyTotals.calories) / CGFloat(max(1, foodDataManager.nutritionGoals.dailyCalories)))
                                let isOverLimit = foodDataManager.dailyTotals.calories > foodDataManager.nutritionGoals.dailyCalories
                                
                                Circle()
                                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 6)
                                    .frame(width: 128, height: 128)
                                
                                // Progress circle
                                Circle()
                                    .trim(from: 0, to: progress)
                                    .stroke(
                                        isOverLimit ? Color(red: 0.90, green: 0.50, blue: 0.55) : Color(red: 0.92, green: 0.58, blue: 0.65),
                                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                    )
                                    .frame(width: 128, height: 128)
                                    .rotationEffect(.degrees(-90))
                                
                                Text("✨")
                                    .font(.system(size: 42))
                            }
                            .padding(.trailing, 30)
                        }
                        .padding(.vertical, 28)
                    }
                    .frame(height: 190)
                    .padding(.horizontal, 20)
                    
                    // Macro Cards - Swipeable
                    TabView(selection: $macroPageIndex) {
                        // Page 1: Protein, Carbs, Fats
                        HStack(spacing: 12) {
                            let remainingNutrition = foodDataManager.getRemainingNutrition()
                            let dailyTotals = foodDataManager.dailyTotals
                            let goals = foodDataManager.nutritionGoals
                            
                            MacroCard(
                                amount: "\(remainingNutrition.protein)g",
                                label: NSLocalizedString("Protein", comment: "") + " " + NSLocalizedString("left", comment: ""),
                                icon: "🍗",
                                circleColor: Color(red: 0.85, green: 0.75, blue: 0.92).opacity(0.6),
                                value: remainingNutrition.protein,
                                consumed: dailyTotals.protein,
                                goal: goals.protein
                            )
                            .frame(maxWidth: .infinity)
                            
                            MacroCard(
                                amount: "\(remainingNutrition.carbs)g",
                                label: NSLocalizedString("Carbs", comment: "") + " " + NSLocalizedString("left", comment: ""),
                                icon: "🌾",
                                circleColor: Color(red: 0.98, green: 0.85, blue: 0.88).opacity(0.6),
                                value: remainingNutrition.carbs,
                                consumed: dailyTotals.carbs,
                                goal: goals.carbs
                            )
                            .frame(maxWidth: .infinity)
                            
                            MacroCard(
                                amount: "\(remainingNutrition.fats)g",
                                label: NSLocalizedString("Fats", comment: "") + " " + NSLocalizedString("left", comment: ""),
                                icon: "💧",
                                circleColor: Color(red: 0.92, green: 0.85, blue: 0.95).opacity(0.6),
                                value: remainingNutrition.fats,
                                consumed: dailyTotals.fats,
                                goal: goals.fats
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 20)
                        .tag(0)
                        
                        // Page 2: Fiber, Sugar, Sodium
                        HStack(spacing: 12) {
                            let remainingNutrition = foodDataManager.getRemainingNutrition()
                            let dailyTotals = foodDataManager.dailyTotals
                            let goals = foodDataManager.nutritionGoals
                            
                            MacroCard(
                                amount: "\(dailyTotals.fiber)g",
                                label: NSLocalizedString("Fiber", comment: "") + " " + NSLocalizedString("eaten", comment: ""),
                                icon: "🌾",
                                circleColor: Color(red: 0.88, green: 0.82, blue: 0.92).opacity(0.6),
                                value: dailyTotals.fiber,
                                consumed: dailyTotals.fiber,
                                goal: goals.fiber,
                                isConsumed: true
                            )
                            .frame(maxWidth: .infinity)
                            
                            MacroCard(
                                amount: "\(dailyTotals.sugar)g",
                                label: NSLocalizedString("Sugar", comment: "") + " " + NSLocalizedString("eaten", comment: ""),
                                icon: "🍬",
                                circleColor: Color(red: 0.98, green: 0.82, blue: 0.88).opacity(0.6),
                                value: dailyTotals.sugar,
                                consumed: dailyTotals.sugar,
                                goal: goals.sugar,
                                isConsumed: true
                            )
                            .frame(maxWidth: .infinity)
                            
                            MacroCard(
                                amount: "\(dailyTotals.sodium)mg",
                                label: NSLocalizedString("Sodium", comment: "") + " " + NSLocalizedString("eaten", comment: ""),
                                icon: "🧂",
                                circleColor: Color(red: 0.90, green: 0.85, blue: 0.95).opacity(0.6),
                                value: dailyTotals.sodium,
                                consumed: dailyTotals.sodium,
                                goal: goals.sodium,
                                isConsumed: true
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 20)
                        .tag(1)
                    }
                    .frame(height: 175)
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .padding(.top, 6)
                    
                    // Page indicator dots (2 dots)
                    HStack(spacing: 8) {
                        Circle()
                            .fill(macroPageIndex == 0 ? Color(red: 0.92, green: 0.58, blue: 0.65) : Color(red: 0.92, green: 0.58, blue: 0.65).opacity(0.3))
                            .frame(width: 6, height: 6)
                        Circle()
                            .fill(macroPageIndex == 1 ? Color(red: 0.92, green: 0.58, blue: 0.65) : Color(red: 0.92, green: 0.58, blue: 0.65).opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                    
                    // Recently Uploaded Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recently uploaded")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                        
                        if foodDataManager.todaysMeals.isEmpty {
                            // Empty state
                            ZStack {
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color.white)
                                    .opacity(1.0) // Ensure fully opaque
                                    .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 2)
                                
                                VStack(spacing: 0) {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(red: 0.95, green: 0.95, blue: 0.96))
                                                .frame(width: 65, height: 65)
                                            
                                            Text("🥗")
                                                .font(.system(size: 34))
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 5) {
                                            Rectangle()
                                                .fill(Color(red: 0.92, green: 0.92, blue: 0.93))
                                                .frame(width: 120, height: 10)
                                                .cornerRadius(5)
                                            
                                            Rectangle()
                                                .fill(Color(red: 0.94, green: 0.94, blue: 0.95))
                                                .frame(width: 85, height: 8)
                                                .cornerRadius(4)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(16)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.5))
                                    .cornerRadius(24)
                                    
                                    Text("Tap + to add your first meal of the day")
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(Color.black.opacity(0.4))
                                        .multilineTextAlignment(.center)
                                        .padding(.vertical, 30)
                                        .padding(.horizontal, 24)
                                }
                            }
                            .frame(height: 195)
                            .padding(.horizontal, 20)
                        } else {
                            // Meal list
                            ForEach(foodDataManager.todaysMeals) { meal in
                                MealRowView(meal: meal)
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.top, 10)
                    
                    Spacer(minLength: 100)
                }
                .background(Color.clear) // Ensure no translucent effects
            }
            .background(Color.clear) // Prevent gradient bleed-through
        }
        }
    }
    
}

// MARK: - Progress View
struct ProgressTabView: View {
    @Binding var showFoodDatabase: Bool
    @StateObject private var foodDataManager = FoodDataManager.shared
    @ObservedObject var onboardingData = OnboardingDataManager.shared
    
    // Helper properties to use OnboardingDataManager as fallback when Firebase hasn't loaded
    var currentWeight: Double {
        // If nutrition goals show default values (148 lbs), use onboarding data instead
        if abs(foodDataManager.nutritionGoals.currentWeight - 148.0) < 0.1 {
            return onboardingData.getCurrentWeightLbs()
        }
        return foodDataManager.nutritionGoals.currentWeight
    }
    
    var targetWeight: Double {
        // If nutrition goals show default values (135.6 lbs), use onboarding data instead
        if abs(foodDataManager.nutritionGoals.targetWeight - 135.6) < 0.1 {
            return onboardingData.getTargetWeightLbs()
        }
        return foodDataManager.nutritionGoals.targetWeight
    }
    
    var weightChangeSpeed: Double {
        // If nutrition goals show default value (1.0), use onboarding data instead
        if abs(foodDataManager.nutritionGoals.weightLossSpeed - 1.0) < 0.1 {
            return onboardingData.weightLossSpeed
        }
        return foodDataManager.nutritionGoals.weightLossSpeed
    }
    
    // Calculate BMI from user data
    var currentBMI: Double {
        let heightInches = onboardingData.getHeightInInches()
        let weightLbs = currentWeight  // Use computed property
        let heightMeters = heightInches * 0.0254
        let weightKg = weightLbs / 2.20462
        let bmi = weightKg / (heightMeters * heightMeters)
        return bmi
    }
    
    var bmiCategory: (name: String, color: Color) {
        let bmi = currentBMI
        if bmi < 18.5 {
            return ("Underweight", Color(red: 0.40, green: 0.60, blue: 0.85))
        } else if bmi < 25.0 {
            return ("Healthy", Color(red: 0.45, green: 0.75, blue: 0.55))
        } else if bmi < 30.0 {
            return ("Overweight", Color(red: 0.85, green: 0.68, blue: 0.45))
        } else {
            return ("Obese", Color(red: 0.80, green: 0.50, blue: 0.50))
        }
    }
    
    var bmiIndicatorPosition: CGFloat {
        let bmi = currentBMI
        // Map BMI to position on scale (15-35 BMI range)
        let minBMI = 15.0
        let maxBMI = 35.0
        let normalizedBMI = min(max(bmi, minBMI), maxBMI)
        return CGFloat((normalizedBMI - minBMI) / (maxBMI - minBMI))
    }
    
    // Calculate goal date
    var goalDate: String {
        let weightDifference = abs(currentWeight - targetWeight)
        let weeksToGoal = weightDifference / max(0.1, weightChangeSpeed)
        let daysToGoal = weeksToGoal * 7
        
        let goalDate = Calendar.current.date(byAdding: .day, value: Int(daysToGoal), to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: goalDate)
    }
    
    // Calculate weight progress percentage
    var weightProgressPercentage: Int {
        let startWeight = currentWeight  // For now, use current as start (will update as user logs weight)
        let totalWeightToLose = abs(startWeight - targetWeight)
        let weightLost = 0.0  // Will be non-zero once user starts logging weight updates
        
        if totalWeightToLose == 0 {
            return 0
        }
        
        let percentage = (weightLost / totalWeightToLose) * 100
        return min(100, max(0, Int(percentage)))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Soft gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.98, green: 0.94, blue: 0.96),
                        Color(red: 0.96, green: 0.93, blue: 0.98)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Progress Header
                    Text("Progress")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 10)
                    .padding(.top, 60)
                    .padding(.bottom, 8)
                
                // Day Streak Card
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                            .frame(maxWidth: .infinity)
                        
                        VStack(spacing: 12) {
                            ZStack {
                                // Fire emoji with sparkles
                                Text("🔥")
                                    .font(.system(size: 72))
                                
                                // Sparkles positioned around the fire
                                Text("✨")
                                    .font(.system(size: 20))
                                    .offset(x: -35, y: -25)
                                
                                Text("✨")
                                    .font(.system(size: 16))
                                    .offset(x: 30, y: -20)
                                
                                Text("✨")
                                    .font(.system(size: 12))
                                    .offset(x: -20, y: -35)
                                
                                // White circle with streak count
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text("\(foodDataManager.streakCount)")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(Color(red: 0.92, green: 0.58, blue: 0.65))
                                    )
                                    .offset(y: 25)
                            }
                            .frame(height: 100)
                            
                            Text("day_streak")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(Color.black.opacity(0.6))
                        }
                        .padding(.vertical, 20)
                    }
                    .frame(maxWidth: .infinity)
                }
                .clipped()
                .padding(.horizontal, 10)
                
                // Current Weight Card
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                        .frame(maxWidth: .infinity)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("current_weight")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(Color.black.opacity(0.5))
                                
                                Text(String(format: "%.1f lbs", currentWeight))
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.black)
                                    .fixedSize()
                            }
                            
                            Spacer()
                        }
                        
                        // Progress bar showing weight loss progress
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color(red: 0.95, green: 0.95, blue: 0.96))
                                    .frame(height: 4)
                                    .cornerRadius(2)
                                
                                Rectangle()
                                    .fill(Color(red: 0.92, green: 0.58, blue: 0.65))
                                    .frame(width: geometry.size.width * CGFloat(weightProgressPercentage) / 100.0, height: 4)
                                    .cornerRadius(2)
                            }
                        }
                        .frame(height: 4)
                        
                        HStack(alignment: .top, spacing: 0) {
                            Text(LocalizedStringKey(String(format: NSLocalizedString("start_weight_label", comment: ""), currentWeight)))
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(Color.black.opacity(0.5))
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)
                                .layoutPriority(1)
                            
                            Spacer(minLength: 2)
                            
                            Text(LocalizedStringKey(String(format: NSLocalizedString("goal_weight_label", comment: ""), targetWeight)))
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(Color.black.opacity(0.5))
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)
                                .multilineTextAlignment(.trailing)
                                .layoutPriority(1)
                        }
                        
                        Text(LocalizedStringKey(String(format: NSLocalizedString("At your goal by %@.", comment: ""), goalDate)))
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(Color.black.opacity(0.5))
                            .lineLimit(2)
                            .minimumScaleFactor(0.4)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                }
                .clipped()
                .padding(.horizontal, 10)
                
                // Weight Progress Chart
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                        .frame(maxWidth: .infinity)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(alignment: .center, spacing: 0) {
                            Text("weight_progress")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)
                                .layoutPriority(1)
                            
                            Spacer(minLength: 2)
                            
                            HStack(spacing: 1) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(Color.black.opacity(0.4))
                                
                                Text(LocalizedStringKey(String(format: NSLocalizedString("percent_of_goal", comment: ""), weightProgressPercentage)))
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(Color.black.opacity(0.5))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.4)
                                    .multilineTextAlignment(.trailing)
                            }
                            .layoutPriority(1)
                        }
                        
                        // Chart
                        GeometryReader { geometry in
                            let startWeight = currentWeight
                            let target = targetWeight
                            let current = currentWeight
                            
                            let maxWeight = max(startWeight, target) + 4
                            let minWeight = min(startWeight, target) - 4
                            let weightRange = maxWeight - minWeight
                            
                            let weightValues = stride(from: Int(maxWeight), through: Int(minWeight), by: -2).map { $0 }
                            
                            ZStack(alignment: .leading) {
                                // Y-axis labels and grid lines
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(Array(weightValues.enumerated()), id: \.offset) { index, value in
                                        HStack(spacing: 8) {
                                            Text("\(value)")
                                                .font(.system(size: 13, weight: .regular))
                                                .foregroundColor(Color.black.opacity(0.4))
                                                .frame(width: 30, alignment: .trailing)
                                            
                                            Rectangle()
                                                .fill(Color.black.opacity(0.06))
                                                .frame(height: 1)
                                        }
                                        
                                        if index < weightValues.count - 1 {
                                            Spacer()
                                        }
                                    }
                                }
                                
                                // Current weight line
                                HStack(spacing: 8) {
                                    Text("")
                                        .frame(width: 30)
                                    
                                    Rectangle()
                                        .fill(Color.black)
                                        .frame(height: 2)
                                }
                                .offset(y: geometry.size.height * CGFloat((maxWeight - current) / weightRange))
                                
                                // Target weight line (dotted)
                                HStack(spacing: 8) {
                                    Text("")
                                        .frame(width: 30)
                                    
                                    Rectangle()
                                        .fill(Color(red: 0.92, green: 0.58, blue: 0.65))
                                        .frame(height: 1)
                                }
                                .offset(y: geometry.size.height * CGFloat((maxWeight - target) / weightRange))
                            }
                        }
                        .frame(height: 200)
                        .padding(.bottom, 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                }
                .clipped()
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
                
                // BMI Card
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                        .frame(maxWidth: .infinity)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Text("your_bmi")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            
                            Spacer()
                            
                            Button(action: {}) {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color.black.opacity(0.3))
                            }
                        }
                        
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(String(format: "%.1f", currentBMI))
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.black)
                                .fixedSize()
                            
                            (Text("Your weight is ")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Color.black.opacity(0.5))
                            + Text(bmiCategory.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(bmiCategory.color))
                                .lineLimit(2)
                                .minimumScaleFactor(0.5)
                        }
                        
                        // BMI Scale Bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Colored sections
                                HStack(spacing: 0) {
                                    // Underweight - Blue (more saturated)
                                    Rectangle()
                                        .fill(Color(red: 0.40, green: 0.60, blue: 0.85))
                                        .frame(width: geometry.size.width * 0.25)
                                    
                                    // Healthy - Green (more saturated)
                                    Rectangle()
                                        .fill(Color(red: 0.45, green: 0.75, blue: 0.55))
                                        .frame(width: geometry.size.width * 0.25)
                                    
                                    // Overweight - Orange/Tan (more saturated)
                                    Rectangle()
                                        .fill(Color(red: 0.85, green: 0.68, blue: 0.45))
                                        .frame(width: geometry.size.width * 0.25)
                                    
                                    // Obese - Red/Brown (more saturated)
                                    Rectangle()
                                        .fill(Color(red: 0.80, green: 0.50, blue: 0.50))
                                        .frame(width: geometry.size.width * 0.25)
                                }
                                .frame(height: 14)
                                .cornerRadius(7)
                                
                                // Current BMI indicator line
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(width: 3, height: 24)
                                    .offset(x: geometry.size.width * bmiIndicatorPosition)
                            }
                        }
                        .frame(height: 24)
                        
                        // BMI Categories
                        HStack(spacing: 2) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 3) {
                                    Circle()
                                        .fill(Color(red: 0.40, green: 0.60, blue: 0.85))
                                        .frame(width: 7, height: 7)
                                    
                                    Text("underweight")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(Color.black.opacity(0.6))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.4)
                                }
                                
                                Text("bmi_underweight")
                                    .font(.system(size: 9, weight: .regular))
                                    .foregroundColor(Color.black.opacity(0.4))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.4)
                                    .padding(.leading, 10)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 3) {
                                    Circle()
                                        .fill(Color(red: 0.45, green: 0.75, blue: 0.55))
                                        .frame(width: 7, height: 7)
                                    
                                    Text("healthy")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(Color.black.opacity(0.6))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.4)
                                }
                                
                                Text("bmi_healthy")
                                    .font(.system(size: 9, weight: .regular))
                                    .foregroundColor(Color.black.opacity(0.4))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.4)
                                    .padding(.leading, 10)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 3) {
                                    Circle()
                                        .fill(Color(red: 0.85, green: 0.68, blue: 0.45))
                                        .frame(width: 7, height: 7)
                                    
                                    Text("overweight")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(Color.black.opacity(0.6))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.4)
                                }
                                
                                Text("bmi_overweight")
                                    .font(.system(size: 9, weight: .regular))
                                    .foregroundColor(Color.black.opacity(0.4))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.4)
                                    .padding(.leading, 10)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 3) {
                                    Circle()
                                        .fill(Color(red: 0.80, green: 0.50, blue: 0.50))
                                        .frame(width: 7, height: 7)
                                    
                                    Text("obese")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(Color.black.opacity(0.6))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.4)
                                }
                                
                                Text("bmi_obese")
                                    .font(.system(size: 9, weight: .regular))
                                    .foregroundColor(Color.black.opacity(0.4))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.4)
                                    .padding(.leading, 10)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                }
                .clipped()
                .padding(.horizontal, 10)
                .padding(.bottom, 120)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: geometry.size.width)
        }
        }
        }
        .opacity(showFoodDatabase ? 0 : 1)
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var foodDataManager = FoodDataManager.shared
    @State private var showLogoutAlert = false
    @State private var showDeleteAlert = false
    @State private var showPersonalDetailsSheet = false
    
    // Debug function to reset app state
    private func resetAppState() {
        // Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        
        // Logout user
        authManager.logOut()
        
        print("🔧 DEBUG: App state reset - returning to login screen")
    }
    
    // Function to send support email
    private func sendSupportEmail() {
        let email = "support@calorietracker.app" // Replace with your actual support email
        let subject = "Support Request"
        let body = "Please describe your issue:"
        
        let mailtoString = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let url = URL(string: mailtoString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                print("⚠️ Cannot open mail app")
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Soft gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.98, green: 0.94, blue: 0.96),
                    Color(red: 0.96, green: 0.93, blue: 0.98)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // Profile Header
                Text("Profile")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .padding(.bottom, 8)
                
                // User Info Card
                if let user = authManager.currentUser {
                    VStack(spacing: 12) {
                        // User Avatar
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.92, green: 0.58, blue: 0.65),
                                        Color(red: 0.85, green: 0.70, blue: 0.90)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(user.name?.prefix(1).uppercased() ?? user.email?.prefix(1).uppercased() ?? "U")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        
                        // User Name
                        if let displayName = user.name {
                            Text(displayName)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        
                        // User Email
                        if let email = user.email {
                            Text(email)
                                .font(.system(size: 15))
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                    .padding(.horizontal, 20)
                }
                
                // Personal Details
                VStack(spacing: 0) {
                    ProfileButton(
                        icon: "person.text.rectangle",
                        title: "Personal Details",
                        action: {
                            showPersonalDetailsSheet = true
                        }
                    )
                }
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 20)
                
                // Preferences Header
                Text("preferences")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.5))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                // Language Picker
                VStack(spacing: 0) {
                    LanguagePickerView()
                }
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 20)
                
                // Support Header
                Text("support")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.5))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                // Support Email
                VStack(spacing: 0) {
                    ProfileButton(
                        icon: "envelope",
                        title: "Support Email",
                        action: {
                            sendSupportEmail()
                        }
                    )
                }
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 20)
                
                // Legal Header
                Text("legal")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.5))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                // Legal Section
                VStack(spacing: 0) {
                    ProfileButton(
                        icon: "doc.text",
                        title: NSLocalizedString("Terms of Service", comment: ""),
                        action: {}
                    )
                    
                    Divider()
                        .padding(.leading, 56)
                    
                    ProfileButton(
                        icon: "checkmark.shield",
                        title: NSLocalizedString("Privacy Policy", comment: ""),
                        action: {}
                    )
                }
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 20)
                
                // Account Actions Header
                Text("account_actions")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.5))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                // Account Actions
                VStack(spacing: 0) {
                    ProfileButton(
                        icon: "rectangle.portrait.and.arrow.right",
                        title: NSLocalizedString("Logout", comment: ""),
                        action: {
                            showLogoutAlert = true
                        }
                    )
                    
                    Divider()
                        .padding(.leading, 56)
                    
                    ProfileButton(
                        icon: "person.crop.circle.badge.minus",
                        title: NSLocalizedString("Delete Account", comment: ""),
                        action: {
                            showDeleteAlert = true
                        }
                    )
                }
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 20)
                
                // Debug Section
                #if DEBUG
                Text("debug")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.orange.opacity(0.8))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
                VStack(spacing: 0) {
                    ProfileButton(
                        icon: "arrow.counterclockwise.circle.fill",
                        title: "🔧 Reset App & Logout (Debug)",
                        action: {
                            resetAppState()
                        }
                    )
                }
                .background(Color.orange.opacity(0.1))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                #endif
            }
            .padding(.bottom, 120)
        }
        .alert("Logout", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Logout", role: .destructive) {
                authManager.logOut()
            }
        } message: {
            Text("confirm_logout")
        }
        .alert("Delete Account", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                authManager.deleteAccount { success, message in
                    if success {
                        print("✅ Account deleted successfully")
                    } else {
                        print("❌ Failed to delete account: \(message ?? "Unknown error")")
                    }
                }
            }
        } message: {
            Text("confirm_delete")
        }
        .sheet(isPresented: $showPersonalDetailsSheet) {
            PersonalDetailsView()
                .environmentObject(authManager)
        }
        }
    }
}

// MARK: - Personal Details View
struct PersonalDetailsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var onboardingData = OnboardingDataManager.shared
    @StateObject private var foodDataManager = FoodDataManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // User Info Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("account")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("email")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(authManager.currentUser?.email ?? "Not available")
                                    .foregroundColor(.black)
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("name")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(authManager.currentUser?.name ?? "Not available")
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    
                    // Physical Info Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("physical_information")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("gender")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(onboardingData.gender)
                                    .foregroundColor(.black)
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("height")
                                    .foregroundColor(.gray)
                                Spacer()
                                if onboardingData.isImperial {
                                    Text("\(onboardingData.heightFeet)' \(onboardingData.heightInches)\"")
                                        .foregroundColor(.black)
                                } else {
                                    Text("\(onboardingData.heightCm) cm")
                                        .foregroundColor(.black)
                                }
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("current_weight")
                                    .foregroundColor(.gray)
                                Spacer()
                                if onboardingData.isImperial {
                                    Text(String(format: "%.1f lbs", onboardingData.weightLbs))
                                        .foregroundColor(.black)
                                } else {
                                    Text(String(format: "%.1f kg", onboardingData.weightKg))
                                        .foregroundColor(.black)
                                }
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("age")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(onboardingData.calculateAge()) years")
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    
                    // Goals Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("goals")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("fitness_goal")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(onboardingData.fitnessGoal)
                                    .foregroundColor(.black)
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Target Weight")
                                    .foregroundColor(.gray)
                                Spacer()
                                if onboardingData.isImperial {
                                    Text(String(format: "%.1f lbs", onboardingData.desiredWeightLbs))
                                        .foregroundColor(.black)
                                } else {
                                    Text(String(format: "%.1f kg", onboardingData.desiredWeightKg))
                                        .foregroundColor(.black)
                                }
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Weight Change Speed")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(String(format: "%.1f lbs/week", onboardingData.weightLossSpeed))
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    
                    // Nutrition Goals Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("daily_nutrition_goals")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("Calories")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(foodDataManager.nutritionGoals.dailyCalories) cal")
                                    .foregroundColor(.black)
                                    .fontWeight(.semibold)
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Protein")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(foodDataManager.nutritionGoals.protein)g")
                                    .foregroundColor(.black)
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("carbs")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(foodDataManager.nutritionGoals.carbs)g")
                                    .foregroundColor(.black)
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("fats")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(foodDataManager.nutritionGoals.fats)g")
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .padding(.top, 20)
            }
            .navigationTitle("Personal Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .preferredColorScheme(.light)  // Force light mode - white background
        }
    }
}

// MARK: - Language Selection View
// Removed - Now using LanguagePickerView with proper English/Spanish/Russian support

// MARK: - Profile Button
struct ProfileButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(.black)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.black)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.3))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Meal Row View
struct MealRowView: View {
    let meal: ScannedFood
    @State private var showFoodDetail = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
            
            HStack(spacing: 14) {
                // Food icon
                ZStack {
                    Circle()
                        .fill(Color(red: 0.95, green: 0.95, blue: 0.96))
                        .frame(width: 60, height: 60)
                    
                    Text(meal.icon)
                        .font(.system(size: 30))
                }
                
                // Food info
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text("\(meal.calories) cal")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.black.opacity(0.6))
                        
                        Text("•")
                            .foregroundColor(Color.black.opacity(0.3))
                        
                        Text(meal.timestamp)
                            .font(.system(size: 14))
                            .foregroundColor(Color.black.opacity(0.5))
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.3))
            }
            .padding(14)
        }
        .frame(height: 88)
        .onTapGesture {
            showFoodDetail = true
        }
        .sheet(isPresented: $showFoodDetail) {
            FoodDetailView(meal: meal)
        }
    }
}

// MARK: - Food Detail View
struct FoodDetailView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var foodDataManager = FoodDataManager.shared
    let meal: ScannedFood
    @State private var showMenu = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Text("nutrition")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Button(action: {
                        showMenu = true
                    }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Time
                        Text(meal.timestamp)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Color.black.opacity(0.5))
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                        
                        // Food Name
                        HStack {
                            Text(meal.name)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.black)
                            
                            Spacer()
                            
                            Button(action: {}) {
                                Image(systemName: "bookmark")
                                    .font(.system(size: 24))
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        // Servings
                        HStack {
                            Text("number_of_servings")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(.black)
                            
                            Spacer()
                            
                            Text("1")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 24)
                        
                        // Nutrition Card
                        VStack(spacing: 20) {
                            // Calories
                            HStack {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.black)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Calories")
                                        .font(.system(size: 15, weight: .regular))
                                        .foregroundColor(Color.black.opacity(0.5))
                                    
                                    Text("\(meal.calories)")
                                        .font(.system(size: 42, weight: .bold))
                                        .foregroundColor(.black)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            
                            // Macros
                            HStack(spacing: 12) {
                                // Protein
                                VStack(spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(Color(red: 0.89, green: 0.85, blue: 0.88))
                                        
                                        Text("Protein")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(Color.black.opacity(0.6))
                                    }
                                    
                                    Text("\(meal.protein)g")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.black)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(.systemGray6))
                                .cornerRadius(16)
                                
                                // Carbs
                                VStack(spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(Color(red: 0.96, green: 0.93, blue: 0.87))
                                        
                                        Text("Carbs")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(Color.black.opacity(0.6))
                                    }
                                    
                                    Text("\(meal.carbs)g")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.black)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(.systemGray6))
                                .cornerRadius(16)
                                
                                // Fats
                                VStack(spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(Color(red: 0.87, green: 0.90, blue: 0.95))
                                        
                                        Text("Fats")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(Color.black.opacity(0.6))
                                    }
                                    
                                    Text("\(meal.fats)g")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.black)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(.systemGray6))
                                .cornerRadius(16)
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.vertical, 24)
                        .background(Color.white)
                        .cornerRadius(24)
                        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                        .padding(.horizontal, 24)
                        
                        Spacer(minLength: 100)
                    }
                }
                
                // Done button
                Button(action: {
                    dismiss()
                }) {
                        Text("done")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.black)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(Color(red: 0.97, green: 0.97, blue: 0.98))
            .navigationBarHidden(true)
        }
        .confirmationDialog("Delete this food item?", isPresented: $showMenu, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                foodDataManager.deleteMeal(meal)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove \(meal.name) from your daily nutrition tracking.")
        }
    }
}

struct MacroCard: View {
    let amount: String
    let label: String
    let icon: String
    let circleColor: Color
    let value: Int
    let consumed: Int
    let goal: Int
    let isConsumed: Bool
    
    init(amount: String, label: String, icon: String, circleColor: Color, value: Int = 0, consumed: Int = 0, goal: Int = 1, isConsumed: Bool = false) {
        self.amount = amount
        self.label = label
        self.icon = icon
        self.circleColor = circleColor
        self.value = value
        self.consumed = consumed
        self.goal = goal
        self.isConsumed = isConsumed
    }
    
    var body: some View {
        let isOver = value < 0
        let displayLabel = isOver ? label.replacingOccurrences(of: "left", with: "over") : label
        let progress = min(1.0, Double(consumed) / Double(max(1, goal)))
        
        ZStack {
            // Solid white background to prevent translucency
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .opacity(1.0) // Ensure fully opaque
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 2)
            
            VStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(amount)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(isOver ? Color(red: 0.90, green: 0.50, blue: 0.55) : .black)
                    
                    Text(displayLabel)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(isOver ? Color(red: 0.90, green: 0.50, blue: 0.55).opacity(0.7) : Color.black.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
                
                Spacer(minLength: 0)
                
                ZStack {
                    // Background circle
                    Circle()
                        .fill(circleColor)
                        .frame(width: 68, height: 68)
                    
                    // Progress ring
                    Circle()
                        .stroke(Color.black.opacity(0.1), lineWidth: 4)
                        .frame(width: 78, height: 78)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(
                            consumed > goal ? Color(red: 0.90, green: 0.50, blue: 0.55) : Color(red: 0.92, green: 0.58, blue: 0.65),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 78, height: 78)
                        .rotationEffect(.degrees(-90))
                    
                    // Icon
                    Text(icon)
                        .font(.system(size: 24))
                        .offset(y: 2)
                }
                .padding(.bottom, 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .frame(height: 165)
    }
}

struct TabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) { // Tighter spacing
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium)) // #20: Smaller icons
                    .foregroundColor(isSelected ? .black : Color.black.opacity(0.35))
                
                Text(label)
                    .font(.system(size: 10, weight: .medium)) // #9: Smaller labels
                    .foregroundColor(isSelected ? .black : Color.black.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// Custom dashed circle for unselected days with exactly 12 dashes
struct DashedCircle: View {
    let lineWidth: CGFloat
    let dashLength: CGFloat
    let color: Color
    
    var body: some View {
        // For a 30pt diameter circle (radius 15), circumference = 2πr ≈ 94.25
        // 12 dashes means 12 dashes + 12 gaps = 24 segments
        // Each segment = 94.25 / 24 ≈ 3.93
        let calculatedDashLength: CGFloat = 3.9
        
        Circle()
            .stroke(style: StrokeStyle(
                lineWidth: lineWidth,
                dash: [calculatedDashLength, calculatedDashLength]
            ))
            .foregroundColor(color)
    }
}

// MARK: - Food Scan Flow
struct FoodScanFlow: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 4 // skip onboarding, go straight to camera
    @State private var scannedFood: ScannedFood?
    
    var body: some View {
        ZStack {
            if currentStep < 4 {
                ScanOnboardingView(currentStep: $currentStep, isPresented: $isPresented)
            } else if currentStep == 4 {
                CameraScanView(currentStep: $currentStep, scannedFood: $scannedFood, isPresented: $isPresented)
            } else if currentStep == 5 {
                if let food = scannedFood {
                    FoodDetailView(meal: food)
                        .onDisappear {
                            isPresented = false
                        }
                }
            }
        }
    }
}

// MARK: - Scan Onboarding View
struct ScanOnboardingView: View {
    @Binding var currentStep: Int
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top section with image and content
                VStack(spacing: 0) {
                    // Status bar area
                    HStack {
                        Spacer()
                    }
                    .frame(height: 44)
                    
                    Spacer()
                    
                    // Content based on current step
                    if currentStep == 0 {
                        OnboardingStep1()
                    } else if currentStep == 1 {
                        OnboardingStep2()
                    } else if currentStep == 2 {
                        OnboardingStep3()
                    }
                    
                    Spacer()
                }
                
                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(index == currentStep ? Color.black : Color.black.opacity(0.2))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.bottom, 24)
                
                // Next/Scan now button
                Button(action: {
                    if currentStep < 2 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            currentStep += 1
                        }
                    } else {
                        currentStep = 4
                    }
                }) {
                    Text(currentStep == 2 ? "Scan now" : "Next")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(red: 0.15, green: 0.15, blue: 0.20))
                        .cornerRadius(28)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }
}

struct OnboardingStep1: View {
    var body: some View {
        VStack(spacing: 32) {
            // Image placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color(red: 0.96, green: 0.96, blue: 0.97))
                    .frame(width: 310, height: 310)
                
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 80, weight: .thin))
                    .foregroundColor(Color.black.opacity(0.3))
            }
            
            VStack(spacing: 20) {
                Text("get_best_scan")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                            .frame(width: 24)
                        Text("hold_still")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.black)
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                            .frame(width: 24)
                        Text("use_lots_light")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.black)
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                            .frame(width: 24)
                        Text("ingredients_visible")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal, 40)
            }
        }
    }
}

struct OnboardingStep2: View {
    var body: some View {
        VStack(spacing: 32) {
            // Image placeholder showing food scan
            ZStack {
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color(red: 0.96, green: 0.96, blue: 0.97))
                    .frame(width: 310, height: 310)
                
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60, weight: .regular))
                        .foregroundColor(Color.black.opacity(0.3))
                    
                    Text("AI analyzing...")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.4))
                }
            }
            
            VStack(spacing: 20) {
                Text("AI analyzes your food")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                            .frame(width: 24)
                        Text("Ingredients are identified")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.black)
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                            .frame(width: 24)
                        Text("Takes a few seconds")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.black)
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                            .frame(width: 24)
                        Text("You'll see the calories and macros")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal, 40)
            }
        }
    }
}

struct OnboardingStep3: View {
    var body: some View {
        VStack(spacing: 32) {
            // Image placeholder showing food label
            ZStack {
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color(red: 0.96, green: 0.96, blue: 0.97))
                    .frame(width: 310, height: 310)
                
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.image")
                        .font(.system(size: 70, weight: .light))
                        .foregroundColor(Color.black.opacity(0.3))
                    
                    Text("ORGANIC")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.black.opacity(0.2))
                    
                    Text("BROCCOLETTE")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color.black.opacity(0.2))
                }
            }
            
            VStack(spacing: 20) {
                Text("For highest accuracy:")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.image")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                            .frame(width: 24)
                        Text("Or take a photo of the food label")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.black)
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                            .frame(width: 24)
                        Text("Alternatively, search the food database")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal, 40)
            }
        }
    }
}

// MARK: - Camera Scan View
struct CameraScanView: View {
    @Binding var currentStep: Int
    @Binding var scannedFood: ScannedFood?
    @Binding var isPresented: Bool
    @State private var flashOn = false
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isAnalyzing = false
    @State private var analysisError: String?
    @State private var isLeftoverMode = false
    
    var body: some View {
        ZStack {
            // Camera preview placeholder
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top controls
                HStack {
                    // Close button
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    // Leftovers / Food scan mode toggle
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isLeftoverMode.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text(isLeftoverMode ? "🍽️" : "🥣")
                                .font(.system(size: 16))
                            Text(isLeftoverMode ? "Leftovers" : "Baby Food")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            isLeftoverMode
                                ? Color(red: 0.83, green: 0.69, blue: 0.52).opacity(0.9)
                                : Color.white.opacity(0.2)
                        )
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    // Flash toggle button
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        flashOn.toggle()
                    }) {
                        Image(systemName: flashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(flashOn ? .yellow : .white)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                
                Spacer()
                
                // Camera controls - properly centered
                ZStack {
                    // Centered shutter button
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        // TODO: Implement actual camera capture
                        // For now, use a placeholder image
                        analyzePlaceholderFood()
                    }) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 76, height: 76)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 64, height: 64)
                        }
                    }
                    .disabled(isAnalyzing)
                    
                    // Photo library button aligned to the right
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            showingImagePicker = true
                        }) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                        }
                        .padding(.trailing, 30)
                        .disabled(isAnalyzing)
                    }
                }
                .padding(.bottom, 70)
            }
            
            // Analyzing overlay
            if isAnalyzing {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                
                    VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text(isLeftoverMode ? "Analyzing leftovers..." : "Analyzing baby food...")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(isLeftoverMode ? "Estimating what your baby ate" : "This may take a few seconds")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Error alert
            if let error = analysisError {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        Text("Analysis Failed")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(error)
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                        
                        Button(action: {
                            analysisError = nil
                        }) {
                            Text("Try Again")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(20)
                        }
                    }
                    .padding(24)
                    .background(Color.red.opacity(0.9))
                    .cornerRadius(16)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 100)
                }
            }
            
            // Speed indicator (top center)
            VStack {
                HStack(spacing: 4) {
                    Text(".5")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Text("x")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .padding(.top, 50)
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage) { image in
                if let image = image {
                    analyzeFood(image: image)
                }
            }
        }
    }
    
    private func analyzePlaceholderFood() {
        // For testing: use sample data
        // In production, this would capture from camera
        scannedFood = ScannedFood.sample
        currentStep = 5
    }
    
    private func analyzeFood(image: UIImage) {
        isAnalyzing = true
        analysisError = nil
        
        Task {
            do {
                let food = isLeftoverMode
                    ? try await FoodAnalysisService.shared.analyzeLeftovers(image: image)
                    : try await FoodAnalysisService.shared.analyzeFood(image: image)
                
                await MainActor.run {
                    scannedFood = food
                    isAnalyzing = false
                    currentStep = 5
                    print("✅ \(isLeftoverMode ? "Leftovers" : "Food") analyzed: \(food.name)")
                }
            } catch let error as FoodAnalysisService.FoodAnalysisError {
                await MainActor.run {
                    isAnalyzing = false
                    switch error {
                    case .imageConversionFailed:
                        analysisError = "Failed to process image"
                    case .networkError(let err):
                        analysisError = "Network error: \(err.localizedDescription)"
                    case .invalidResponse:
                        analysisError = "Invalid response from AI"
                    case .apiError(let msg):
                        analysisError = "API error: \(msg)"
                    }
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                    analysisError = "Unexpected error: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct MacroItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    var lightBackground: Bool = false // For white backgrounds
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: 48, height: 48)
                
                Text(icon)
                    .font(.system(size: 20))
            }
            
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(lightBackground ? .black : .white)
            
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(lightBackground ? .gray : .white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

struct NutrientItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    var lightBackground: Bool = false // For white backgrounds
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 48, height: 48)
                
                Text(icon)
                    .font(.system(size: 20))
            }
            
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(lightBackground ? .black : .white)
            
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(lightBackground ? .gray : .white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    var onImageSelected: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
                parent.onImageSelected(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Scanned Food Model
// MARK: - Nutrition Data Models
struct NutritionGoals: Codable {
    let dailyCalories: Int
    let protein: Int
    let carbs: Int
    let fats: Int
    let fiber: Int
    let sugar: Int
    let sodium: Int
    let currentWeight: Double
    let targetWeight: Double
    let weightLossSpeed: Double
    
    static let `default` = NutritionGoals(
        dailyCalories: 1387,
        protein: 104,
        carbs: 139,
        fats: 46,
        fiber: 28,      // Recommended daily fiber (25-30g)
        sugar: 50,      // Max recommended added sugar (~50g)
        sodium: 2300,   // Max recommended sodium (2300mg)
        currentWeight: 148,
        targetWeight: 135.6,
        weightLossSpeed: 1.0
    )
}

struct DailyTotals: Codable {
    var calories: Int
    var protein: Int
    var carbs: Int
    var fats: Int
    var fiber: Int
    var sugar: Int
    var sodium: Int
    
    static let zero = DailyTotals(calories: 0, protein: 0, carbs: 0, fats: 0, fiber: 0, sugar: 0, sodium: 0)
    
    mutating func add(_ food: ScannedFood) {
        calories += food.calories
        protein += food.protein
        carbs += food.carbs
        fats += food.fats
        fiber += food.fiber
        sugar += food.sugar
        sodium += food.sodium
    }
}

struct ScannedFood: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let servings: Int
    let timestamp: String
    let date: Date
    let calories: Int
    let protein: Int
    let carbs: Int
    let fats: Int
    let fiber: Int
    let sugar: Int
    let sodium: Int
    let healthScore: Int
    let icon: String
    let imageName: String?
    let ingredients: [String]
    
    init(id: String = UUID().uuidString, name: String, servings: Int, timestamp: String, date: Date = Date(), calories: Int, protein: Int, carbs: Int, fats: Int, fiber: Int, sugar: Int, sodium: Int, healthScore: Int, icon: String, imageName: String?, ingredients: [String]) {
        self.id = id
        self.name = name
        self.servings = servings
        self.timestamp = timestamp
        self.date = date
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fats = fats
        self.fiber = fiber
        self.sugar = sugar
        self.sodium = sodium
        self.healthScore = healthScore
        self.icon = icon
        self.imageName = imageName
        self.ingredients = ingredients
    }
    
    static let sample = ScannedFood(
        name: "Kopiko Black 3 in One",
        servings: 1,
        timestamp: "3:08 PM",
        calories: 90,
        protein: 1,
        carbs: 16,
        fats: 2,
        fiber: 0,
        sugar: 10,
        sodium: 40,
        healthScore: 5,
        icon: "☕️",
        imageName: nil,
        ingredients: [
            "Smoked Salmon - 180 cal, 85g",
            "Avocado - 120 cal, 78g"
        ]
    )
}

// MARK: - Food Data Manager (Firebase Persistence)
class FoodDataManager: ObservableObject {
    static let shared = FoodDataManager()
    private let db = Firestore.firestore()
    
    @Published var todaysMeals: [ScannedFood] = []
    @Published var nutritionGoals: NutritionGoals = .default
    @Published var dailyTotals: DailyTotals = .zero
    @Published var streakCount: Int = 0
    
    private init() {
        // Set up authentication state listener
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if user != nil {
                // User logged in - reload all data from Firebase
                print("🔄 User logged in, reloading all data from Firebase...")
                self?.reloadAllUserData()
            } else {
                // User logged out - clear local data
                print("🔄 User logged out, clearing local data...")
                self?.clearLocalData()
            }
        }
    }
    
    // MARK: - Nutrition Goals
    func saveNutritionGoals(_ goals: NutritionGoals) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Cannot save nutrition goals: No user logged in")
            return
        }
        
        print("💾 Saving nutrition goals to Firebase...")
        
        do {
            let data = try JSONEncoder().encode(goals)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            // Save to Firebase (NOT local cache)
            db.collection("users").document(userId).collection("profile").document("nutrition_goals").setData(dict) { error in
                if let error = error {
                    print("❌ Error saving nutrition goals to Firebase: \(error)")
                } else {
                    print("✅ Nutrition goals saved to Firebase successfully")
                    print("   📍 Path: users/\(userId)/profile/nutrition_goals")
                    print("   🎯 Daily calories: \(goals.dailyCalories)")
                    DispatchQueue.main.async {
                        self.nutritionGoals = goals
                    }
                }
            }
        } catch {
            print("❌ Error encoding nutrition goals: \(error)")
        }
    }
    
    // MARK: - Data Loading & Synchronization
    
    /// Reloads all user data from Firebase when user logs in
    func reloadAllUserData() {
        guard Auth.auth().currentUser != nil else {
            print("⚠️ Cannot reload data: No user logged in")
            return
        }
        
        print("📥 Loading all user data from Firebase...")
        loadNutritionGoals()
        loadMealsForToday()
        loadStreak()
    }
    
    /// Clears local data when user logs out
    private func clearLocalData() {
        DispatchQueue.main.async {
            self.todaysMeals = []
            self.nutritionGoals = .default
            self.dailyTotals = .zero
            self.streakCount = 0
            print("🗑️ Local data cleared")
        }
    }
    
    func loadNutritionGoals() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ Cannot load nutrition goals: No user logged in")
            return
        }
        
        print("📥 Loading nutrition goals from Firebase for user: \(userId)")
        
        db.collection("users").document(userId).collection("profile").document("nutrition_goals").getDocument { snapshot, error in
            if let error = error {
                print("❌ Error loading nutrition goals: \(error)")
                return
            }
            
            guard let data = snapshot?.data(),
                  let jsonData = try? JSONSerialization.data(withJSONObject: data),
                  let goals = try? JSONDecoder().decode(NutritionGoals.self, from: jsonData) else {
                print("⚠️ No nutrition goals found in Firebase, using defaults")
                DispatchQueue.main.async {
                    self.nutritionGoals = .default
                }
                return
            }
            
            DispatchQueue.main.async {
                self.nutritionGoals = goals
                print("✅ Nutrition goals loaded from Firebase: \(goals.dailyCalories) cal/day")
            }
        }
    }
    
    // MARK: - Meal Logging
    func saveMeal(_ food: ScannedFood) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ Cannot save meal: No user logged in")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: food.date)
        
        print("💾 Saving meal to Firebase: \(food.name) for date: \(dateString)")
        
        do {
            let data = try JSONEncoder().encode(food)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            // Save to Firebase (NOT local cache)
            db.collection("users")
                .document(userId)
                .collection("meals")
                .document(dateString)
                .collection("items")
                .document(food.id)
                .setData(dict) { error in
                    if let error = error {
                        print("❌ Error saving meal to Firebase: \(error)")
                    } else {
                        print("✅ Meal saved to Firebase: \(food.name)")
                        print("   📍 Path: users/\(userId)/meals/\(dateString)/items/\(food.id)")
                        // Real-time listener will auto-update todaysMeals
                        self.updateStreak()
                    }
                }
        } catch {
            print("❌ Error encoding meal: \(error)")
        }
    }
    
    func loadMealsForToday() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ Cannot load meals: No user logged in")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())
        
        print("📥 Loading meals from Firebase for date: \(todayString)")
        
        // Use real-time listener for automatic updates
        db.collection("users")
            .document(userId)
            .collection("meals")
            .document(todayString)
            .collection("items")
            .order(by: "date", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error loading meals from Firebase: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ No meal documents found for today")
                    DispatchQueue.main.async {
                        self.todaysMeals = []
                        self.calculateDailyTotals()
                    }
                    return
                }
                
                let meals = documents.compactMap { doc -> ScannedFood? in
                    guard let jsonData = try? JSONSerialization.data(withJSONObject: doc.data()),
                          let food = try? JSONDecoder().decode(ScannedFood.self, from: jsonData) else {
                        print("⚠️ Failed to decode meal document: \(doc.documentID)")
                        return nil
                    }
                    return food
                }
                
                DispatchQueue.main.async {
                    self.todaysMeals = meals
                    self.calculateDailyTotals()
                    print("✅ Loaded \(meals.count) meals from Firebase for today")
                }
            }
    }
    
    func loadMealsForDate(_ date: Date) async -> [ScannedFood] {
        guard let userId = Auth.auth().currentUser?.uid else { return [] }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("meals")
                .document(dateString)
                .collection("items")
                .order(by: "date", descending: true)
                .getDocuments()
            
            let meals = snapshot.documents.compactMap { doc -> ScannedFood? in
                guard let jsonData = try? JSONSerialization.data(withJSONObject: doc.data()),
                      let food = try? JSONDecoder().decode(ScannedFood.self, from: jsonData) else {
                    return nil
                }
                return food
            }
            
            return meals
        } catch {
            print("❌ Error loading meals for date: \(error)")
            return []
        }
    }
    
    func deleteMeal(_ food: ScannedFood) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: food.date)
        
        db.collection("users")
            .document(userId)
            .collection("meals")
            .document(dateString)
            .collection("items")
            .document(food.id)
            .delete { error in
                if let error = error {
                    print("❌ Error deleting meal: \(error)")
                } else {
                    print("✅ Meal deleted: \(food.name)")
                    self.loadMealsForToday()
                }
            }
    }
    
    // MARK: - Calculations
    func calculateDailyTotals() {
        var totals = DailyTotals.zero
        for meal in todaysMeals {
            totals.add(meal)
        }
        self.dailyTotals = totals
    }
    
    func getRemainingNutrition() -> DailyTotals {
        return DailyTotals(
            calories: nutritionGoals.dailyCalories - dailyTotals.calories,
            protein: nutritionGoals.protein - dailyTotals.protein,
            carbs: nutritionGoals.carbs - dailyTotals.carbs,
            fats: nutritionGoals.fats - dailyTotals.fats,
            fiber: nutritionGoals.fiber - dailyTotals.fiber,
            sugar: nutritionGoals.sugar - dailyTotals.sugar,
            sodium: nutritionGoals.sodium - dailyTotals.sodium
        )
    }
    
    // MARK: - Streak Tracking
    func updateStreak() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            let streak = await calculateStreak()
            DispatchQueue.main.async {
                self.streakCount = streak
            }
            
            // Save streak to Firestore
            do {
                try await db.collection("users").document(userId).collection("profile").document("streak").setData([
                    "count": streak,
                    "lastUpdated": Timestamp(date: Date())
                ])
                print("✅ Streak saved to Firebase: \(streak) days")
            } catch {
                print("❌ Error saving streak to Firebase: \(error)")
            }
        }
    }
    
    func loadStreak() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ Cannot load streak: No user logged in")
            return
        }
        
        print("📥 Loading streak from Firebase...")
        
        db.collection("users").document(userId).collection("profile").document("streak").getDocument { snapshot, error in
            if let error = error {
                print("❌ Error loading streak from Firebase: \(error)")
                return
            }
            
            if let data = snapshot?.data(),
               let count = data["count"] as? Int {
                DispatchQueue.main.async {
                    self.streakCount = count
                    print("✅ Streak loaded from Firebase: \(count) days")
                }
            } else {
                print("⚠️ No streak data found in Firebase, starting at 0")
                DispatchQueue.main.async {
                    self.streakCount = 0
                }
            }
        }
    }
    
    private func calculateStreak() async -> Int {
        guard let userId = Auth.auth().currentUser?.uid else { return 0 }
        
        var streak = 0
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Check last 365 days for streak
        for _ in 0..<365 {
            let dateString = dateFormatter.string(from: currentDate)
            
            do {
                let snapshot = try await db.collection("users")
                    .document(userId)
                    .collection("meals")
                    .document(dateString)
                    .collection("items")
                    .limit(to: 1)
                    .getDocuments()
                
                if !snapshot.documents.isEmpty {
                    streak += 1
                    currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
                } else {
                    break
                }
            } catch {
                break
            }
        }
        
        return streak
    }
}

// MARK: - OpenAI Food Analysis Service
class FoodAnalysisService {
    static let shared = FoodAnalysisService()
    static let openAIKey = "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"
    private let apiKey = FoodAnalysisService.openAIKey
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    
    enum FoodAnalysisError: Error {
        case imageConversionFailed
        case networkError(Error)
        case invalidResponse
        case apiError(String)
    }
    
    func analyzeFood(image: UIImage) async throws -> ScannedFood {
        // Convert image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw FoodAnalysisError.imageConversionFailed
        }
        let base64Image = imageData.base64EncodedString()
        
        // Prepare the prompt
        let prompt = """
        Analyze this baby food image and provide detailed nutritional information in JSON format.

        This is food being prepared or served to a baby (typically 4–18 months old). Estimate nutritional values for a single baby-sized serving (usually 2–4 oz / 60–120g).

        If the image shows a nutrition label, extract the exact values from the label.
        If multiple food items are visible, combine them into a single meal analysis.

        Return ONLY valid JSON (no markdown, no explanation) with this exact structure:
        {
          "name": "Descriptive food name",
          "servings": 1,
          "calories": 0,
          "protein": 0,
          "carbs": 0,
          "fats": 0,
          "fiber": 0,
          "sugar": 0,
          "sodium": 0,
          "healthScore": 0,
          "icon": "🍽️",
          "ingredients": ["Ingredient 1 - calories, weight", "Ingredient 2 - calories, weight"]
        }

        Guidelines:
        - name: Clear baby-friendly food name (e.g., "Sweet Potato Puree", "Banana Oatmeal")
        - servings: Default to 1 baby serving
        - All nutritional values in integer format
        - protein, carbs, fats, fiber, sugar in grams
        - sodium in milligrams (baby foods should be very low sodium)
        - healthScore: 0-10 based on nutritional balance for babies (10 = excellent for baby)
        - icon: Single emoji representing the food
        - ingredients: List 2-4 main ingredients with estimated calories and weight

        Baby health score criteria:
        - Iron-rich foods (meat, fortified cereals, lentils, spinach): +points
        - Whole fruits and vegetables: +points
        - High fiber, healthy fats (avocado, salmon): +points
        - High added sugar, salt, processed: -points
        - Allergens present (note in name if relevant): neutral
        """
        
        // Prepare request body
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 1000,
            "temperature": 0.3
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody),
              let url = URL(string: endpoint) else {
            throw FoodAnalysisError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FoodAnalysisError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw FoodAnalysisError.apiError(message)
                }
                throw FoodAnalysisError.apiError("HTTP \(httpResponse.statusCode)")
            }
            
            // Parse OpenAI response
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw FoodAnalysisError.invalidResponse
            }
            
            // Clean content (remove markdown code blocks if present)
            let cleanedContent = content
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Parse the food data JSON
            guard let foodData = cleanedContent.data(using: .utf8),
                  let foodJson = try? JSONSerialization.jsonObject(with: foodData) as? [String: Any] else {
                throw FoodAnalysisError.invalidResponse
            }
            
            // Create timestamp
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            let timestamp = formatter.string(from: Date())
            
            // Extract values
            let name = foodJson["name"] as? String ?? "Unknown Food"
            let servings = foodJson["servings"] as? Int ?? 1
            let calories = foodJson["calories"] as? Int ?? 0
            let protein = foodJson["protein"] as? Int ?? 0
            let carbs = foodJson["carbs"] as? Int ?? 0
            let fats = foodJson["fats"] as? Int ?? 0
            let fiber = foodJson["fiber"] as? Int ?? 0
            let sugar = foodJson["sugar"] as? Int ?? 0
            let sodium = foodJson["sodium"] as? Int ?? 0
            let healthScore = foodJson["healthScore"] as? Int ?? 5
            let icon = foodJson["icon"] as? String ?? "🍽️"
            let ingredients = foodJson["ingredients"] as? [String] ?? []
            
            return ScannedFood(
                name: name,
                servings: servings,
                timestamp: timestamp,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fats: fats,
                fiber: fiber,
                sugar: sugar,
                sodium: sodium,
                healthScore: healthScore,
                icon: icon,
                imageName: nil,
                ingredients: ingredients
            )
            
        } catch let error as FoodAnalysisError {
            throw error
        } catch {
            throw FoodAnalysisError.networkError(error)
        }
    }

    // Detects what a baby left on their plate and estimates how much was eaten
    func analyzeLeftovers(image: UIImage) async throws -> ScannedFood {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw FoodAnalysisError.imageConversionFailed
        }
        let base64Image = imageData.base64EncodedString()

        let prompt = """
        This is a photo of a baby's plate after eating. Identify what food was served and estimate how much the baby ate vs. what is left over.

        Return ONLY valid JSON (no markdown, no explanation) with this exact structure:
        {
          "name": "Food name + leftover summary (e.g. 'Mashed Peas – ~70% eaten')",
          "servings": 1,
          "calories": 0,
          "protein": 0,
          "carbs": 0,
          "fats": 0,
          "fiber": 0,
          "sugar": 0,
          "sodium": 0,
          "healthScore": 0,
          "icon": "🍽️",
          "ingredients": ["Food item: estimated portion eaten vs leftover"]
        }

        Guidelines:
        - Identify all foods visible on the plate
        - Estimate percentage eaten for each item (from most eaten to least)
        - Calculate calories and macros for the EATEN portion only
        - healthScore 0–10 for the food itself (not based on how much was eaten)
        - sodium in milligrams
        - ingredients: list each food with its eaten/leftover estimate
        """

        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
                ]
            ]],
            "max_tokens": 800,
            "temperature": 0.3
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody),
              let url = URL(string: endpoint) else {
            throw FoodAnalysisError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw FoodAnalysisError.apiError("HTTP error")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw FoodAnalysisError.invalidResponse
        }

        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let foodData = cleaned.data(using: .utf8),
              let foodJson = try? JSONSerialization.jsonObject(with: foodData) as? [String: Any] else {
            throw FoodAnalysisError.invalidResponse
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        return ScannedFood(
            name: foodJson["name"] as? String ?? "Leftovers",
            servings: foodJson["servings"] as? Int ?? 1,
            timestamp: formatter.string(from: Date()),
            calories: foodJson["calories"] as? Int ?? 0,
            protein: foodJson["protein"] as? Int ?? 0,
            carbs: foodJson["carbs"] as? Int ?? 0,
            fats: foodJson["fats"] as? Int ?? 0,
            fiber: foodJson["fiber"] as? Int ?? 0,
            sugar: foodJson["sugar"] as? Int ?? 0,
            sodium: foodJson["sodium"] as? Int ?? 0,
            healthScore: foodJson["healthScore"] as? Int ?? 5,
            icon: foodJson["icon"] as? String ?? "🍽️",
            imageName: nil,
            ingredients: foodJson["ingredients"] as? [String] ?? []
        )
    }
}

// MARK: - Food Database (OLD CODE REMOVED - Using clean architecture in /Invoice/Views/FoodDatabaseView.swift)

// Old embedded OpenFoodFacts code removed - now using:
// - Invoice/Models/FoodModels.swift
// - Invoice/Services/OpenFoodFactsService.swift  
// - Invoice/ViewModels/FoodSearchViewModel.swift
// - Invoice/Views/FoodDatabaseView.swift

// NOTE: Old OpenFoodFacts code removed - using clean architecture:
// - /Invoice/Models/FoodModels.swift
// - /Invoice/Services/OpenFoodFactsService.swift  
// - /Invoice/ViewModels/FoodSearchViewModel.swift
// - /Invoice/Views/FoodDatabaseView.swift

// MARK: - Legacy Support Structures (Keep for backward compatibility with existing UI)

// REMOVED: typealias OFFProduct = LegacyOFFProduct
// This was causing ambiguity with the NEW OFFProduct in FoodModels.swift
// Now using LegacyOFFProduct explicitly in this file for old UI

// Legacy OFFProduct for compatibility with old FoodDatabaseView in ContentView
struct LegacyOFFProduct: Codable, Identifiable {
    let code: String?
    let product_name: String?
    let brands: String?
    let image_url: String?
    let nutriments: LegacyOFFNutriments?
    let serving_size: String?
    
    init(code: String? = nil, product_name: String? = nil, brands: String? = nil, image_url: String? = nil, nutriments: LegacyOFFNutriments? = nil, serving_size: String? = nil) {
        self.code = code
        self.product_name = product_name
        self.brands = brands
        self.image_url = image_url
        self.nutriments = nutriments
        self.serving_size = serving_size
    }
    
    var id: String { code ?? UUID().uuidString }
    
    var displayName: String {
        product_name ?? "Unknown Product"
    }
    
    var displayBrand: String {
        brands ?? ""
    }
}

struct LegacyOFFNutriments: Codable {
    let energy_kcal_100g: Double?
    let proteins_100g: Double?
    let carbohydrates_100g: Double?
    let fat_100g: Double?
    let fiber_100g: Double?
    let sugars_100g: Double?
    let sodium_100g: Double?
    
    init(energy_kcal_100g: Double? = nil, proteins_100g: Double? = nil, carbohydrates_100g: Double? = nil, fat_100g: Double? = nil, fiber_100g: Double? = nil, sugars_100g: Double? = nil, sodium_100g: Double? = nil) {
        self.energy_kcal_100g = energy_kcal_100g
        self.proteins_100g = proteins_100g
        self.carbohydrates_100g = carbohydrates_100g
        self.fat_100g = fat_100g
        self.fiber_100g = fiber_100g
        self.sugars_100g = sugars_100g
        self.sodium_100g = sodium_100g
    }
    
    enum CodingKeys: String, CodingKey {
        case energy_kcal_100g = "energy-kcal_100g"
        case proteins_100g
        case carbohydrates_100g
        case fat_100g
        case fiber_100g
        case sugars_100g
        case sodium_100g
    }
}

// MARK: - Old Embedded OpenFoodFacts Service (REMOVED - see line 17012 for new service usage)
/*
actor OpenFoodFactsService {
    static let shared = OpenFoodFactsService()
    private let baseURL = "https://world.openfoodfacts.org"
    
    // Simple cache with 5-minute expiration (now thread-safe via actor)
    private var searchCache: [String: (results: [OFFProduct], timestamp: Date)] = [:]
    private let cacheExpirationSeconds: TimeInterval = 300 // 5 minutes
    
    // Search for products by name with cancellation support
    func searchProducts(query: String) async throws -> [OFFProduct] {
        // Check for cancellation before starting
        try Task.checkCancellation()
        
        // Get current language code from LanguageManager
        let languageCode = LanguageManager.shared.currentLanguage.code
        
        // Check cache first (include language in cache key)
        let lowercaseQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        let cacheKey = "\(lowercaseQuery)_\(languageCode)"
        if let cached = searchCache[cacheKey] {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheExpirationSeconds {
                print("✅ Returning cached results for: \(query) [\(languageCode)] (age: \(Int(age))s)")
                return cached.results
            } else {
                // Remove expired cache entry
                searchCache.removeValue(forKey: cacheKey)
            }
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        // Reduced page_size from 25 to 12 for faster loading
        // Added lc (language code) parameter for language-specific results
        let urlString = "\(baseURL)/cgi/search.pl?search_terms=\(encodedQuery)&search_simple=1&action=process&json=1&page_size=12&lc=\(languageCode)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        print("🔍 Searching OpenFoodFacts for: \(query) [Language: \(languageCode)]")
        
        // Add 10-second timeout for faster failure
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Check for cancellation after network request completes
        try Task.checkCancellation()
        
        // Parse JSON manually to handle missing fields gracefully
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let productsArray = json["products"] as? [[String: Any]] else {
            print("❌ Failed to parse OpenFoodFacts response")
            return []
        }
        
        // Manually parse products, skipping invalid ones
        var validProducts: [OFFProduct] = []
        
        for productDict in productsArray {
            // Only include products with basic nutrition data
            guard let productName = productDict["product_name"] as? String,
                  !productName.isEmpty else {
                continue
            }
            
            // Parse nutriments if available
            var nutriments: OFFNutriments?
            if let nutrimentsDict = productDict["nutriments"] as? [String: Any] {
                nutriments = OFFNutriments(
                    energy_kcal_100g: nutrimentsDict["energy-kcal_100g"] as? Double,
                    proteins_100g: nutrimentsDict["proteins_100g"] as? Double,
                    carbohydrates_100g: nutrimentsDict["carbohydrates_100g"] as? Double,
                    fat_100g: nutrimentsDict["fat_100g"] as? Double,
                    fiber_100g: nutrimentsDict["fiber_100g"] as? Double,
                    sugars_100g: nutrimentsDict["sugars_100g"] as? Double,
                    sodium_100g: nutrimentsDict["sodium_100g"] as? Double,
                    energy_kcal_serving: nutrimentsDict["energy-kcal_serving"] as? Double,
                    proteins_serving: nutrimentsDict["proteins_serving"] as? Double,
                    carbohydrates_serving: nutrimentsDict["carbohydrates_serving"] as? Double,
                    fat_serving: nutrimentsDict["fat_serving"] as? Double
                )
            }
            
            let product = OFFProduct(
                code: productDict["code"] as? String,
                product_name: productName,
                brands: productDict["brands"] as? String,
                image_url: productDict["image_url"] as? String,
                nutriments: nutriments,
                serving_size: productDict["serving_size"] as? String
            )
            
            validProducts.append(product)
        }
        
        // Cache the results with language-specific key
        searchCache[cacheKey] = (results: validProducts, timestamp: Date())
        
        // Clean up old cache entries (keep only last 20 searches)
        if searchCache.count > 20 {
            let sortedKeys = searchCache.sorted { $0.value.timestamp < $1.value.timestamp }
            for (key, _) in sortedKeys.prefix(searchCache.count - 20) {
                searchCache.removeValue(forKey: key)
            }
        }
        
        print("✅ Found \(validProducts.count) valid products for: \(query)")
        return validProducts
    }
    
    // Get product by barcode
    func getProduct(barcode: String) async throws -> LegacyOFFProduct {
        // Get current language code from LanguageManager
        let languageCode = LanguageManager.shared.currentLanguage.code
        
        let urlString = "\(baseURL)/api/v2/product/\(barcode).json?lc=\(languageCode)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        print("🔍 Fetching product by barcode: \(barcode) [Language: \(languageCode)]")
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(OFFProductResponse.self, from: data)
        
        guard let product = response.product else {
            throw NSError(domain: "Product not found", code: 404)
        }
        
        return product
    }
}
*/
// End of old embedded OpenFoodFacts service (now in /Invoice/Services/OpenFoodFactsService.swift)

// MARK: - Legacy Food Database View (RENAMED to avoid conflict with new /Invoice/Views/FoodDatabaseView.swift)
struct LegacyFoodDatabaseView: View {
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var searchResults: [LegacyOFFProduct] = []
    @State private var isLoading = false
    @State private var selectedProduct: LegacyOFFProduct?
    @State private var searchTask: Task<Void, Never>?
    @State private var currentSearchTask: Task<Void, Never>?
    @State private var errorMessage: String?
    
    // Quick action categories
    let quickActions = [
        ("Custom Food", "Add manually", "square.and.pencil"),
        ("Recent Foods", "View history", "clock.arrow.circlepath"),
        ("Favorites", "Quick access", "star.fill"),
        ("Water", "Log hydration", "drop.fill")
    ]
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: {
                            isPresented = false
                        }) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.black)
                                .frame(width: 44, height: 44)
                        }
                        
                        Spacer()
                        
                        Text("Log Food")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        // Placeholder for symmetry
                        Color.clear
                            .frame(width: 44, height: 44)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 50)
                    .padding(.bottom, 24)
                    
                    // Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundColor(Color.black.opacity(0.3))
                        
                        TextField("Describe what you ate", text: $searchText)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.black)
                            .submitLabel(.search)
                            .autocorrectionDisabled()
                            .onSubmit {
                                // Cancel debounce task and search immediately
                                searchTask?.cancel()
                                performSearch()
                            }
                            .onChange(of: searchText) { newValue in
                                // Cancel previous search AND debounce tasks
                                searchTask?.cancel()
                                currentSearchTask?.cancel() // ✅ FIX: Cancel in-progress search too!
                                
                                if newValue.isEmpty {
                                    searchResults = []
                                    isLoading = false
                                    errorMessage = nil
                                    return
                                }
                                
                                // Only search if at least 2 characters
                                if newValue.count < 2 {
                                    searchResults = []
                                    isLoading = false
                                    errorMessage = nil
                                    return
                                }
                                
                                // Debounce search - wait 0.3 seconds after user stops typing for better responsiveness
                                searchTask = Task {
                                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 second delay
                                    
                                    if !Task.isCancelled {
                                        await MainActor.run {
                                            performSearch()
                                        }
                                    }
                                }
                            }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                
                // Content
                ScrollView(showsIndicators: false) {
                    ZStack {
                        Color.white // Ensure solid background during transitions
                        
                        VStack(alignment: .leading, spacing: 12) {
                            // Error banner
                            if let errorMessage = errorMessage {
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Search Failed")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                        
                                        Text(errorMessage)
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        self.errorMessage = nil
                                        performSearch()
                                    }) {
                                        Text("Retry")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.white.opacity(0.2))
                                            .cornerRadius(8)
                                    }
                                }
                                .padding(16)
                                .background(Color.red)
                                .cornerRadius(12)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 12)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                            
                            if isLoading {
                                // Enhanced Loading Screen
                                VStack(spacing: 24) {
                                    Spacer()
                                        .frame(height: 120)
                                    
                                    // Animated search icon
                                    ZStack {
                                        Circle()
                                            .fill(Color(red: 0.96, green: 0.96, blue: 0.97))
                                            .frame(width: 100, height: 100)
                                        
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 40, weight: .medium))
                                            .foregroundColor(.black.opacity(0.3))
                                    }
                                    
                                    VStack(spacing: 12) {
                                        Text("Searching food database...")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(.black)
                                        
                                        Text("Finding the best matches for you")
                                            .font(.system(size: 16, weight: .regular))
                                            .foregroundColor(.black.opacity(0.5))
                                    }
                                    .padding(.horizontal, 40)
                                    
                                    // Loading indicator
                                    ProgressView()
                                        .scaleEffect(1.3)
                                        .tint(.black)
                                        .padding(.top, 8)
                                    
                                    Spacer()
                                        .frame(height: 300)
                                }
                                .frame(maxWidth: .infinity, minHeight: 600)
                            } else if !searchResults.isEmpty {
                            // Search Results
                            Text("Results")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 4)
                            
                            ForEach(searchResults) { product in
                                FoodSuggestionRow(
                                    name: product.displayName,
                                    calories: product.nutriments?.energy_kcal_100g.map { "\(Int($0)) cal" } ?? "-- cal",
                                    servingInfo: "100g",
                                    action: {
                                        selectedProduct = product
                                    }
                                )
                            }
                        } else {
                            // Empty state with quick actions
                            VStack(spacing: 32) {
                                Spacer()
                                    .frame(height: 40)
                                
                                // Search illustration
                                VStack(spacing: 16) {
                                    Image(systemName: "fork.knife.circle.fill")
                                        .font(.system(size: 64))
                                        .foregroundColor(.black.opacity(0.2))
                                    
                                    VStack(spacing: 8) {
                                        Text("Search for any food")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(.black)
                                        
                                        Text("Type in the search bar above to find\nnutrition information")
                                            .font(.system(size: 15, weight: .regular))
                                            .foregroundColor(.black.opacity(0.5))
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                .padding(.horizontal, 40)
                                
                                // Quick Actions Grid
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Quick Actions")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 20)
                                    
                                    VStack(spacing: 12) {
                                        ForEach(quickActions, id: \.0) { action in
                                            Button(action: {
                                                // Handle quick action tap
                                                print("Quick action tapped: \(action.0)")
                                            }) {
                                                HStack(spacing: 16) {
                                                    ZStack {
                                                        Circle()
                                                            .fill(Color(red: 0.96, green: 0.96, blue: 0.97))
                                                            .frame(width: 48, height: 48)
                                                        
                                                        Image(systemName: action.2)
                                                            .font(.system(size: 20, weight: .medium))
                                                            .foregroundColor(.black.opacity(0.6))
                                                    }
                                                    
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(action.0)
                                                            .font(.system(size: 17, weight: .semibold))
                                                            .foregroundColor(.black)
                                                        
                                                        Text(action.1)
                                                            .font(.system(size: 14, weight: .regular))
                                                            .foregroundColor(.black.opacity(0.5))
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    Image(systemName: "chevron.right")
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(.black.opacity(0.3))
                                                }
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 12)
                                                .background(Color.white)
                                            }
                                        }
                                    }
                                }
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                            Spacer(minLength: 40)
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
        .sheet(item: $selectedProduct) { product in
            OFFProductDetailView(
                product: product,
                isPresented: Binding<Bool>(
                    get: { selectedProduct != nil },
                    set: { if !$0 { selectedProduct = nil } }
                )
            )
        }
        .onDisappear {
            // Cancel all pending tasks when view is dismissed
            searchTask?.cancel()
            currentSearchTask?.cancel()
            print("🧹 Cancelled pending search tasks on view dismissal")
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty && searchText.count >= 2 else {
            searchResults = []
            isLoading = false
            errorMessage = nil
            return
        }
        
        // Cancel previous search task to prevent race conditions
        currentSearchTask?.cancel()
        
        // Clear previous error
        errorMessage = nil
        
        // Set loading state immediately
        isLoading = true
        
        // Capture the current search text to detect if it changed
        let queryText = searchText
        
        currentSearchTask = Task {
            do {
                // Use the NEW clean architecture service with language filtering
                let language = LanguageManager.shared.currentLanguage
                // Call the new OpenFoodFactsService from /Invoice/Services/OpenFoodFactsService.swift
                // The old embedded actor is commented out at line 16484
                let foodProducts = try await OpenFoodFactsService.shared.searchProducts(query: queryText, language: language)
                
                // Convert new FoodProduct models back to legacy LegacyOFFProduct for compatibility
                let results = foodProducts.map { foodProduct -> LegacyOFFProduct in
                    LegacyOFFProduct(
                        code: foodProduct.id,
                        product_name: foodProduct.name,
                        brands: foodProduct.brand,
                        image_url: foodProduct.imageURL?.absoluteString,
                        nutriments: foodProduct.nutritionalInfo.map { info in
                            LegacyOFFNutriments(
                                energy_kcal_100g: info.caloriesPer100g,
                                proteins_100g: info.proteinPer100g,
                                carbohydrates_100g: info.carbsPer100g,
                                fat_100g: info.fatPer100g,
                                fiber_100g: info.fiberPer100g,
                                sugars_100g: info.sugarsPer100g,
                                sodium_100g: info.sodiumPer100g
                            )
                        },
                        serving_size: foodProduct.servingSize
                    )
                }
                
                // Check if task was cancelled
                guard !Task.isCancelled else {
                    print("🚫 Search task cancelled for: \(queryText)")
                    await MainActor.run {
                        self.isLoading = false
                    }
                    return
                }
                
                await MainActor.run {
                    // Only update if we're still searching for the same text
                    guard queryText == self.searchText else {
                        print("⏭️ Search text changed, ignoring stale results for: \(queryText)")
                        return
                    }
                    
                    // Update both states in a single transaction without animation
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        self.searchResults = results
                        self.isLoading = false
                        self.errorMessage = nil
                    }
                    print("✅ Found \(results.count) results for: \(queryText)")
                }
            } catch is CancellationError {
                // Task was cancelled, don't show error but reset loading state
                print("🚫 Search cancelled for: \(queryText)")
                await MainActor.run {
                    self.isLoading = false
                }
            } catch {
                // Check if task was cancelled after error
                guard !Task.isCancelled else {
                    return
                }
                
                await MainActor.run {
                    // Only update if we're still searching for the same text
                    guard queryText == self.searchText else {
                        return
                    }
                    
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        self.searchResults = []
                        self.isLoading = false
                        
                        // Set user-friendly error message with localization
                        if let urlError = error as? URLError {
                            switch urlError.code {
                            case .notConnectedToInternet, .networkConnectionLost:
                                self.errorMessage = NSLocalizedString("no_internet_connection", comment: "")
                            case .timedOut:
                                self.errorMessage = NSLocalizedString("search_timed_out", comment: "")
                            default:
                                self.errorMessage = NSLocalizedString("unable_to_reach_database", comment: "")
                            }
                        } else {
                            self.errorMessage = NSLocalizedString("search_failed", comment: "")
                        }
                    }
                    print("❌ Search error for '\(queryText)': \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Food Suggestion Row
struct FoodSuggestionRow: View {
    let name: String
    let calories: String
    let servingInfo: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                // Droplet icon - aligned to top
                Image(systemName: "drop.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color.black.opacity(0.3))
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 6) {
                        Text(calories)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Color.black.opacity(0.5))
                        
                        Text("·")
                            .foregroundColor(Color.black.opacity(0.3))
                        
                        Text(servingInfo)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Color.black.opacity(0.5))
                    }
                }
                
                Spacer()
                
                // Plus button - aligned to center
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(red: 0.97, green: 0.97, blue: 0.98))
            .cornerRadius(16)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - OpenFoodFacts Product Detail View
struct OFFProductDetailView: View {
    let product: LegacyOFFProduct
    @Binding var isPresented: Bool
    @State private var servingAmount: Double = 1.0
    @State private var isSaving = false
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.black)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Text("nutrition")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Product image
                        if let imageUrl = product.image_url, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 120, height: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            } placeholder: {
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: 120, height: 120)
                                    
                                    ProgressView()
                                }
                            }
                            .padding(.top, 20)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 20)
                        }
                        
                        // Product name
                        VStack(spacing: 8) {
                            Text(product.displayName)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            
                            if !product.displayBrand.isEmpty {
                                Text(product.displayBrand)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // Serving size info
                        if let servingSize = product.serving_size {
                            Text("Serving: \(servingSize)")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(20)
                        }
                        
                        // Nutrition info (per 100g)
                        if let nutriments = product.nutriments {
                            VStack(spacing: 16) {
                                // Calories
                                if let calories = nutriments.energy_kcal_100g {
                                    HStack(spacing: 8) {
                                        Text("🔥")
                                            .font(.system(size: 20))
                                        
                                        Text("Calories")
                                            .font(.system(size: 15, weight: .regular))
                                            .foregroundColor(.gray)
                                        
                                        Spacer()
                                        
                                        Text("\(Int(calories))")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(.black)
                                        
                                        Text("/ 100g")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.horizontal, 24)
                                }
                                
                                // Macros
                                HStack(spacing: 20) {
                                    if let protein = nutriments.proteins_100g {
                                        VStack(spacing: 8) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color(red: 0.89, green: 0.85, blue: 0.88).opacity(0.3))
                                                    .frame(width: 48, height: 48)
                                                Text("🍗").font(.system(size: 20))
                                            }
                                            Text(String(format: "%.1fg", protein))
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(.black)
                                            Text("Protein")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundColor(.gray)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    
                                    if let carbs = nutriments.carbohydrates_100g {
                                        VStack(spacing: 8) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color(red: 0.96, green: 0.93, blue: 0.87).opacity(0.3))
                                                    .frame(width: 48, height: 48)
                                                Text("🌾").font(.system(size: 20))
                                            }
                                            Text(String(format: "%.1fg", carbs))
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(.black)
                                            Text("Carbs")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundColor(.gray)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    
                                    if let fat = nutriments.fat_100g {
                                        VStack(spacing: 8) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color(red: 0.87, green: 0.90, blue: 0.95).opacity(0.3))
                                                    .frame(width: 48, height: 48)
                                                Text("💧").font(.system(size: 20))
                                            }
                                            Text(String(format: "%.1fg", fat))
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(.black)
                                            Text("Fats")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundColor(.gray)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                                .padding(.horizontal, 24)
                                
                                // Additional nutrients
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 1)
                                    .padding(.horizontal, 24)
                                
                                HStack(spacing: 20) {
                                    if let fiber = nutriments.fiber_100g {
                                        VStack(spacing: 8) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.purple.opacity(0.3))
                                                    .frame(width: 48, height: 48)
                                                Text("🥦").font(.system(size: 20))
                                            }
                                            Text(String(format: "%.1fg", fiber))
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(.black)
                                            Text("Fiber")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundColor(.gray)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    
                                    if let sugar = nutriments.sugars_100g {
                                        VStack(spacing: 8) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.pink.opacity(0.3))
                                                    .frame(width: 48, height: 48)
                                                Text("🍬").font(.system(size: 20))
                                            }
                                            Text(String(format: "%.1fg", sugar))
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(.black)
                                            Text("Sugar")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundColor(.gray)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    
                                    if let sodium = nutriments.sodium_100g {
                                        VStack(spacing: 8) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.orange.opacity(0.3))
                                                    .frame(width: 48, height: 48)
                                                Text("🧂").font(.system(size: 20))
                                            }
                                            Text(String(format: "%.0fmg", sodium * 1000))
                                                .font(.system(size: 15, weight: .bold))
                                                .foregroundColor(.black)
                                            Text("Sodium")
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundColor(.gray)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
                
                // Bottom button
                Button(action: {
                    addToDiary()
                }) {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isSaving ? "Adding..." : "Add to Diary")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .cornerRadius(28)
                }
                .disabled(isSaving)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    private func addToDiary() {
        // Haptic feedback first
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        isSaving = true
        
        // Convert OFFProduct to ScannedFood
        let scannedFood = convertToScannedFood(product: product)
        
        // Save to Firebase asynchronously
        FoodDataManager.shared.saveMeal(scannedFood)
        
        // Close immediately without waiting for Firebase
        // Firebase will update in background via real-time listener
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isSaving = false
            isPresented = false
        }
    }
    
    private func convertToScannedFood(product: LegacyOFFProduct) -> ScannedFood {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let timestamp = formatter.string(from: Date())
        
        // Get nutrition values per 100g
        let nutriments = product.nutriments
        let calories = Int(nutriments?.energy_kcal_100g ?? 0)
        let protein = Int(nutriments?.proteins_100g ?? 0)
        let carbs = Int(nutriments?.carbohydrates_100g ?? 0)
        let fats = Int(nutriments?.fat_100g ?? 0)
        let fiber = Int(nutriments?.fiber_100g ?? 0)
        let sugar = Int(nutriments?.sugars_100g ?? 0)
        let sodium = Int((nutriments?.sodium_100g ?? 0) * 1000) // Convert to mg
        
        // Calculate health score
        let healthScore = calculateHealthScore(
            protein: protein,
            fiber: fiber,
            sugar: sugar,
            sodium: sodium,
            fats: fats
        )
        
        // Determine food emoji based on categories or name
        let icon = determineFoodIcon(for: product)
        
        // Create ingredients breakdown
        let ingredients = [
            "\(product.displayName) - \(calories) cal, 100g"
        ]
        
        return ScannedFood(
            name: product.displayName,
            servings: 1,
            timestamp: timestamp,
            date: Date(),
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            fiber: fiber,
            sugar: sugar,
            sodium: sodium,
            healthScore: healthScore,
            icon: icon,
            imageName: nil,
            ingredients: ingredients
        )
    }
    
    private func calculateHealthScore(protein: Int, fiber: Int, sugar: Int, sodium: Int, fats: Int) -> Int {
        var score = 5 // Start at neutral
        
        // Positive factors
        if protein > 10 { score += 1 }
        if fiber > 5 { score += 1 }
        if protein > 20 { score += 1 }
        
        // Negative factors
        if sugar > 15 { score -= 1 }
        if sodium > 500 { score -= 1 }
        if sugar > 30 { score -= 1 }
        if fats > 20 { score -= 1 }
        
        return max(0, min(10, score))
    }
    
    private func determineFoodIcon(for product: LegacyOFFProduct) -> String {
        let name = product.displayName.lowercased()
        
        // Check for common food categories
        if name.contains("chicken") || name.contains("turkey") || name.contains("meat") {
            return "🍗"
        } else if name.contains("salad") || name.contains("lettuce") {
            return "🥗"
        } else if name.contains("pizza") {
            return "🍕"
        } else if name.contains("burger") || name.contains("sandwich") {
            return "🍔"
        } else if name.contains("pasta") || name.contains("spaghetti") {
            return "🍝"
        } else if name.contains("rice") || name.contains("bowl") {
            return "🍚"
        } else if name.contains("fruit") || name.contains("apple") || name.contains("banana") {
            return "🍎"
        } else if name.contains("bread") || name.contains("toast") {
            return "🍞"
        } else if name.contains("egg") {
            return "🥚"
        } else if name.contains("fish") || name.contains("salmon") {
            return "🐟"
        } else if name.contains("milk") || name.contains("yogurt") {
            return "🥛"
        } else if name.contains("cheese") {
            return "🧀"
        } else if name.contains("coffee") {
            return "☕️"
        } else if name.contains("juice") || name.contains("drink") {
            return "🥤"
        } else if name.contains("cake") || name.contains("dessert") {
            return "🍰"
        } else if name.contains("vegetable") {
            return "🥦"
        } else if name.contains("soup") {
            return "🍲"
        } else {
            return "🍽️" // Default
        }
    }
}

#Preview {
    ContentView()
}


// Streak Manager for tracking writing streaks
@MainActor
class StreakManager: ObservableObject {
    @Published var currentStreak: Int = 0
    @Published var writingDays: Set<Date> = []
    @Published var debugDayOffset: Int = 0 // For debug purposes
    @Published var isDebugSkipActive: Bool = false // Prevent auto-adding during debug skip
    
    private let calendar = Calendar.current
    private let writingDaysKey = "StreakManager_WritingDays"
    private let debugOffsetKey = "StreakManager_DebugOffset"
    private let lastAppOpenKey = "StreakManager_LastAppOpen"
    
    init() {
        // Defer heavy operations to avoid blocking the main thread
        DispatchQueue.main.async { [weak self] in
            self?.loadData()
            self?.trackAppOpening()
            self?.updateStreak()
        }
    }
    
    // Get the current effective date (real date + debug offset)
    var currentEffectiveDate: Date {
        let realDate = Date()
        return calendar.date(byAdding: .day, value: debugDayOffset, to: realDate) ?? realDate
    }
    
    func addWritingDay(_ date: Date? = nil) {
        let targetDate = date ?? currentEffectiveDate
        let startOfDay = calendar.startOfDay(for: targetDate)
        
        // Don't add days during debug skip simulation
        if isDebugSkipActive && calendar.isDate(startOfDay, inSameDayAs: currentEffectiveDate) {
            print("🐛 Prevented adding skipped day during debug simulation")
            return
        }
        
        writingDays.insert(startOfDay)
        updateStreak()
        saveData()
    }
    
    func hasWrittenOnDate(_ date: Date) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        return writingDays.contains(startOfDay)
    }
    
    // Debug function to advance the day by 1
    func advanceDebugDay() {
        isDebugSkipActive = false // Clear skip flag for normal advance
        debugDayOffset += 1
        
        // Automatically add the new day as a writing day to maintain streak
        let newToday = calendar.startOfDay(for: currentEffectiveDate)
        writingDays.insert(newToday)
        
        updateStreak()
        saveData()
        print("🐛 Advanced debug day by 1. Current offset: \(debugDayOffset)")
        print("🐛 Effective current date: \(currentEffectiveDate)")
        print("🐛 Added new day to writing streak: \(newToday)")
    }
    
    // Debug function to skip a day (advance without adding to streak)
    func skipDebugDay() {
        isDebugSkipActive = true // Prevent auto-adding during skip
        debugDayOffset += 1
        
        // Explicitly remove the new "today" from writing days if it exists
        let skippedToday = calendar.startOfDay(for: currentEffectiveDate)
        writingDays.remove(skippedToday)
        
        updateStreak()
        saveData()
        print("🐛 Skipped a day. Current offset: \(debugDayOffset)")
        print("🐛 Effective current date: \(currentEffectiveDate)")
        print("🐛 SKIPPED day - removed from writing streak if it existed")
        print("🐛 Current streak after skip: \(currentStreak)")
    }
    
    // Reset debug offset back to real time
    func resetDebugDay() {
        debugDayOffset = 0
        isDebugSkipActive = false // Clear skip flag on reset
        updateStreak()
        saveData()
        print("🐛 Reset debug day offset")
        print("🐛 Cleared debug skip flag - normal app behavior resumed")
    }
    
    // Track when user opens the app
    func trackAppOpening() {
        // Don't auto-add days during debug skip simulation
        if isDebugSkipActive {
            print("📱 Skipping auto-add during debug skip simulation")
            return
        }
        
        let today = calendar.startOfDay(for: currentEffectiveDate)
        let lastOpenString = UserDefaults.standard.string(forKey: lastAppOpenKey) ?? ""
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let todayString = dateFormatter.string(from: today)
        
        // If this is the first time opening today, add it as a writing day
        if lastOpenString != todayString {
            addWritingDay(today)
            UserDefaults.standard.set(todayString, forKey: lastAppOpenKey)
            print("📱 App opened for first time today - added to streak!")
        }
    }
    
    private func updateStreak() {
        currentStreak = calculateCurrentStreak()
    }
    
    func calculateCurrentStreak() -> Int {
        let today = calendar.startOfDay(for: currentEffectiveDate)
        var streak = 0
        var currentDate = today
        
        // Only count streak if today is included (user opened app today)
        if !hasWrittenOnDate(today) {
            return 0
        }
        
        // Count consecutive days backwards from today
        while hasWrittenOnDate(currentDate) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
            currentDate = previousDay
        }
        
        return streak
    }
    
    func saveData() {
        // Save writing days
        let dateArray = Array(writingDays)
        if let encoded = try? JSONEncoder().encode(dateArray) {
            UserDefaults.standard.set(encoded, forKey: writingDaysKey)
        }
        
        // Save debug offset
        UserDefaults.standard.set(debugDayOffset, forKey: debugOffsetKey)
    }
    
    private func loadData() {
        // Load writing days
        if let data = UserDefaults.standard.data(forKey: writingDaysKey),
           let decoded = try? JSONDecoder().decode([Date].self, from: data) {
            writingDays = Set(decoded)
        }
        
        // Load debug offset
        debugDayOffset = UserDefaults.standard.integer(forKey: debugOffsetKey)
    }
}

// Streak Calendar View matching Figma design
struct StreakCalendarView: View {
    @ObservedObject var streakManager: StreakManager
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var songManager: SongManager
    @State private var giftAnimating = false
    @Binding var showGiftNotification: Bool
    @Binding var giftBoxPosition: CGPoint

    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    private var weekDays: [Date] {
        let effectiveToday = streakManager.currentEffectiveDate
        let startOfToday = calendar.startOfDay(for: effectiveToday)
        
        // Create 7 days centered around today, with today in the second position (index 1)
        return (-1..<6).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startOfToday)
        }
    }
    
    private func isToday(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: streakManager.currentEffectiveDate)
    }
    
    private func isFourthDayFromToday(_ date: Date) -> Bool {
        // Use account creation date, not current date, so gift has a fixed date
        let accountCreationDate = getAccountCreationDate()
        let giftDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 4, to: accountCreationDate) ?? accountCreationDate)
        let checkDate = calendar.startOfDay(for: date)
        return calendar.isDate(giftDate, inSameDayAs: checkDate)
    }
    
    private func getAccountCreationDate() -> Date {
        let userDefaults = UserDefaults.standard
        let accountCreationKey = "AccountCreationDate"
        
        if let savedDate = userDefaults.object(forKey: accountCreationKey) as? Date {
            return savedDate
        } else {
            // First time - set account creation date to today
            let today = calendar.startOfDay(for: Date())
            userDefaults.set(today, forKey: accountCreationKey)
            return today
        }
    }
    
    private func isPartOfCurrentStreak(_ date: Date) -> Bool {
        // Check if this date is part of the current streak
        let today = calendar.startOfDay(for: streakManager.currentEffectiveDate)
        let checkDate = calendar.startOfDay(for: date)
        
        // If it's a future date, it's not part of current streak
        if checkDate > today {
            return false
        }
        
        // If today doesn't have activity, there's no current streak
        if !streakManager.hasWrittenOnDate(today) {
            return false
        }
        
        // Check if there's an unbroken chain from today back to this date
        var currentDate = today
        while currentDate >= checkDate {
            if !streakManager.hasWrittenOnDate(currentDate) {
                return false
            }
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
            currentDate = previousDay
        }
        
        return true
    }
    
    var body: some View {
        ZStack {
        VStack(spacing: 8) {
        // Calendar week view
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { date in
                    let isStreakDay = isPartOfCurrentStreak(date)
                    let isTodayDate = isToday(date)
                    let isGiftDay = isFourthDayFromToday(date)
                    
                VStack(spacing: 8) {
                    // Show gift emoji for 4th day, regular circle for others
                    if isGiftDay {
                        // Gift emoji with pulse and gentle movement animation
                        GeometryReader { geometry in
                            Text("🎁")
                                .font(.system(size: 32))
                                .scaleEffect(giftAnimating ? 1.3 : 1.0)
                                .rotationEffect(.degrees(giftAnimating ? 8 : -8))
                                .opacity(giftAnimating ? 1.0 : 0.9)
                                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: giftAnimating)
                                .onAppear {
                                    giftAnimating = true
                                    // Capture the gift box position
                                    let frame = geometry.frame(in: .global)
                                    giftBoxPosition = CGPoint(
                                        x: frame.midX,
                                        y: frame.midY
                                    )
                                }
                                .onDisappear {
                                    giftAnimating = false
                                }
                                .onTapGesture {
                                    triggerGiftNotification()
                                }
                        }
                        .frame(width: 32, height: 32)
                    } else {
                    // Consistent dashed circle design for all days
                    ZStack {
                        Circle()
                            .stroke(
                                style: StrokeStyle(
                                    lineWidth: 1.5,
                                    lineCap: .round,
                                    dash: [4.5, 4.5] // Dashed design for all days
                                )
                            )
                            .foregroundStyle(
                                isStreakDay ? 
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.96, green: 0.87, blue: 0.70),  // Light beige
                                        Color(red: 0.83, green: 0.69, blue: 0.52),  // Medium beige
                                        Color(red: 0.76, green: 0.60, blue: 0.42),  // Darker beige
                                        Color(red: 0.96, green: 0.87, blue: 0.70)   // Back to light
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) : 
                                LinearGradient(
                                    gradient: Gradient(colors: [.black.opacity(0.3), .black.opacity(0.3)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .background(
                                // Fill background for streak days
                                isStreakDay ? 
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(red: 0.96, green: 0.87, blue: 0.70),  // Light beige
                                                Color(red: 0.83, green: 0.69, blue: 0.52),  // Medium beige
                                                Color(red: 0.76, green: 0.60, blue: 0.42),  // Darker beige
                                                Color(red: 0.96, green: 0.87, blue: 0.70)   // Back to light
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        .opacity(0.15)
                                    )
                                : nil
                            )
                            .frame(width: 32, height: 32) // Same size for all days
                            .scaleEffect(isTodayDate ? 1.1 : 1.0)
                            .shadow(
                                color: isTodayDate ? Color(red: 0.83, green: 0.69, blue: 0.52).opacity(0.6) : .clear,
                                radius: isTodayDate ? 8 : 0,
                                x: 0,
                                y: 0
                            )
                        
                        // Day letter inside circle
                        Text(dayLetter(for: date))
                                .font(.system(size: 14, weight: isTodayDate ? .bold : .medium))
                            .foregroundColor(
                                    isStreakDay ? .black : .black.opacity(0.6)
                            )
                            .shadow(
                                    color: isTodayDate ? Color.black.opacity(0.3) : .clear,
                                    radius: isTodayDate ? 2 : 0,
                                x: 0,
                                y: 0
                            )
                                            }
                    }
                    
                    // Day number below circle (show for all days including gift day)
                    Text(dateFormatter.string(from: date))
                            .font(.system(size: 14, weight: isTodayDate ? .bold : .medium))
                        .foregroundColor(
                                isStreakDay ? .black : .black.opacity(0.8)
                        )
                        .shadow(
                                color: isTodayDate ? Color.black.opacity(0.3) : .clear,
                                radius: isTodayDate ? 2 : 0,
                            x: 0,
                            y: 0
                        )
                }
                .onLongPressGesture(minimumDuration: 0.5) {
                    // Debug feature: long press to simulate streak on this date
                    debugAddStreakDay(date)
                }
                
                if date != weekDays.last {
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 0)
        }
        

        }
    }
    
    private func dayLetter(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        let dayName = formatter.string(from: date)
        return String(dayName.prefix(1))
    }
    
    private func triggerGiftNotification() {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Show notification with animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            showGiftNotification = true
        }
    }
    
    // Debug function to add/remove streak days
    private func debugAddStreakDay(_ date: Date) {
        let startOfDay = calendar.startOfDay(for: date)
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        if streakManager.hasWrittenOnDate(startOfDay) {
            // Remove the day if it exists
            streakManager.writingDays.remove(startOfDay)
            print("🐛 DEBUG: Removed streak day for \(dateFormatter.string(from: date))")
        } else {
            // Add the day if it doesn't exist
            streakManager.writingDays.insert(startOfDay)
            print("🐛 DEBUG: Added streak day for \(dateFormatter.string(from: date))")
        }
        
        // Update streak and save
        streakManager.objectWillChange.send()
        streakManager.saveData()
        
        // Recalculate the current streak
        DispatchQueue.main.async {
            streakManager.currentStreak = streakManager.calculateCurrentStreak()
            print("🐛 DEBUG: Current streak updated to \(streakManager.currentStreak)")
            
            // Show which days are currently in the streak
            let sortedDays = streakManager.writingDays.sorted(by: >)
            let dayStrings = sortedDays.prefix(7).map { dateFormatter.string(from: $0) }
            print("🐛 DEBUG: Recent writing days: \(dayStrings.joined(separator: ", "))")
        }
    }
}

// Home View - Main screen with empty state

// MARK: - End of ContentView
struct TimePickerButton: View {
    @Binding var text: String
    let onUpdate: (String) -> Void
    @State private var showingPicker = false
    
    var body: some View {
        Button(action: {
            showingPicker = true
        }) {
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 45)
                .padding(.vertical, 8)
        }
        .sheet(isPresented: $showingPicker) {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: {
                        showingPicker = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white)
                            .padding(12)
                            .contentShape(Rectangle())
                    }
                }
                .frame(height: 44)
                
                TimePicker(text: $text, onUpdate: onUpdate)
                    .frame(height: 160)
                
                Spacer(minLength: 0)
            }
            .background(Color.black)
            .presentationDetents([.height(250)])
            .presentationDragIndicator(.visible)
        }
    }
}

struct TimePicker: UIViewRepresentable {
    @Binding var text: String
    let onUpdate: (String) -> Void
    
    func makeUIView(context: Context) -> UIPickerView {
        let picker = UIPickerView()
        picker.delegate = context.coordinator
        picker.dataSource = context.coordinator
        
        if let time = parseTimeComponents(text) {
            let minuteRow = max(0, min(time.minutes, 9))
            let secondRow = max(0, min(time.seconds, 59))
            picker.selectRow(minuteRow, inComponent: 0, animated: false)
            picker.selectRow(secondRow, inComponent: 1, animated: false)
        }
        
        return picker
    }
    
    func updateUIView(_ uiView: UIPickerView, context: Context) {
        if let time = parseTimeComponents(text) {
            let minuteRow = max(0, min(time.minutes, 9))
            let secondRow = max(0, min(time.seconds, 59))
            uiView.selectRow(minuteRow, inComponent: 0, animated: false)
            uiView.selectRow(secondRow, inComponent: 1, animated: false)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    private func parseTimeComponents(_ timeString: String) -> (minutes: Int, seconds: Int)? {
        let components = timeString.split(separator: ":")
        guard components.count == 2,
              let minutes = Int(components[0]),
              let seconds = Int(components[1]),
              minutes >= 0, minutes <= 9,
              seconds >= 0, seconds <= 59
        else {
            return nil
        }
        return (minutes, seconds)
    }
    
    class Coordinator: NSObject, UIPickerViewDelegate, UIPickerViewDataSource {
        let parent: TimePicker
        
        init(parent: TimePicker) {
            self.parent = parent
        }
        
        func numberOfComponents(in pickerView: UIPickerView) -> Int {
            return 2
        }
        
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            return component == 0 ? 10 : 60
        }
        
        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            let label = (view as? UILabel) ?? UILabel()
            if component == 0 {
                label.text = "\(row)"
            } else {
                label.text = String(format: "%02d", row)
            }
            label.textColor = .white
            label.font = .systemFont(ofSize: 20, weight: .medium)
            label.textAlignment = .center
            return label
        }
        
        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            let minutes = pickerView.selectedRow(inComponent: 0)
            let seconds = pickerView.selectedRow(inComponent: 1)
            let timeString = "\(minutes):\(String(format: "%02d", seconds))"
            parent.text = timeString
            parent.onUpdate(timeString)
        }
    }
}

struct ToolDetailView: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    let description: String
    let backgroundImage: String
    @State private var userInput = ""
    @State private var generatedText = ""
    @State private var isGenerating = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        HStack {
                            Text(title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(8)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, geometry.safeAreaInsets.top + 1)
                        
                        Text(description)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            .padding(.bottom, 24)
                    }
                    .background(
                        ZStack {
                            Image(backgroundImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity)
                            
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Color.clear, location: 0.0),
                                    .init(color: Color.black.opacity(0.4), location: 0.5),
                                    .init(color: Color.black.opacity(0.95), location: 1.0)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .ignoresSafeArea(.all, edges: .top)
                    )
                    
                    Spacer()
                }
            }
        }
    }
}

struct DetailCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Language Picker Sheet
struct LanguagePickerSheet: View {
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("select_language")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 32)
                
                // Language options
                VStack(spacing: 12) {
                    ForEach(AppLanguage.allCases) { language in
                        Button(action: {
                            languageManager.changeLanguage(to: language)
                            
                            // Small delay then dismiss to show selection
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                dismiss()
                            }
                        }) {
                            HStack(spacing: 16) {
                                Text(language.flag)
                                    .font(.system(size: 32))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(language.name)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.black)
                                    
                                    Text(language.englishName)
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                if languageManager.currentLanguage == language {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(languageManager.currentLanguage == language ? Color.green.opacity(0.1) : Color(.systemGray6))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .background(Color.white)
            .navigationBarHidden(true)
        }
    }
}


// MARK: - End of ContentView
