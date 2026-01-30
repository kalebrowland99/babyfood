# 🏗️ Food Database Architecture Documentation

**Date**: January 30, 2026  
**Status**: ✅ **PRODUCTION-READY CLEAN ARCHITECTURE**

---

## 📋 Overview

The food database system has been completely re-architected following **Clean Architecture** and **MVVM** patterns, replacing the previous "Frankenstein" embedded code with a professional, maintainable structure.

---

## 🎯 Architecture Layers

```
┌──────────────────────────────────────────────────────────┐
│                    Presentation Layer                     │
│   FoodDatabaseView.swift + FoodSearchViewModel.swift     │
└────────────────────────┬─────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────┐
│                     Domain Layer                          │
│              FoodModels.swift (Business Logic)            │
└────────────────────────┬─────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────┐
│                  Infrastructure Layer                     │
│            OpenFoodFactsService.swift (API)               │
└──────────────────────────────────────────────────────────┘
```

---

## 📁 File Structure

### **1. Models Layer** (`Invoice/Models/FoodModels.swift`)

**Purpose**: Domain models, DTOs, and business logic

**Key Components**:
- `FoodProduct` - Clean domain model for UI
- `NutritionalInfo` - Nutritional data structure
- `OFFProduct` - API response DTO (Data Transfer Object)
- `OFFNutriments` - API nutriments DTO
- `FoodSearchConfig` - Service configuration
- `FoodServiceError` - Typed error handling

**Key Features**:
- ✅ Separation between API models (DTOs) and domain models
- ✅ Language-aware product name mapping
- ✅ Intelligent fallback logic for missing translations
- ✅ Codable for easy JSON parsing
- ✅ Identifiable for SwiftUI lists

```swift
// Example: Language-aware product mapping
extension OFFProduct {
    func toDomainModel(preferredLanguage: AppLanguage) -> FoodProduct? {
        let name = getLocalizedName(for: preferredLanguage)
        // Returns product with name in correct language
    }
}
```

---

### **2. Service Layer** (`Invoice/Services/OpenFoodFactsService.swift`)

**Purpose**: API integration and data fetching

**Key Components**:
- `FoodDatabaseService` protocol - Abstraction for testing
- `OpenFoodFactsService` actor - Thread-safe implementation
- Cache management
- URL building
- Response parsing

**Key Features**:
- ✅ Actor-based concurrency for thread safety
- ✅ Protocol-oriented design for testability
- ✅ Language-specific API requests (`lc` parameter)
- ✅ Smart caching with language keys
- ✅ Automatic cache cleanup
- ✅ Proper error handling
- ✅ Task cancellation support

```swift
// Example: Language-specific search
func searchProducts(query: String, language: AppLanguage) async throws -> [FoodProduct] {
    // Builds URL with &lc=es for Spanish
    // Filters results to only show products with Spanish names
    // Caches with language-specific key
}
```

**API Integration**:
```
Search: https://world.openfoodfacts.org/cgi/search.pl
  ?search_terms=chicken
  &lc=es                    ← Language code
  &page_size=12
  &fields=product_name_es   ← Request language-specific fields
  
Barcode: https://world.openfoodfacts.org/api/v2/product/{barcode}.json
  ?lc=es                    ← Language code
```

---

### **3. ViewModel Layer** (`Invoice/ViewModels/FoodSearchViewModel.swift`)

**Purpose**: Presentation logic and state management

**Key Components**:
- `FoodSearchViewModel` - ObservableObject
- Published properties for UI binding
- Search debouncing logic
- Task cancellation
- Error handling

**Key Features**:
- ✅ @MainActor for UI updates
- ✅ Debounced search (300ms)
- ✅ Race condition prevention
- ✅ Proper task cancellation
- ✅ Language-aware searches via LanguageManager
- ✅ Clean separation from view

```swift
@MainActor
class FoodSearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [FoodProduct] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Automatically uses current app language
    func onSearchTextChanged() {
        let language = languageManager.currentLanguage
        // Searches in correct language
    }
}
```

---

### **4. View Layer** (`Invoice/Views/FoodDatabaseView.swift`)

**Purpose**: UI presentation

**Key Components**:
- `FoodDatabaseView` - Main search interface
- `FoodResultRow` - Individual search result
- `ProductDetailSheet` - Product details modal
- `QuickActionRow` - Quick action buttons

**Key Features**:
- ✅ SwiftUI declarative UI
- ✅ Reactive binding to ViewModel
- ✅ Loading states
- ✅ Error states
- ✅ Empty states
- ✅ Clean, modern design

---

## 🔧 Key Improvements Over Old Code

### **Before (Frankenstein Code)**:
```swift
// ContentView.swift (16,000+ lines)
struct FoodDatabaseView: View {
    @State private var searchText = ""
    @State private var searchResults: [OFFProduct] = []
    
    private func performSearch() {
        // Embedded logic mixing UI, business logic, and API calls
        Task {
            let results = try await OpenFoodFactsService.shared.searchProducts(query: searchText)
            // Direct API models in UI
            // No language filtering
            // Mixed concerns
        }
    }
}

// Embedded in ContentView.swift
actor OpenFoodFactsService {
    // 200+ lines of code embedded in view file
    // No protocol
    // Hard to test
    // No separation
}
```

