//
//  CreateInvoiceFlow.swift
//  Thrifty
//
//  Invoice creation flow with all modals and screens
//

import SwiftUI
import FirebaseFirestore

// MARK: - Invoice Models
struct Invoice: Identifiable, Codable, Hashable {
    var id = UUID()
    var number: String
    var issuedDate: Date
    var dueDate: DueDate
    var client: Client?
    var items: [InvoiceItem]
    var subtotal: Double
    var discount: Double
    var discountPercentage: Double? // Store the percentage for display
    var discountIsPercentage: Bool? // Track if discount is percentage or fixed amount
    var tax: Tax
    var total: Double
    var receivedPayments: Double
    var photos: [String]
    var notes: String
    
    // Business information (from/sender)
    var businessName: String
    var businessEmail: String?
    var businessPhone: String?
    var businessAddress: String?
    
    // Email tracking
    var sentAt: Date?
    var sentTo: String?
    var status: String? // "draft", "sent", "paid"
    
    enum DueDate: Codable, Hashable {
        case onReceipt
        case customDate(Date)
        case noDueDate
        case days10
        case days15
        case days30
        
        var displayText: String {
            switch self {
            case .onReceipt:
                return "On Receipt"
            case .customDate(_):
                return "Custom Date"
            case .noDueDate:
                return "No Due Date"
            case .days10:
                return "10 days"
            case .days15:
                return "15 days"
            case .days30:
                return "30 days"
            }
        }
        
        var actualDate: Date? {
            switch self {
            case .onReceipt, .noDueDate:
                return nil
            case .customDate(let date):
                return date
            case .days10:
                return Calendar.current.date(byAdding: .day, value: 10, to: Date())
            case .days15:
                return Calendar.current.date(byAdding: .day, value: 15, to: Date())
            case .days30:
                return Calendar.current.date(byAdding: .day, value: 30, to: Date())
            }
        }
    }
}

struct Client: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var email: String?
    var phone: String?
    var address: String?
}

struct InvoiceItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var description: String?
    var quantity: Double
    var unitPrice: Double
    var discount: Double
    var itemType: ItemType
    var unitType: String? // e.g., "hours", "days"
    
    var total: Double {
        (quantity * unitPrice) - discount
    }
    
    enum ItemType: String, Codable {
        case service = "Service"
        case material = "Material"
        case other = "Other"
    }
}

struct Tax: Codable, Hashable {
    var percentage: Double
    var isInclusive: Bool
    
    static let zero = Tax(percentage: 0, isInclusive: false)
}

