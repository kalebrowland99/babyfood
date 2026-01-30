//
//  FoodSearchViewModel.swift
//  Invoice
//
//  View model for food search functionality
//  Clean architecture - Presentation layer
//

import Foundation
import SwiftUI

@MainActor
class FoodSearchViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var searchText: String = ""
    @Published var searchResults: [FoodProduct] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedProduct: FoodProduct?
    
    // MARK: - Private Properties
    
    private let foodService: FoodDatabaseService
    private let languageManager: LanguageManager
    private var searchTask: Task<Void, Never>?
    private var currentSearchTask: Task<Void, Never>?
    
    private let debounceInterval: TimeInterval = 0.3 // 300ms
    private let minimumCharacters: Int = 2
    
    // MARK: - Initialization
    
    init(
        foodService: FoodDatabaseService = OpenFoodFactsService.shared,
        languageManager: LanguageManager = LanguageManager.shared
    ) {
        self.foodService = foodService
        self.languageManager = languageManager
        
        setupSearchObserver()
    }
    
    // MARK: - Public Methods
    
    /// Trigger a search manually
    func search(query: String) {
        searchText = query
    }
    
    /// Select a product
    func selectProduct(_ product: FoodProduct) {
        selectedProduct = product
    }
    
    /// Clear search
    func clearSearch() {
        searchText = ""
        searchResults = []
        errorMessage = nil
        cancelAllTasks()
    }
    
    /// Cancel ongoing searches
    func cancelAllTasks() {
        searchTask?.cancel()
        currentSearchTask?.cancel()
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    private func setupSearchObserver() {
        // Note: In a real app, we'd use Combine's debounce here
        // For now, we'll handle debouncing manually in the search logic
    }
    
    /// Called when search text changes (to be triggered from view)
    func onSearchTextChanged() {
        // Cancel previous search operations
        searchTask?.cancel()
        currentSearchTask?.cancel()
        
        // Clear error
        errorMessage = nil
        
        // Validate input
        guard !searchText.isEmpty && searchText.count >= minimumCharacters else {
            searchResults = []
            isLoading = false
            return
        }
        
        // Start debounce timer
        isLoading = true
        let queryText = searchText
        
        searchTask = Task {
            // Debounce delay
            try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
            
            // Check if cancelled during debounce
            guard !Task.isCancelled else {
                await MainActor.run { self.isLoading = false }
                return
            }
            
            // Perform search
            await performSearch(query: queryText)
        }
    }
    
    private func performSearch(query: String) async {
        // Capture current language
        let language = languageManager.currentLanguage
        
        // Cancel previous search
        currentSearchTask?.cancel()
        
        currentSearchTask = Task {
            do {
                // Call service layer
                let results = try await foodService.searchProducts(
                    query: query,
                    language: language
                )
                
                // Check if task was cancelled
                guard !Task.isCancelled else {
                    print("🚫 [ViewModel] Search cancelled for: \(query)")
                    await MainActor.run { self.isLoading = false }
                    return
                }
                
                // Update UI on main thread
                await MainActor.run {
                    // Verify we're still searching for the same text
                    guard query == self.searchText else {
                        print("⏭️ [ViewModel] Search text changed, ignoring results for: \(query)")
                        return
                    }
                    
                    // Update state without animation for better performance
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        self.searchResults = results
                        self.isLoading = false
                        self.errorMessage = nil
                    }
                    
                    print("✅ [ViewModel] Updated UI with \(results.count) results")
                }
                
            } catch is CancellationError {
                print("🚫 [ViewModel] Search task cancelled")
                await MainActor.run { self.isLoading = false }
                
            } catch {
                // Handle errors
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    guard query == self.searchText else { return }
                    
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        self.searchResults = []
                        self.isLoading = false
                        
                        if let foodError = error as? FoodServiceError {
                            self.errorMessage = foodError.errorDescription
                        } else {
                            self.errorMessage = NSLocalizedString("search_failed", comment: "")
                        }
                    }
                    
                    print("❌ [ViewModel] Search error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Cleanup when view disappears
    func cleanup() {
        cancelAllTasks()
    }
}

// MARK: - Preview Helper

#if DEBUG
extension FoodSearchViewModel {
    static var preview: FoodSearchViewModel {
        let vm = FoodSearchViewModel()
        vm.searchResults = [
            FoodProduct(
                id: "1",
                name: "Chicken Breast",
                brand: "Organic Farms",
                imageURL: nil,
                nutritionalInfo: NutritionalInfo(
                    caloriesPer100g: 165,
                    proteinPer100g: 31,
                    carbsPer100g: 0,
                    fatPer100g: 3.6,
                    fiberPer100g: 0,
                    sugarsPer100g: 0,
                    sodiumPer100g: 0.074,
                    caloriesPerServing: nil,
                    proteinPerServing: nil,
                    carbsPerServing: nil,
                    fatPerServing: nil
                ),
                servingSize: "100g"
            )
        ]
        return vm
    }
}
#endif
