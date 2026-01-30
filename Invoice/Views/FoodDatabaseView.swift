//
//  FoodDatabaseView.swift
//  Invoice
//
//  Clean, properly architected food database search view
//  Uses MVVM pattern with ViewModel
//

import SwiftUI

struct FoodDatabaseView: View {
    @Binding var isPresented: Bool
    @StateObject private var viewModel = FoodSearchViewModel()
    
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
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(width: 40, height: 40)
                    }
                    
                    Spacer()
                    
                    Text("Food Database")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    // Invisible placeholder for balance
                    Color.clear
                        .frame(width: 40, height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 16)
                
                // Search Bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.gray)
                    
                    TextField("Search foods...", text: $viewModel.searchText)
                        .font(.system(size: 17))
                        .foregroundColor(.black)
                        .autocapitalization(.none)
                        .submitLabel(.search)
                        .onSubmit {
                            // Trigger search immediately
                            viewModel.onSearchTextChanged()
                        }
                        .onChange(of: viewModel.searchText) { _ in
                            viewModel.onSearchTextChanged()
                        }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                .cornerRadius(16)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                
                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        if viewModel.isLoading {
                            // Loading State
                            VStack(spacing: 24) {
                                Spacer()
                                    .frame(height: 80)
                                
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
                        } else if let errorMessage = viewModel.errorMessage {
                            // Error State
                            VStack(spacing: 16) {
                                Spacer()
                                    .frame(height: 80)
                                
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 48))
                                    .foregroundColor(.red.opacity(0.7))
                                
                                Text(errorMessage)
                                    .font(.system(size: 17))
                                    .foregroundColor(.black.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                
                                Button(action: {
                                    viewModel.onSearchTextChanged()
                                }) {
                                    Text("Try Again")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 32)
                                        .padding(.vertical, 12)
                                        .background(Color.black)
                                        .cornerRadius(12)
                                }
                                .padding(.top, 8)
                                
                                Spacer()
                                    .frame(height: 300)
                            }
                            .frame(maxWidth: .infinity)
                        } else if !viewModel.searchResults.isEmpty {
                            // Search Results
                            Text("Results")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 4)
                            
                            ForEach(viewModel.searchResults) { product in
                                FoodResultRow(
                                    product: product,
                                    action: {
                                        viewModel.selectProduct(product)
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
                                        Text("Search for food")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(.black)
                                        
                                        Text("Type to search our extensive database")
                                            .font(.system(size: 16))
                                            .foregroundColor(.black.opacity(0.5))
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                
                                // Quick Actions
                                VStack(spacing: 12) {
                                    Text("Quick Actions")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 20)
                                    
                                    ForEach(quickActions, id: \.0) { title, subtitle, icon in
                                        QuickActionRow(title: title, subtitle: subtitle, icon: icon)
                                    }
                                }
                                .padding(.top, 16)
                                
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $viewModel.selectedProduct) { product in
            ProductDetailSheet(product: product, isPresented: $viewModel.selectedProduct)
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
}

// MARK: - Food Result Row

struct FoodResultRow: View {
    let product: FoodProduct
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Product image or placeholder
                ZStack {
                    if let imageURL = product.imageURL {
                        AsyncImage(url: imageURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            placeholderView
                        }
                    } else {
                        placeholderView
                    }
                }
                .frame(width: 56, height: 56)
                .cornerRadius(12)
                .clipped()
                
                // Product info
                VStack(alignment: .leading, spacing: 6) {
                    Text(product.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .lineLimit(2)
                    
                    if let brand = product.brand, !brand.isEmpty {
                        Text(brand)
                            .font(.system(size: 15))
                            .foregroundColor(.black.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Calories
                VStack(alignment: .trailing, spacing: 4) {
                    if let calories = product.nutritionalInfo?.caloriesPer100g {
                        Text("\(Int(calories))")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text("cal")
                            .font(.system(size: 13))
                            .foregroundColor(.black.opacity(0.5))
                    } else {
                        Text("--")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
    
    private var placeholderView: some View {
        ZStack {
            Color(red: 0.96, green: 0.96, blue: 0.97)
            Image(systemName: "fork.knife")
                .font(.system(size: 24))
                .foregroundColor(.gray.opacity(0.5))
        }
    }
}

// MARK: - Quick Action Row

struct QuickActionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        Button(action: {
            // Handle quick action
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
                    .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text(subtitle)
                        .font(.system(size: 15))
                        .foregroundColor(.black.opacity(0.5))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.3))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
}

// MARK: - Product Detail Sheet

struct ProductDetailSheet: View {
    let product: FoodProduct
    @Binding var isPresented: FoodProduct?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Product image
                    if let imageURL = product.imageURL {
                        AsyncImage(url: imageURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(height: 200)
                    }
                    
                    // Product name
                    VStack(spacing: 8) {
                        Text(product.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                        
                        if let brand = product.brand {
                            Text(brand)
                                .font(.system(size: 17))
                                .foregroundColor(.black.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Nutritional info
                    if let info = product.nutritionalInfo {
                        VStack(spacing: 16) {
                            Text("Nutritional Information (per 100g)")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.black)
                            
                            VStack(spacing: 12) {
                                if let calories = info.caloriesPer100g {
                                    NutrientRow(name: "Calories", value: "\(Int(calories)) kcal")
                                }
                                if let protein = info.proteinPer100g {
                                    NutrientRow(name: "Protein", value: String(format: "%.1fg", protein))
                                }
                                if let carbs = info.carbsPer100g {
                                    NutrientRow(name: "Carbohydrates", value: String(format: "%.1fg", carbs))
                                }
                                if let fat = info.fatPer100g {
                                    NutrientRow(name: "Fat", value: String(format: "%.1fg", fat))
                                }
                            }
                        }
                        .padding(20)
                        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 20)
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPresented = nil
                    }
                }
            }
        }
    }
}

struct NutrientRow: View {
    let name: String
    let value: String
    
    var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 16))
                .foregroundColor(.black)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview

#if DEBUG
struct FoodDatabaseView_Previews: PreviewProvider {
    static var previews: some View {
        FoodDatabaseView(isPresented: .constant(true))
    }
}
#endif