// MARK: - Create Invoice View
struct CreateInvoiceView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var showSuccessAlert: Bool
    @Binding var confettiTrigger: Int
    @StateObject private var clientManager = ClientManager.shared
    @State private var invoice: Invoice
    @State private var showingAddClient = false
    @State private var showingSelectClient = false
    @State private var showingEditClient = false
    @State private var showingAddItem = false
    @State private var showingPreview = false
    @State private var showingPayments = false
    @State private var showingTax = false
    @State private var showingDiscount = false
    @State private var showingPhotoPicker = false
    @State private var showingInvoiceDetail = false
    @State private var showingIssuedDatePicker = false
    @State private var showingDueDatePicker = false
    @State private var isSavingInvoice = false
    @State private var isLoadingInvoiceNumber = true
    
    init(showSuccessAlert: Binding<Bool>, confettiTrigger: Binding<Int>) {
        self._showSuccessAlert = showSuccessAlert
        self._confettiTrigger = confettiTrigger
        
        // Start with placeholder - will be updated in onAppear
        let invoiceNumber = "001"
        print("🆕 Creating new invoice...")
        
        _invoice = State(initialValue: Invoice(
            number: invoiceNumber,
            issuedDate: Date(),
            dueDate: .onReceipt,
            client: nil,
            items: [],
            subtotal: 0,
            discount: 0,
            tax: .zero,
            total: 0,
            receivedPayments: 0,
            photos: [],
            notes: "",
            businessName: UserDefaults.standard.string(forKey: "businessName") ?? "615films",
            businessEmail: UserDefaults.standard.string(forKey: "businessEmail"),
            businessPhone: UserDefaults.standard.string(forKey: "businessPhone"),
            businessAddress: UserDefaults.standard.string(forKey: "businessAddress"),
            sentAt: nil,
            sentTo: nil,
            status: "draft"
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.black)
                        
                        Spacer()
                        
                        Button("Preview") {
                            showingPreview = true
                        }
                        .foregroundColor(.black)
                        
                        Button("Done") {
                            // Save invoice
                            dismiss()
                        }
                        .foregroundColor(.black)
                        .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                    
                    // Title
                    Text("New invoice")
                        .font(.system(size: 28, weight: .bold))
                        .padding(.bottom, 30)
                    
                    // Date Section
                    HStack(spacing: 40) {
                        // Issued Date (Tappable)
                        Button(action: {
                            showingIssuedDatePicker = true
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Issued")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                                
                                Text(formatDate(invoice.issuedDate))
                                    .font(.system(size: 16))
                                    .foregroundColor(.black)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        // Due Date (Tappable)
                        Button(action: {
                            showingDueDatePicker = true
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Due")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                                
                                Text(invoice.dueDate.displayText)
                                    .font(.system(size: 16))
                                    .foregroundColor(.black)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 8) {
                            Text("#")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                            
                            Text(invoice.number)
                                .font(.system(size: 16))
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    
                    // Client Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Client")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                        
                        if let client = invoice.client {
                            Button(action: {
                                showingEditClient = true
                            }) {
                                HStack {
                                    Text(client.name)
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        invoice.client = nil
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                        } else {
                            Button(action: {
                                // If clients exist, show selection; otherwise go straight to add
                                if clientManager.clients.isEmpty {
                                    showingAddClient = true
                                } else {
                                    showingSelectClient = true
                                }
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                    Text("Add client")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 20)
                    
                    // Items Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Items")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            ForEach(Array(invoice.items.enumerated()), id: \.element.id) { index, item in
                                InvoiceItemRow(item: item, onDelete: {
                                    invoice.items.removeAll { $0.id == item.id }
                                    recalculateTotals()
                                })
                                
                                if index < invoice.items.count - 1 {
                                    Divider()
                                        .padding(.horizontal, 16)
                                }
                            }
                            
                            if !invoice.items.isEmpty {
                                Divider()
                                    .padding(.horizontal, 16)
                            }
                            
                            Button(action: {
                                showingAddItem = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                    Text("Add Item")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)
                    
                    // Stripe Integration (if items added)
                    if !invoice.items.isEmpty {
                        StripeIntegrationCard()
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }
                    
                    // Summary Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Summary")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            if !invoice.items.isEmpty {
                                SummaryRow(title: "Subtotal", amount: invoice.subtotal)
                                
                                Button(action: {
                                    showingDiscount = true
                                }) {
                                    if invoice.discount > 0 {
                                        if let percentage = invoice.discountPercentage, invoice.discountIsPercentage == true {
                                            SummaryRow(
                                                title: "Discount \(String(format: "%.2f", percentage))%",
                                                amount: invoice.discount,
                                                showChevron: true
                                            )
                                        } else {
                                            SummaryRow(
                                                title: "Discount",
                                                amount: invoice.discount,
                                                showChevron: true
                                            )
                                        }
                                    } else {
                                        SummaryRow(title: "Discount", amount: 0, showChevron: true)
                                    }
                                }
                                
                                Button(action: {
                                    showingTax = true
                                }) {
                                    if invoice.tax.percentage > 0 {
                                        SummaryRow(
                                            title: "Tax \(String(format: "%.2f", invoice.tax.percentage))% (\(invoice.tax.isInclusive ? "Incl." : "Excl."))",
                                            amount: calculateTaxAmount(),
                                            showChevron: true
                                        )
                                    } else {
                                        SummaryRow(title: "Tax", amount: 0, showChevron: true)
                                    }
                                }
                            }
                            
                            HStack {
                                Text("Total")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                Menu {
                                    Button("USD") {}
                                    Button("EUR") {}
                                    Button("GBP") {}
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("USD")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                Text("$\(String(format: "%.2f", invoice.total))")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                            .padding(16)
                            
                            if !invoice.items.isEmpty {
                                Divider()
                                    .padding(.horizontal, 16)
                                
                                Button(action: {
                                    showingPayments = true
                                }) {
                                    SummaryRow(title: "Received Payments", amount: invoice.receivedPayments, showChevron: true)
                                }
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)
                    
                    // Photos Section
                    if !invoice.items.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Photos")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)
                            
                            Button(action: {
                                showingPhotoPicker = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                    Text("Add photo")
                                        .font(.system(size: 16, weight: .medium))
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 20)
                        
                        // Notes Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Notes & Payment Instructions")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)
                            
                            TextField("Optional", text: $invoice.notes, axis: .vertical)
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(12)
                                .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 20)
                    }
                    
                    // Create Invoice Button
                    Button(action: {
                        // Save invoice to Firestore, then show detail
                        isSavingInvoice = true
                        saveInvoiceToFirestore { success in
                            isSavingInvoice = false
                            if success {
                                showingInvoiceDetail = true
                            }
                        }
                    }) {
                        HStack {
                            if isSavingInvoice {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isSavingInvoice ? "Creating..." : "Create Invoice")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(isSavingInvoice ? Color.gray : Color(red: 0.11, green: 0.11, blue: 0.12))
                        .cornerRadius(12)
                    }
                    .disabled(isSavingInvoice)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarHidden(true)
            .onAppear {
                if isLoadingInvoiceNumber {
                    fetchNextInvoiceNumber()
                }
            }
        }
        .sheet(isPresented: $showingSelectClient) {
            ClientSelectionModal(
                clients: clientManager.clients,
                onSelect: { client in
                    invoice.client = client
                },
                onAddNew: {
                    showingSelectClient = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingAddClient = true
                    }
                }
            )
        }
        .sheet(isPresented: $showingAddClient) {
            AddClientModal(onSave: { client in
                clientManager.addClient(client)
                invoice.client = client
            })
        }
        .sheet(isPresented: $showingEditClient) {
            if let client = invoice.client {
                EditClientModal(client: client, onSave: { updatedClient in
                    clientManager.updateClient(updatedClient)
                    invoice.client = updatedClient
                }, onRemove: {
                    invoice.client = nil
                })
            }
        }
        .sheet(isPresented: $showingAddItem) {
            if PriceBookManager.shared.items.isEmpty {
                // No price book items - show form directly
                AddInvoiceItemView(isInvoiceContext: true, onSave: { item in
                    invoice.items.append(item)
                    recalculateTotals()
                })
            } else {
                // Has price book items - show picker
                AddItemFromPriceBookModal(onSelect: { item in
                    invoice.items.append(item)
                    recalculateTotals()
                })
            }
        }
        .sheet(isPresented: $showingPreview) {
            InvoicePreviewView(invoice: invoice)
        }
        .sheet(isPresented: $showingPayments) {
            PaymentsModal(amount: $invoice.receivedPayments)
        }
        .sheet(isPresented: $showingTax) {
            TaxModal(tax: $invoice.tax, onSave: {
                recalculateTotals()
            })
        }
        .sheet(isPresented: $showingDiscount) {
            DiscountModal(
                discount: $invoice.discount,
                discountPercentage: $invoice.discountPercentage,
                discountIsPercentage: $invoice.discountIsPercentage,
                subtotal: invoice.subtotal,
                onSave: {
                    recalculateTotals()
                }
            )
        }
        .fullScreenCover(isPresented: $showingInvoiceDetail) {
            InvoiceDetailView(
                invoice: invoice,
                showSuccessAlert: $showSuccessAlert,
                confettiTrigger: $confettiTrigger,
                dismissToMain: {
                    // Dismiss both InvoiceDetailView and CreateInvoiceView
                    showingInvoiceDetail = false
                    dismiss()
                }
            )
        }
        .sheet(isPresented: $showingIssuedDatePicker) {
            IssuedDatePickerModal(selectedDate: $invoice.issuedDate)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingDueDatePicker) {
            DueDatePickerModal(dueDate: $invoice.dueDate)
                .presentationDetents([.height(450)])
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func fetchNextInvoiceNumber() {
        let db = Firestore.firestore()
        
        print("🔢 Fetching next invoice number...")
        
        // Query all invoices ordered by number descending to get the highest
        db.collection("invoices")
            .order(by: "number", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching invoice numbers: \(error.localizedDescription)")
                    // Default to 001 if error
                    self.invoice.number = "001"
                    self.isLoadingInvoiceNumber = false
                    return
                }
                
                if let document = snapshot?.documents.first,
                   let lastNumber = document.data()["number"] as? String,
                   let numberInt = Int(lastNumber) {
                    // Increment the last number
                    let nextNumber = numberInt + 1
                    self.invoice.number = String(format: "%03d", nextNumber)
                    print("✅ Next invoice number: \(self.invoice.number)")
                } else {
                    // No invoices exist, start with 001
                    self.invoice.number = "001"
                    print("✅ First invoice, starting with: 001")
                }
                
                self.isLoadingInvoiceNumber = false
            }
    }
    
    private func saveInvoiceToFirestore(completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        
        do {
            // Convert invoice to dictionary for Firestore
            let encoder = Firestore.Encoder()
            let invoiceData = try encoder.encode(invoice)
            
            let documentID = invoice.id.uuidString
            print("💾 SAVING INVOICE TO FIRESTORE:")
            print("   - Document ID: \(documentID)")
            print("   - Invoice #: \(invoice.number)")
            print("   - Client: \(invoice.client?.name ?? "no client")")
            print("   - Total: $\(invoice.total)")
            
            // Save to Firestore using the invoice ID as document ID
            // setData() will create or overwrite - should NOT create duplicates
            db.collection("invoices").document(documentID).setData(invoiceData) { error in
                if let error = error {
                    print("❌ Error saving invoice to Firestore: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("✅ Invoice saved successfully: \(documentID)")
                    completion(true)
                }
            }
        } catch {
            print("❌ Error encoding invoice: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    private func recalculateTotals() {
        invoice.subtotal = invoice.items.reduce(0) { $0 + $1.total }
        
        let taxAmount = calculateTaxAmount()
        invoice.total = invoice.subtotal - invoice.discount + taxAmount
    }
    
    private func calculateTaxAmount() -> Double {
        if invoice.tax.isInclusive {
            return (invoice.subtotal - invoice.discount) * invoice.tax.percentage / (100 + invoice.tax.percentage)
        } else {
            return (invoice.subtotal - invoice.discount) * invoice.tax.percentage / 100
        }
    }
}

// MARK: - Invoice Item Row
struct InvoiceItemRow: View {
    let item: InvoiceItem
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                
                if let description = item.description {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                HStack(spacing: 6) {
                    Text(item.itemType.rawValue)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    Text("•")
                        .foregroundColor(.gray)
                    Text("\(Int(item.quantity)) × $\(String(format: "%.2f", item.unitPrice))")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    if item.discount > 0 {
                        Text("- \(String(format: "%.2f", item.discount)) DISC")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("$\(String(format: "%.2f", item.total))")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 20))
                }
            }
        }
        .padding(16)
    }
}

// MARK: - Summary Row
struct SummaryRow: View {
    let title: String
    let amount: Double
    var showChevron: Bool = false
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.black)
            
            Spacer()
            
            Text("$\(String(format: "%.2f", amount))")
                .font(.system(size: 16))
                .foregroundColor(.black)
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
    }
}

// MARK: - Stripe Integration Card
struct StripeIntegrationCard: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("stripe")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(red: 0.38, green: 0.44, blue: 1.0))
                
                Spacer()
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.yellow)
            }
            
            Text("Your account setup is incomplete. Additional verification information is required to enable capabilities on this account. Please finish yo...")
                .font(.system(size: 13))
                .foregroundColor(.black)
                .fixedSize(horizontal: false, vertical: true)
            
            Button(action: {}) {
                Text("Complete Set-Up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
    }
}

// MARK: - Add Client Modal
struct AddClientModal: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (Client) -> Void
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 30)
            
            // Title
            Text("New client")
                .font(.system(size: 28, weight: .bold))
                .padding(.bottom, 20)
            
            // Import from contacts
            Button(action: {}) {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.square")
                        .font(.system(size: 16))
                    Text("Import from contacts")
                        .font(.system(size: 15))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .padding(.bottom, 30)
            
            // Form
            VStack(alignment: .leading, spacing: 20) {
                // Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    
                    TextField("Client's name", text: $name)
                        .font(.system(size: 16))
                        .padding()
                        .background(Color.white)
                        .cornerRadius(8)
                }
                
                // Contacts
                Text("Contacts")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .padding(.top, 10)
                
                // E-mail
                HStack {
                    Text("E-mail")
                        .font(.system(size: 16))
                        .frame(width: 80, alignment: .leading)
                    
                    TextField("Optional", text: $email)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(8)
                
                // Phone
                HStack {
                    Text("Phone")
                        .font(.system(size: 16))
                        .frame(width: 80, alignment: .leading)
                    
                    TextField("Optional", text: $phone)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .keyboardType(.phonePad)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(8)
                
                // Address
                HStack(alignment: .top) {
                    Text("Address")
                        .font(.system(size: 16))
                        .frame(width: 80, alignment: .leading)
                        .padding(.top, 4)
                    
                    TextField("Optional", text: $address, axis: .vertical)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .lineLimit(2...3)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(8)
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Save Button
            Button(action: {
                guard !name.isEmpty else { return }
                
                let client = Client(
                    name: name,
                    email: email.isEmpty ? nil : email,
                    phone: phone.isEmpty ? nil : phone,
                    address: address.isEmpty ? nil : address
                )
                onSave(client)
                dismiss()
            }) {
                Text("Save")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(name.isEmpty ? Color.gray : Color.black)
                    .cornerRadius(12)
            }
            .disabled(name.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Edit Client Modal
struct EditClientModal: View {
    @Environment(\.dismiss) var dismiss
    let client: Client
    let onSave: (Client) -> Void
    let onRemove: () -> Void
    
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    
    init(client: Client, onSave: @escaping (Client) -> Void, onRemove: @escaping () -> Void) {
        self.client = client
        self.onSave = onSave
        self.onRemove = onRemove
        _name = State(initialValue: client.name)
        _email = State(initialValue: client.email ?? "")
        _phone = State(initialValue: client.phone ?? "")
        _address = State(initialValue: client.address ?? "")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                }
                Spacer()
                
                Button(action: {
                    guard !name.isEmpty else { return }
                    
                    var updatedClient = client
                    updatedClient.name = name
                    updatedClient.email = email.isEmpty ? nil : email
                    updatedClient.phone = phone.isEmpty ? nil : phone
                    updatedClient.address = address.isEmpty ? nil : address
                    
                    onSave(updatedClient)
                    dismiss()
                }) {
                    Text("Save")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                }
                .disabled(name.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 30)
            
            // Title
            Text("Edit client")
                .font(.system(size: 28, weight: .bold))
                .padding(.bottom, 30)
            
            // Form
            VStack(alignment: .leading, spacing: 20) {
                // Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    
                    TextField("Client's name", text: $name)
                        .font(.system(size: 16))
                        .padding()
                        .background(Color.white)
                        .cornerRadius(8)
                }
                
                // Contacts
                Text("Contacts")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .padding(.top, 10)
                
                // E-mail
                HStack {
                    Text("E-mail")
                        .font(.system(size: 16))
                        .frame(width: 80, alignment: .leading)
                    
                    TextField("Optional", text: $email)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(8)
                
                // Phone
                HStack {
                    Text("Phone")
                        .font(.system(size: 16))
                        .frame(width: 80, alignment: .leading)
                    
                    TextField("Optional", text: $phone)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .keyboardType(.phonePad)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(8)
                
                // Address
                HStack(alignment: .top) {
                    Text("Address")
                        .font(.system(size: 16))
                        .frame(width: 80, alignment: .leading)
                        .padding(.top, 4)
                    
                    TextField("Optional", text: $address, axis: .vertical)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .lineLimit(2...3)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(8)
            }
            .padding(.horizontal, 20)
            
            // Helper text
            Text("Add contacts for quick calling and emailing, and see driving directions on a map.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 40)
                .padding(.top, 30)
            
            Spacer()
            
            // Remove client button
            Button(action: {
                onRemove()
                dismiss()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.minus")
                        .font(.system(size: 16))
                    Text("Remove client from the invoice")
                        .font(.system(size: 16))
                }
                .foregroundColor(.red)
            }
            .padding(.bottom, 20)
            
            // Save Changes Button
            Button(action: {
                guard !name.isEmpty else { return }
                
                var updatedClient = client
                updatedClient.name = name
                updatedClient.email = email.isEmpty ? nil : email
                updatedClient.phone = phone.isEmpty ? nil : phone
                updatedClient.address = address.isEmpty ? nil : address
                
                onSave(updatedClient)
                dismiss()
            }) {
                Text("Save changes")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(name.isEmpty ? Color.gray : Color.black)
                    .cornerRadius(12)
            }
            .disabled(name.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Client Selection Modal
struct ClientSelectionModal: View {
    @Environment(\.dismiss) var dismiss
    let clients: [Client]
    let onSelect: (Client) -> Void
    let onAddNew: () -> Void
    
    @State private var searchText = ""
    
    var filteredClients: [Client] {
        if searchText.isEmpty {
            return clients
        }
        return clients.filter { client in
            client.name.localizedCaseInsensitiveContains(searchText) ||
            (client.email?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (client.phone?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                    }
                    
                    Spacer()
                    
                    Text("Clients")
                        .font(.system(size: 17, weight: .semibold))
                    
                    Spacer()
                    
                    // Invisible placeholder for symmetry
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search client...", text: $searchText)
                        .font(.system(size: 16))
                }
                .padding(12)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                
                // Column Headers
                HStack {
                    Text("Name")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("Balance due")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                
                // Clients List
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredClients) { client in
                            Button(action: {
                                onSelect(client)
                                dismiss()
                            }) {
                                HStack {
                                    Text(client.name)
                                        .font(.system(size: 18))
                                        .foregroundColor(.black)
                                    
                                    Spacer()
                                    
                                    Text("$0.00")
                                        .font(.system(size: 18))
                                        .foregroundColor(.black)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(Color.white)
                            }
                            
                            if client.id != filteredClients.last?.id {
                                Divider()
                                    .padding(.leading, 20)
                            }
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }
                
                // Add Client Button
                Button(action: {
                    dismiss()
                    onAddNew()
                }) {
                    Text("Add client")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.black)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Add Item From Price Book Modal
struct AddItemFromPriceBookModal: View {
    @Environment(\.dismiss) var dismiss
    let onSelect: (InvoiceItem) -> Void
    
    @StateObject private var priceBookManager = PriceBookManager.shared
    @State private var searchText = ""
    @State private var selectedTab = "All"
    @State private var showingAddNewItem = false
    @State private var showingItemForm = false
    @State private var selectedItemForEdit: InvoiceItem? = nil
    let tabs = ["All", "Services", "Materials", "Other"]
    
    // Convert PriceBookItems to InvoiceItems
    var priceBookItems: [InvoiceItem] {
        priceBookManager.items.map { priceBookItem in
            InvoiceItem(
                name: priceBookItem.name,
                description: nil,
                quantity: 1.0,
                unitPrice: priceBookItem.unitPrice,
                discount: 0,
                itemType: convertItemType(priceBookItem.type),
                unitType: priceBookItem.unitType != .none ? priceBookItem.unitType.rawValue.lowercased() : nil
            )
        }
    }
    
    private func convertItemType(_ type: PriceBookItemType) -> InvoiceItem.ItemType {
        switch type {
        case .service:
            return .service
        case .material:
            return .material
        case .other:
            return .other
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                Text("Price book")
                    .font(.system(size: 28, weight: .bold))
                
                Spacer()
                
                // Invisible placeholder for symmetry
                Image(systemName: "arrow.left")
                    .font(.system(size: 20))
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 30)
            
            // Tabs
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        Text(tab)
                            .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? .black : .gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selectedTab == tab ? Color.white : Color.clear)
                            .cornerRadius(8)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            // Content Area
            if filteredItems.isEmpty {
                // Empty State
                VStack(spacing: 16) {
                    Spacer()
                    
                    Text("No items")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("Start by adding a new item")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
            } else {
                // Items List
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredItems) { item in
                            Button(action: {
                                // Open form with pre-filled data (except details & discount)
                                selectedItemForEdit = item
                                showingItemForm = true
                            }) {
                                HStack {
                                    Text(item.name)
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                    
                                    Spacer()
                                    
                                    if let unitType = item.unitType {
                                        Text("$\(String(format: "%.2f", item.unitPrice)) / \(unitType)")
                                            .font(.system(size: 16))
                                            .foregroundColor(.black)
                                    } else {
                                        Text("$\(String(format: "%.2f", item.unitPrice))")
                                            .font(.system(size: 16))
                                            .foregroundColor(.black)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(Color.white)
                            }
                            
                            if item.id != filteredItems.last?.id {
                                Divider()
                                    .padding(.leading, 20)
                            }
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }
            }
            
            // Add New Item Button
            Button(action: {
                showingAddNewItem = true
            }) {
                Text("Add new Item")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.black)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .sheet(isPresented: $showingAddNewItem) {
            AddPriceBookItemView()
        }
        .sheet(isPresented: $showingItemForm) {
            if let selectedItem = selectedItemForEdit {
                // Open form with pre-filled data from price book item
                AddInvoiceItemView(existingItem: selectedItem, isInvoiceContext: true, onSave: { item in
                    onSelect(item)
                    dismiss()
                })
            }
        }
        .onChange(of: showingItemForm) { newValue in
            if !newValue {
                selectedItemForEdit = nil
            }
        }
    }
    
    var filteredItems: [InvoiceItem] {
        var items = priceBookItems
        
        if selectedTab != "All" {
            // Convert tab name to item type (e.g., "Services" -> "Service")
            let targetType = selectedTab == "Services" ? "Service" : 
                           selectedTab == "Materials" ? "Material" : 
                           selectedTab == "Other" ? "Other" : selectedTab
            items = items.filter { $0.itemType.rawValue == targetType }
        }
        
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return items
    }
}

// MARK: - Invoice Preview View
struct InvoicePreviewView: View {
    @Environment(\.dismiss) var dismiss
    let invoice: Invoice
    @ObservedObject private var profileManager = ProfileManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.black)
                
                Spacer()
                
                Text("Preview")
                    .font(.system(size: 17, weight: .semibold))
                
                Spacer()
                
                Button("Customize") {
                    // Customize action
                }
                .foregroundColor(.black)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            // Invoice Preview
            ScrollView {
                VStack(spacing: 20) {
                    // Invoice Content
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) {
                            // Business Logo
                            if let customImage = profileManager.customProfileImage {
                                Image(uiImage: customImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 80)
                                    .cornerRadius(4)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("INVOICE")
                                    .font(.system(size: 20, weight: .bold))
                                
                                Text(formatDate(invoice.issuedDate))
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // Business Info (Dynamic)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(invoice.businessName)
                                .font(.system(size: 14, weight: .semibold))
                            if let phone = invoice.businessPhone {
                                Text(phone)
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                            if let email = invoice.businessEmail {
                                Text(email)
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                            if let address = invoice.businessAddress {
                                Text(address)
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Divider()
                        
                        // Items Table
                        HStack {
                            Text("Description")
                                .font(.system(size: 11, weight: .semibold))
                            Spacer()
                            Text("Qty")
                                .font(.system(size: 11, weight: .semibold))
                                .frame(width: 40)
                            Text("Price, USD")
                                .font(.system(size: 11, weight: .semibold))
                                .frame(width: 80, alignment: .trailing)
                            Text("Amount, USD")
                                .font(.system(size: 11, weight: .semibold))
                                .frame(width: 80, alignment: .trailing)
                        }
                        
                        ForEach(invoice.items) { item in
                            HStack {
                                Text(item.name)
                                    .font(.system(size: 11))
                                Spacer()
                                Text("\(Int(item.quantity))")
                                    .font(.system(size: 11))
                                    .frame(width: 40)
                                Text("$\(String(format: "%.2f", item.unitPrice))")
                                    .font(.system(size: 11))
                                    .frame(width: 80, alignment: .trailing)
                                Text("$\(String(format: "%.2f", item.total))")
                                    .font(.system(size: 11))
                                    .frame(width: 80, alignment: .trailing)
                            }
                        }
                        
                        Divider()
                        
                        // Total
                        HStack {
                            Spacer()
                            Text("Total")
                                .font(.system(size: 12, weight: .semibold))
                            Text("$\(String(format: "%.2f", invoice.total))")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 80, alignment: .trailing)
                        }
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 2)
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Payments Modal
struct PaymentsModal: View {
    @Environment(\.dismiss) var dismiss
    @Binding var amount: Double
    @State private var paidInFull = false
    @State private var inputAmount = "0"
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                Text("Payments")
                    .font(.system(size: 17, weight: .semibold))
                
                Spacer()
                
                // Placeholder for symmetry
                Image(systemName: "arrow.left")
                    .font(.system(size: 20))
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 30)
            
            // Paid in full toggle
            HStack {
                Text("Paid in full")
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                
                Spacer()
                
                Toggle("", isOn: $paidInFull)
                    .labelsHidden()
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            // Amount Section
            HStack {
                Text("$")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.red)
                
                Text(inputAmount)
                    .font(.system(size: 24))
                    .foregroundColor(.black)
                
                Spacer()
                
                Button("Save") {
                    amount = Double(inputAmount) ?? 0
                    dismiss()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.green)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            
            Button("Add Partial Payment") {
                // Add partial payment
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.green)
            .padding(.bottom, 30)
            
            Spacer()
            
            // Number Pad
            VStack(spacing: 1) {
                ForEach(0..<3) { row in
                    HStack(spacing: 1) {
                        ForEach(1...3, id: \.self) { col in
                            let number = row * 3 + col
                            NumberPadButton(text: "\(number)") {
                                if inputAmount == "0" {
                                    inputAmount = "\(number)"
                                } else {
                                    inputAmount += "\(number)"
                                }
                            }
                        }
                    }
                }
                
                HStack(spacing: 1) {
                    NumberPadButton(text: ".") {
                        if !inputAmount.contains(".") {
                            inputAmount += "."
                        }
                    }
                    
                    NumberPadButton(text: "0") {
                        if inputAmount != "0" {
                            inputAmount += "0"
                        }
                    }
                    
                    NumberPadButton(text: "⌫", isDelete: true) {
                        if inputAmount.count > 1 {
                            inputAmount.removeLast()
                        } else {
                            inputAmount = "0"
                        }
                    }
                }
            }
            .background(Color(UIColor.systemGray5))
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Issued Date Picker Modal
struct IssuedDatePickerModal: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedDate: Date
    @State private var tempDate: Date
    
    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        self._tempDate = State(initialValue: selectedDate.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Calendar
            DatePicker("", selection: $tempDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding(.horizontal, 20)
                .padding(.top, 20)
            
            Spacer()
            
            // Done button (implicit - just dismiss)
        }
        .background(Color(UIColor.systemBackground))
        .onDisappear {
            selectedDate = tempDate
        }
    }
}

// MARK: - Due Date Picker Modal
struct DueDatePickerModal: View {
    @Environment(\.dismiss) var dismiss
    @Binding var dueDate: Invoice.DueDate
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Select terms")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .padding(.vertical, 16)
            
            Divider()
            
            VStack(spacing: 0) {
                DueDateOption(title: "No Due Date", isSelected: isNoDueDate) {
                    dueDate = .noDueDate
                    dismiss()
                }
                
                Divider()
                
                DueDateOption(title: "On Receipt", isSelected: isDueDateOnReceipt) {
                    dueDate = .onReceipt
                    dismiss()
                }
                
                Divider()
                
                DueDateOption(title: "10 days", isSelected: is10Days) {
                    dueDate = .days10
                    dismiss()
                }
                
                Divider()
                
                DueDateOption(title: "15 days", isSelected: is15Days) {
                    dueDate = .days15
                    dismiss()
                }
                
                Divider()
                
                DueDateOption(title: "30 days", isSelected: is30Days) {
                    dueDate = .days30
                    dismiss()
                }
            }
            
            Spacer()
            
            // Cancel Button
            Button(action: {
                dismiss()
            }) {
                Text("Cancel")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .background(Color(UIColor.systemBackground))
            .padding(.bottom, 20)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private var isNoDueDate: Bool {
        if case .noDueDate = dueDate {
            return true
        }
        return false
    }
    
    private var isDueDateOnReceipt: Bool {
        if case .onReceipt = dueDate {
            return true
        }
        return false
    }
    
    private var is10Days: Bool {
        if case .days10 = dueDate {
            return true
        }
        return false
    }
    
    private var is15Days: Bool {
        if case .days15 = dueDate {
            return true
        }
        return false
    }
    
    private var is30Days: Bool {
        if case .days30 = dueDate {
            return true
        }
        return false
    }
}

struct DueDateOption: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(UIColor.systemBackground))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tax Modal
struct TaxModal: View {
    @Environment(\.dismiss) var dismiss
    @Binding var tax: Tax
    let onSave: () -> Void
    @State private var inputPercentage = ""
    @State private var isInclusive = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                Text("Tax")
                    .font(.system(size: 17, weight: .semibold))
                
                Spacer()
                
                // Placeholder for symmetry
                Image(systemName: "arrow.left")
                    .font(.system(size: 20))
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 30)
            
            // Percentage input with toggle
            HStack {
                Text(inputPercentage.isEmpty ? "" : inputPercentage)
                    .font(.system(size: 24))
                    .foregroundColor(.black)
                Text("%")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Toggle("", isOn: $isInclusive)
                    .labelsHidden()
                    .tint(.green)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            // Exclusive/Inclusive Picker
            Picker("", selection: $isInclusive) {
                Text("Exclusive").tag(false)
                Text("Inclusive").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            
            Spacer()
            
            // Number Pad
            VStack(spacing: 1) {
                ForEach(0..<3) { row in
                    HStack(spacing: 1) {
                        ForEach(1...3, id: \.self) { col in
                            let number = row * 3 + col
                            NumberPadButton(text: "\(number)") {
                                inputPercentage += "\(number)"
                            }
                        }
                    }
                }
                
                HStack(spacing: 1) {
                    NumberPadButton(text: ".") {
                        if !inputPercentage.contains(".") {
                            inputPercentage += "."
                        }
                    }
                    
                    NumberPadButton(text: "0") {
                        inputPercentage += "0"
                    }
                    
                    NumberPadButton(text: "⌫", isDelete: true) {
                        if !inputPercentage.isEmpty {
                            inputPercentage.removeLast()
                        }
                    }
                }
            }
            .background(Color(UIColor.systemGray5))
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onDisappear {
            tax.percentage = Double(inputPercentage) ?? 0
            tax.isInclusive = isInclusive
            onSave()
        }
    }
}

// MARK: - Number Pad Button
struct NumberPadButton: View {
    let text: String
    var isDelete: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 24, weight: isDelete ? .regular : .light))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(height: 50)
                .background(Color.white)
        }
    }
}

// MARK: - Discount Modal
struct DiscountModal: View {
    @Environment(\.dismiss) var dismiss
    @Binding var discount: Double
    @Binding var discountPercentage: Double?
    @Binding var discountIsPercentage: Bool?
    let subtotal: Double
    let onSave: () -> Void
    
    @State private var inputAmount = ""
    @State private var isPercentage = true
    @State private var discountEnabled = false
    
    var calculatedDiscount: Double {
        guard let value = Double(inputAmount) else { return 0 }
        
        if isPercentage {
            return subtotal * (value / 100)
        } else {
            return value
        }
    }
    
    var displayAmount: String {
        guard let value = Double(inputAmount), !inputAmount.isEmpty else { return "" }
        return String(format: "%.0f", value)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                Text("Discount")
                    .font(.system(size: 17, weight: .semibold))
                
                Spacer()
                
                // Placeholder for symmetry
                Image(systemName: "arrow.left")
                    .font(.system(size: 20))
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 30)
            
            // Discount input with toggle
            HStack {
                Text(displayAmount)
                    .font(.system(size: 24))
                    .foregroundColor(.black)
                Text(isPercentage ? "%" : "$")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
                
                Spacer()
                
                HStack(spacing: 8) {
                    if discountEnabled && !inputAmount.isEmpty {
                        Button(action: {
                            inputAmount = ""
                            discount = 0
                            discountEnabled = false
                            onSave()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Toggle("", isOn: $discountEnabled)
                        .labelsHidden()
                        .tint(.green)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            // %/$ Picker - only show when discount is enabled
            if discountEnabled {
                Picker("", selection: $isPercentage) {
                    Text("%").tag(true)
                    Text("$").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            
            Spacer()
            
            // Number Pad
            VStack(spacing: 1) {
                ForEach(0..<3) { row in
                    HStack(spacing: 1) {
                        ForEach(1...3, id: \.self) { col in
                            let number = row * 3 + col
                            NumberPadButton(text: "\(number)") {
                                if discountEnabled {
                                    inputAmount += "\(number)"
                                }
                            }
                        }
                    }
                }
                
                HStack(spacing: 1) {
                    NumberPadButton(text: ".") {
                        if discountEnabled && !inputAmount.contains(".") {
                            inputAmount += "."
                        }
                    }
                    
                    NumberPadButton(text: "0") {
                        if discountEnabled {
                            inputAmount += "0"
                        }
                    }
                    
                    NumberPadButton(text: "⌫", isDelete: true) {
                        if discountEnabled && !inputAmount.isEmpty {
                            inputAmount.removeLast()
                        }
                    }
                }
            }
            .background(Color(UIColor.systemGray5))
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            if discount > 0 {
                discountEnabled = true
                // Try to determine if it's a percentage or fixed amount
                // For now, assume percentage if it's less than the subtotal
                if discount < subtotal {
                    isPercentage = true
                    let percentage = (discount / subtotal) * 100
                    inputAmount = String(format: "%.0f", percentage)
                } else {
                    isPercentage = false
                    inputAmount = String(format: "%.0f", discount)
                }
            }
        }
        .onChange(of: inputAmount) { newValue in
            if discountEnabled {
                discount = calculatedDiscount
                discountIsPercentage = isPercentage
                if isPercentage, let value = Double(inputAmount) {
                    discountPercentage = value
                } else {
                    discountPercentage = nil
                }
                onSave()
            }
        }
        .onChange(of: isPercentage) { _ in
            if discountEnabled && !inputAmount.isEmpty {
                discount = calculatedDiscount
                discountIsPercentage = isPercentage
                if isPercentage, let value = Double(inputAmount) {
                    discountPercentage = value
                } else {
                    discountPercentage = nil
                }
                onSave()
            }
        }
        .onChange(of: discountEnabled) { newValue in
            if !newValue {
                inputAmount = ""
                discount = 0
                discountPercentage = nil
                discountIsPercentage = nil
                onSave()
            }
        }
    }
}


