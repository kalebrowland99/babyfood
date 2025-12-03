//
//  EditInvoiceView.swift
//  Invoice
//
//  Edit existing invoice with warning banner and delete option
//

import SwiftUI
import FirebaseFirestore

struct EditInvoiceView: View {
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
    @State private var showingIssuedDatePicker = false
    @State private var showingDueDatePicker = false
    @State private var isSavingInvoice = false
    @State private var showingDeleteConfirmation = false
    
    var isInvoiceSent: Bool {
        invoice.status == "sent" || invoice.sentAt != nil
    }
    
    init(invoice: Invoice, showSuccessAlert: Binding<Bool>, confettiTrigger: Binding<Int>) {
        self._invoice = State(initialValue: invoice)
        self._showSuccessAlert = showSuccessAlert
        self._confettiTrigger = confettiTrigger
        print("🔧 Editing invoice #\(invoice.number)")
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
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
                            
                            Text("Edit invoice")
                                .font(.system(size: 20, weight: .bold))
                            
                            Spacer()
                            
                            Button("Preview") {
                                showingPreview = true
                            }
                            .foregroundColor(.black)
                            
                            Button("Done") {
                                saveChanges()
                            }
                            .foregroundColor(.black)
                            .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 20)
                        
                        // Warning Banner (only if invoice has been sent)
                        if isInvoiceSent {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.yellow.opacity(0.3))
                                        .frame(width: 48, height: 48)
                                    
                                    Image(systemName: "envelope.badge.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.orange)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("The invoice has already been sent")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black)
                                    
                                    Text("Make sure that your client will not pay before you edit")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                            }
                            .padding(16)
                            .background(Color.yellow.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                        
                        // Issued, Due, Number
                        HStack(spacing: 12) {
                            Button(action: { showingIssuedDatePicker = true }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Issued")
                                        .font(.system(size: 13))
                                        .foregroundColor(.gray)
                                    Text(formatDate(invoice.issuedDate))
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: { showingDueDatePicker = true }) {
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
                                        Divider().padding(.horizontal, 16)
                                    }
                                }
                                
                                if !invoice.items.isEmpty {
                                    Divider().padding(.horizontal, 16)
                                }
                                
                                Button(action: { showingAddItem = true }) {
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
                        
                        // Summary Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Summary")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                if !invoice.items.isEmpty {
                                    SummaryRow(title: "Subtotal", amount: invoice.subtotal)
                                    
                                    Button(action: { showingDiscount = true }) {
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
                                    
                                    Button(action: { showingTax = true }) {
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
                                    Divider().padding(.horizontal, 16)
                                    
                                    Button(action: { showingPayments = true }) {
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
                                
                                Button(action: { showingPhotoPicker = true }) {
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
                        
                        // Spacer for bottom buttons
                        Color.clear.frame(height: 160)
                    }
                }
                .background(Color(UIColor.systemGroupedBackground))
                .navigationBarHidden(true)
            }
            
            // Bottom buttons
            VStack(spacing: 12) {
                // Delete Invoice Button
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Text("Delete Invoice")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                
                // Save Button
                Button(action: {
                    saveChanges()
                }) {
                    HStack {
                        if isSavingInvoice {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isSavingInvoice ? "Saving..." : "Save")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                    .cornerRadius(12)
                }
                .disabled(isSavingInvoice)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color(UIColor.systemGroupedBackground))
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
                AddInvoiceItemView(isInvoiceContext: true, onSave: { item in
                    invoice.items.append(item)
                    recalculateTotals()
                })
            } else {
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
        .sheet(isPresented: $showingIssuedDatePicker) {
            IssuedDatePickerModal(selectedDate: $invoice.issuedDate)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingDueDatePicker) {
            DueDatePickerModal(dueDate: $invoice.dueDate)
                .presentationDetents([.height(450)])
        }
        .alert("Delete Invoice", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteInvoice()
            }
        } message: {
            Text("Are you sure you want to delete this invoice? This action cannot be undone.")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func saveChanges() {
        isSavingInvoice = true
        let db = Firestore.firestore()
        
        do {
            let encoder = Firestore.Encoder()
            let invoiceData = try encoder.encode(invoice)
            
            print("💾 UPDATING INVOICE IN FIRESTORE:")
            print("   - Document ID: \(invoice.id.uuidString)")
            print("   - Invoice #: \(invoice.number)")
            
            db.collection("invoices").document(invoice.id.uuidString).setData(invoiceData) { error in
                isSavingInvoice = false
                if let error = error {
                    print("❌ Error updating invoice: \(error.localizedDescription)")
                } else {
                    print("✅ Invoice updated successfully")
                    dismiss()
                }
            }
        } catch {
            print("❌ Error encoding invoice: \(error.localizedDescription)")
            isSavingInvoice = false
        }
    }
    
    private func deleteInvoice() {
        let db = Firestore.firestore()
        
        print("🗑️ DELETING INVOICE FROM FIRESTORE:")
        print("   - Document ID: \(invoice.id.uuidString)")
        print("   - Invoice #: \(invoice.number)")
        
        db.collection("invoices").document(invoice.id.uuidString).delete { error in
            if let error = error {
                print("❌ Error deleting invoice: \(error.localizedDescription)")
            } else {
                print("✅ Invoice deleted successfully")
                dismiss()
            }
        }
    }
    
    private func recalculateTotals() {
        invoice.subtotal = invoice.items.reduce(0) { $0 + $1.total }
        let taxAmount = calculateTaxAmount()
        invoice.total = invoice.subtotal - invoice.discount + taxAmount
    }
    
    private func calculateTaxAmount() -> Double {
        if invoice.tax.isInclusive {
            return (invoice.subtotal - invoice.discount) * (invoice.tax.percentage / 100)
        } else {
            return (invoice.subtotal - invoice.discount) * (invoice.tax.percentage / 100)
        }
    }
}
