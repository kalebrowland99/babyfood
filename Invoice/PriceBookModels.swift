//
//  PriceBookModels.swift
//  Invoice
//
//  Price Book Data Models
//

import Foundation
import SwiftUI

// MARK: - Price Book Item Type
enum PriceBookItemType: String, Codable, CaseIterable {
    case service = "Service"
    case material = "Material"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .service:
            return "wrench.and.screwdriver"
        case .material:
            return "cube.box"
        case .other:
            return "ellipsis.circle"
        }
    }
}

// MARK: - Unit Type
enum UnitType: String, Codable, CaseIterable {
    case none = "None"
    case hours = "Hours"
    case days = "Days"
    
    var abbreviation: String {
        switch self {
        case .none:
            return ""
        case .hours:
            return "hr"
        case .days:
            return "d"
        }
    }
}

// MARK: - Price Book Item
struct PriceBookItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var unitPrice: Double
    var unitType: UnitType
    var isTaxable: Bool
    var type: PriceBookItemType
    var createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(), name: String, unitPrice: Double, unitType: UnitType = .none, isTaxable: Bool = false, type: PriceBookItemType) {
        self.id = id
        self.name = name
        self.unitPrice = unitPrice
        self.unitType = unitType
        self.isTaxable = isTaxable
        self.type = type
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 2
        
        let priceString = formatter.string(from: NSNumber(value: unitPrice)) ?? "$0.00"
        
        if unitType != .none {
            return "\(priceString) / \(unitType.abbreviation)"
        } else {
            return priceString
        }
    }
}

// MARK: - Price Book Manager
@MainActor
class PriceBookManager: ObservableObject {
    static let shared = PriceBookManager()
    
    @Published var items: [PriceBookItem] = []
    
    private let itemsKey = "PriceBookItems"
    
    private init() {
        loadItems()
    }
    
    // MARK: - CRUD Operations
    func addItem(_ item: PriceBookItem) {
        items.append(item)
        saveItems()
    }
    
    func updateItem(_ item: PriceBookItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            var updatedItem = item
            updatedItem.updatedAt = Date()
            items[index] = updatedItem
            saveItems()
        }
    }
    
    func deleteItem(_ item: PriceBookItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }
    
    func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        saveItems()
    }
    
    // MARK: - Filtering
    func items(ofType type: PriceBookItemType?) -> [PriceBookItem] {
        guard let type = type else { return items }
        return items.filter { $0.type == type }
    }
    
    // MARK: - Persistence
    private func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: itemsKey)
        }
    }
    
    private func loadItems() {
        if let data = UserDefaults.standard.data(forKey: itemsKey),
           let decoded = try? JSONDecoder().decode([PriceBookItem].self, from: data) {
            items = decoded
        }
    }
}

