//
//  AddInvoiceItemView.swift
//  Invoice
//
//  Form for adding/editing invoice items
//

import SwiftUI

struct AddInvoiceItemView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var priceBookManager = PriceBookManager.shared
    
    let onSave: (InvoiceItem) -> Void
    let existingItem: InvoiceItem?
    let isInvoiceContext: Bool
    
    @State private var selectedType: InvoiceItem.ItemType
    @State private var itemName: String
    @State private var itemDetails: String
    @State private var unitPrice: String
    @State private var quantity: String
    @State private var selectedUnitType: String?
    @State private var discount: String
    @State private var discountIsPercentage: Bool
    @State private var discountEnabled: Bool
    @State private var isTaxable: Bool
    @State private var saveToPriceBook: Bool
    @State private var showingUnitTypePicker = false
    
    init(existingItem: InvoiceItem? = nil, isInvoiceContext: Bool = false, onSave: @escaping (InvoiceItem) -> Void) {
        self.existingItem = existingItem
        self.isInvoiceContext = isInvoiceContext
        self.onSave = onSave
        
        // Initialize state from existing item or defaults
        if let item = existingItem {
            _selectedType = State(initialValue: item.itemType)
            _itemName = State(initialValue: item.name)
            _itemDetails = State(initialValue: item.description ?? "")
            _unitPrice = State(initialValue: String(format: "%.0f", item.unitPrice))
            _quantity = State(initialValue: String(format: "%.0f", item.quantity))
            _selectedUnitType = State(initialValue: item.unitType)
            _discount = State(initialValue: item.discount > 0 ? String(format: "%.0f", item.discount) : "0")
            _discountIsPercentage = State(initialValue: false) // Default to $ for existing items
            _discountEnabled = State(initialValue: item.discount > 0)
            _isTaxable = State(initialValue: false) // Not stored in InvoiceItem currently
            _saveToPriceBook = State(initialValue: false)
        } else {
            _selectedType = State(initialValue: .service)
            _itemName = State(initialValue: "")
            _itemDetails = State(initialValue: "")
            _unitPrice = State(initialValue: "0")
            _quantity = State(initialValue: "1")
            _selectedUnitType = State(initialValue: nil)
            _discount = State(initialValue: "0")
            _discountIsPercentage = State(initialValue: true)
            _discountEnabled = State(initialValue: false)
            _isTaxable = State(initialValue: false)
            _saveToPriceBook = State(initialValue: true)
        }
    }
    
    var isFormValid: Bool {
        !itemName.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(unitPrice) != nil &&
        Double(quantity) != nil
    }
    
    var calculatedDiscount: Double {
        guard discountEnabled,
              let discountValue = Double(discount),
              let price = Double(unitPrice),
              let qty = Double(quantity) else {
            return 0
        }
        
        if discountIsPercentage {
            return (price * qty) * (discountValue / 100)
        } else {
            return discountValue
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
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    
                    // Form
                    ScrollView {
                        VStack(spacing: 16) {
                            // Name Field
                            TextField("Name", text: $itemName)
                                .font(.system(size: 17))
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(10)
                            
                            // Details Field
                            TextField("Details (e.g. Completed on 1/12)", text: $itemDetails)
                                .font(.system(size: 17))
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(10)
                            
                            // Unit Price, Quantity, Unit Type Section
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 0) {
                                    Text("Unit price")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Text("Quantity")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                    
                                    Text("Unit type")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                HStack(spacing: 0) {
                                    // Unit Price
                                    HStack(spacing: 2) {
                                        Text("$")
                                            .font(.system(size: 17))
                                            .foregroundColor(.primary)
                                        TextField("125", text: $unitPrice)
                                            .font(.system(size: 17))
                                            .keyboardType(.decimalPad)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Divider()
                                        .frame(height: 30)
                                        .padding(.horizontal, 12)
                                    
                                    // Quantity
                                    TextField("1", text: $quantity)
                                        .font(.system(size: 17))
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                    
                                    Divider()
                                        .frame(height: 30)
                                        .padding(.horizontal, 12)
                                    
                                    // Unit Type
                                    Button(action: {
                                        showingUnitTypePicker = true
                                    }) {
                                        Text(selectedUnitType?.capitalized ?? "Optional")
                                            .font(.system(size: 17))
                                            .foregroundColor(selectedUnitType == nil ? .secondary : .primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .cornerRadius(10)
                            }
                            
                            // Discount Section
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Discount")
                                        .font(.system(size: 17))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("$\(String(format: "%.2f", calculatedDiscount))")
                                        .font(.system(size: 17))
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack(spacing: 0) {
                                    // Input row
                                    HStack(spacing: 12) {
                                        TextField("", text: $discount, prompt: Text("0"))
                                            .font(.system(size: 17))
                                            .keyboardType(.decimalPad)
                                            .disabled(!discountEnabled)
                                            .frame(width: 50)
                                        
                                        if discountEnabled && !discount.isEmpty && discount != "0" {
                                            Button(action: {
                                                discount = "0"
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 18))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Toggle("", isOn: $discountEnabled)
                                            .labelsHidden()
                                            .tint(.gray)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.top, 14)
                                    .padding(.bottom, discountEnabled ? 12 : 14)
                                    
                                    // % and $ buttons - only show when discount is enabled
                                    if discountEnabled {
                                        HStack(spacing: 0) {
                                            Button(action: {
                                                discountIsPercentage = true
                                            }) {
                                                Text("%")
                                                    .font(.system(size: 17))
                                                    .foregroundColor(discountIsPercentage ? .primary : .secondary)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 8)
                                                    .background(discountIsPercentage ? Color.white : Color.clear)
                                                    .cornerRadius(5)
                                            }
                                            
                                            Divider()
                                                .frame(height: 18)
                                            
                                            Button(action: {
                                                discountIsPercentage = false
                                            }) {
                                                Text("$")
                                                    .font(.system(size: 17))
                                                    .foregroundColor(!discountIsPercentage ? .primary : .secondary)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 8)
                                                    .background(!discountIsPercentage ? Color.white : Color.clear)
                                                    .cornerRadius(5)
                                            }
                                        }
                                        .padding(2)
                                        .background(Color(UIColor.systemGray5))
                                        .cornerRadius(7)
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, 14)
                                    }
                                }
                                .background(Color.white)
                                .cornerRadius(10)
                            }
                            
                            // Taxable Toggle
                            HStack {
                                Text("Taxable?")
                                    .font(.system(size: 17))
                                Spacer()
                                Toggle("", isOn: $isTaxable)
                                    .labelsHidden()
                                    .tint(.gray)
                            }
                            .padding(16)
                            .background(Color.white)
                            .cornerRadius(10)
                            
                            // Save to Price Book Toggle - Hide in invoice context
                            if !isInvoiceContext {
                                HStack {
                                    Text("Save to price book")
                                        .font(.system(size: 17))
                                    Spacer()
                                    Toggle("", isOn: $saveToPriceBook)
                                        .labelsHidden()
                                        .tint(.gray)
                                }
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 100)
                    }
                    
                    Spacer()
                    
                    // Save Button
                    Button(action: saveItem) {
                        Text("Save")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(isFormValid ? Color.black : Color.gray)
                            .cornerRadius(12)
                    }
                    .disabled(!isFormValid)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("New item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveItem()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid)
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
            ForEach([InvoiceItem.ItemType.service, .material, .other], id: \.self) { type in
                Button(action: {
                    selectedType = type
                }) {
                    Text(type.rawValue)
                        .font(.system(size: 15, weight: selectedType == type ? .medium : .regular))
                        .foregroundColor(selectedType == type ? .primary : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedType == type ?
                                Color.white :
                                Color.clear
                        )
                        .cornerRadius(7)
                }
            }
        }
        .padding(3)
        .background(Color(UIColor.systemGray5))
        .cornerRadius(8)
        .padding(.top, 16)
    }
    
    // MARK: - Unit Type Picker Sheet
    private var unitTypePickerSheet: some View {
        NavigationView {
            List {
                Button(action: {
                    selectedUnitType = nil
                    showingUnitTypePicker = false
                }) {
                    HStack {
                        Text("None")
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedUnitType == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                ForEach(["Hours", "Days"], id: \.self) { unitType in
                    Button(action: {
                        selectedUnitType = unitType.lowercased()
                        showingUnitTypePicker = false
                    }) {
                        HStack {
                            Text(unitType)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedUnitType == unitType.lowercased() {
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
              let priceValue = Double(unitPrice),
              let qtyValue = Double(quantity) else {
            return
        }
        
        let finalDiscount = calculatedDiscount
        let trimmedDetails = itemDetails.trimmingCharacters(in: .whitespaces)
        
        let newItem = InvoiceItem(
            id: existingItem?.id ?? UUID(),
            name: itemName.trimmingCharacters(in: .whitespaces),
            description: trimmedDetails.isEmpty ? nil : trimmedDetails,
            quantity: qtyValue,
            unitPrice: priceValue,
            discount: finalDiscount,
            itemType: selectedType,
            unitType: selectedUnitType
        )
        
        // Save to price book if toggled
        if saveToPriceBook {
            let priceBookItem = PriceBookItem(
                name: itemName.trimmingCharacters(in: .whitespaces),
                unitPrice: priceValue,
                unitType: selectedUnitType == nil ? .none : 
                         selectedUnitType == "hours" ? .hours : 
                         selectedUnitType == "days" ? .days : .none,
                isTaxable: isTaxable,
                type: selectedType == .service ? .service : 
                      selectedType == .material ? .material : .other
            )
            priceBookManager.addItem(priceBookItem)
        }
        
        onSave(newItem)
        dismiss()
    }
}

