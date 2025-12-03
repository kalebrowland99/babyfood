//
//  AddPriceBookItemView.swift
//  Invoice
//
//  Add/Edit Price Book Item View
//

import SwiftUI

struct AddPriceBookItemView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var manager = PriceBookManager.shared
    
    let itemToEdit: PriceBookItem?
    
    @State private var selectedType: PriceBookItemType = .service
    @State private var itemName: String = ""
    @State private var unitPrice: String = ""
    @State private var selectedUnitType: UnitType = .none
    @State private var isTaxable: Bool = false
    @State private var showingUnitTypePicker = false
    
    var isEditing: Bool {
        itemToEdit != nil
    }
    
    var isFormValid: Bool {
        !itemName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !unitPrice.isEmpty &&
        Double(unitPrice) != nil
    }
    
    init(itemToEdit: PriceBookItem? = nil) {
        self.itemToEdit = itemToEdit
        
        // Initialize state if editing
        if let item = itemToEdit {
            _selectedType = State(initialValue: item.type)
            _itemName = State(initialValue: item.name)
            _unitPrice = State(initialValue: String(format: "%.2f", item.unitPrice))
            _selectedUnitType = State(initialValue: item.unitType)
            _isTaxable = State(initialValue: item.isTaxable)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Type Tabs
                    typeTabs
                    
                    // Form
                    ScrollView {
                        VStack(spacing: 24) {
                            // Item Name
                            nameSection
                            
                            // Price and Unit Type
                            priceSection
                            
                            // Taxable
                            taxableSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Update" : "Add") {
                        saveItem()
                    }
                    .foregroundColor(.black)
                    .fontWeight(.semibold)
                    .disabled(!isFormValid)
                    .opacity(isFormValid ? 1 : 0.5)
                }
            }
        }
        .sheet(isPresented: $showingUnitTypePicker) {
            unitTypePickerSheet
        }
    }
    
    // MARK: - Type Tabs
    private var typeTabs: some View {
        HStack(spacing: 0) {
            ForEach(PriceBookItemType.allCases, id: \.self) { type in
                Button(action: {
                    selectedType = type
                }) {
                    Text(type.rawValue)
                        .font(.system(size: 16, weight: selectedType == type ? .semibold : .regular))
                        .foregroundColor(selectedType == type ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedType == type ?
                                Color(UIColor.secondarySystemGroupedBackground) :
                                Color.clear
                        )
                }
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Name Section
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Test \(selectedType.rawValue.lowercased())", text: $itemName)
                .font(.system(size: 17))
                .padding(16)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
        }
    }
    
    // MARK: - Price Section
    private var priceSection: some View {
        HStack(spacing: 16) {
            // Unit Price
            VStack(alignment: .leading, spacing: 8) {
                Text("Unit price")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("$")
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                    
                    TextField("200", text: $unitPrice)
                        .font(.system(size: 17))
                        .keyboardType(.decimalPad)
                }
                .padding(16)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
            
            // Unit Type
            VStack(alignment: .leading, spacing: 8) {
                Text("Unit type")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Button(action: {
                    showingUnitTypePicker = true
                }) {
                    HStack {
                        Text(selectedUnitType == .none ? "Optional" : selectedUnitType.rawValue)
                            .font(.system(size: 17))
                            .foregroundColor(selectedUnitType == .none ? .secondary : .primary)
                        
                        Spacer()
                        
                        if selectedUnitType != .none {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .onTapGesture {
                                    selectedUnitType = .none
                                }
                        }
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Taxable Section
    private var taxableSection: some View {
        HStack {
            Text("Taxable?")
                .font(.system(size: 17))
            
            Spacer()
            
            Toggle("", isOn: $isTaxable)
                .labelsHidden()
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Unit Type Picker Sheet
    private var unitTypePickerSheet: some View {
        NavigationView {
            List {
                ForEach(UnitType.allCases, id: \.self) { unitType in
                    Button(action: {
                        selectedUnitType = unitType
                        showingUnitTypePicker = false
                    }) {
                        HStack {
                            Text(unitType.rawValue)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedUnitType == unitType {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Unit Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingUnitTypePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Save Item
    private func saveItem() {
        guard isFormValid,
              let priceValue = Double(unitPrice) else {
            return
        }
        
        if let existingItem = itemToEdit {
            // Update existing item
            var updatedItem = existingItem
            updatedItem.name = itemName.trimmingCharacters(in: .whitespaces)
            updatedItem.unitPrice = priceValue
            updatedItem.unitType = selectedUnitType
            updatedItem.isTaxable = isTaxable
            updatedItem.type = selectedType
            
            manager.updateItem(updatedItem)
        } else {
            // Create new item
            let newItem = PriceBookItem(
                name: itemName.trimmingCharacters(in: .whitespaces),
                unitPrice: priceValue,
                unitType: selectedUnitType,
                isTaxable: isTaxable,
                type: selectedType
            )
            
            manager.addItem(newItem)
        }
        
        dismiss()
    }
}

// MARK: - Preview
struct AddPriceBookItemView_Previews: PreviewProvider {
    static var previews: some View {
        AddPriceBookItemView()
    }
}