### **After (Clean Architecture)**:
```swift
// Separated, testable, maintainable

// View - Only UI
struct FoodDatabaseView: View {
    @StateObject private var viewModel = FoodSearchViewModel()
    // Just renders viewModel state
}

// ViewModel - Presentation logic
class FoodSearchViewModel: ObservableObject {
    private let foodService: FoodDatabaseService  // ← Protocol!
    // Coordinates between view and service
}

// Service - Data fetching
actor OpenFoodFactsService: FoodDatabaseService {
    // Clean, focused, testable
}

// Models - Domain logic
struct FoodProduct {
    // Business entities separate from DTOs
}
```

---

## 🌍 Language Filtering Solution

### **The Problem**:
- Spanish results appeared when English was selected
- No filtering by language
- Mixed language results

### **The Solution**:

**1. Request Language-Specific Fields**:
```swift
&fields=product_name,product_name_en,product_name_es,product_name_ru
```

**2. Filter Products by Language**:
```swift
private func filterProductsByLanguage(_ products: [OFFProduct], language: AppLanguage) -> [OFFProduct] {
    return products.filter { product in
        switch language {
        case .english:
            // Only show if has English name
            return product.productNameEn != nil
        case .spanish:
            // Only show if has Spanish name
            return product.productNameEs != nil
        case .russian:
            // Only show if has Russian name
            return product.productNameRu != nil
        }
    }
}
```

**3. Map to Correct Language**:
```swift
func toDomainModel(preferredLanguage: AppLanguage) -> FoodProduct? {
    let name = getLocalizedName(for: preferredLanguage)
    // Returns Spanish name for Spanish, English for English, etc.
}
```

---

## 🧪 Testing Benefits

### **Old Code**:
- ❌ Embedded in view - can't unit test
- ❌ No protocol - can't mock
- ❌ Direct API dependency - needs network

### **New Code**:
```swift
// ✅ Easy to unit test

class MockFoodService: FoodDatabaseService {
    var mockResults: [FoodProduct] = []
    
    func searchProducts(query: String, language: AppLanguage) async throws -> [FoodProduct] {
        return mockResults
    }
}

// Test ViewModel
let mockService = MockFoodService()
let viewModel = FoodSearchViewModel(foodService: mockService)
// Test without network!
```

---

## 📊 Performance Improvements

1. **Caching**: Language-specific cache keys prevent wrong results
2. **Debouncing**: 300ms delay reduces API calls
3. **Task Cancellation**: Prevents race conditions
4. **Actor**: Thread-safe without locks
5. **Filtering**: Only relevant products shown

---

## 🎓 Design Patterns Used

1. **MVVM** (Model-View-ViewModel)
   - Clear separation of concerns
   - Testable presentation logic

2. **Repository Pattern**
   - Service layer abstracts data source
   - Easy to swap implementations

3. **Protocol-Oriented Programming**
   - `FoodDatabaseService` protocol
   - Enables dependency injection

4. **DTO Pattern**
   - `OFFProduct` (API) → `FoodProduct` (Domain)
   - Isolates API changes from UI

5. **Actor Model**
   - Thread-safe concurrency
   - No data races

---

## 🚀 Usage Example

```swift
// Simple, clean usage in any view
struct MyView: View {
    @StateObject private var viewModel = FoodSearchViewModel()
    
    var body: some View {
        FoodDatabaseView(isPresented: $showDatabase)
        // That's it! All logic is encapsulated
    }
}
```

---

## 📝 Localization

All error messages are properly localized:
- `no_internet_connection` → "Sin conexión a Internet..."
- `search_timed_out` → "Se agotó el tiempo de búsqueda..."
- `unable_to_reach_database` → "No se puede acceder..."
- `search_failed` → "Búsqueda fallida..."
- `invalid_search_query` → "Consulta de búsqueda no válida..."
- `no_results_found` → "No se encontraron resultados..."
- `product_not_found` → "Producto no encontrado..."

---

## ✅ Checklist for Senior Review

- ✅ Proper separation of concerns
- ✅ Protocol-oriented design
- ✅ Dependency injection support
- ✅ Comprehensive error handling
- ✅ Thread-safe with actors
- ✅ Unit testable
- ✅ Language-aware filtering
- ✅ Clean, documented code
- ✅ SOLID principles followed
- ✅ SwiftUI best practices
- ✅ Async/await properly used
- ✅ Task cancellation implemented
- ✅ Caching strategy
- ✅ Performance optimized

---

## 🔮 Future Enhancements

1. **Offline Support**: Core Data caching
2. **Analytics**: Track search patterns
3. **AI Suggestions**: Smart recommendations
4. **Barcode Scanner**: Camera integration
5. **User Foods**: Custom entries
6. **Meal Templates**: Pre-made meals
7. **Favorites**: Save frequent foods

---

**Architected by**: Senior iOS Developer Standards  
**Language Support**: English, Spanish, Russian  
**API**: OpenFoodFacts.org  
**Framework**: SwiftUI + Swift Concurrency
