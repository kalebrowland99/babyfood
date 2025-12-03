//
//  InvoiceSendFlow.swift
//  Thrifty
//
//  Invoice detail, preview, and sending flow
//

import SwiftUI
import UIKit
import ConfettiSwiftUI
import FirebaseFunctions

// MARK: - Invoice Detail View
struct InvoiceDetailView: View {
    @Environment(\.dismiss) var dismiss
    let invoice: Invoice
    @Binding var showSuccessAlert: Bool
    @Binding var confettiTrigger: Int
    let dismissToMain: () -> Void
    
    @State private var showingPreview = false
    @State private var showingSendOptions = false
    @State private var showingPaymentMethod = false
    @State private var showingEditInvoice = false
    @State private var isPaid = false
    @State private var isPreviewExpanded = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                        }
                        
                        Spacer()
                        
                        Button("Preview") {
                            showingPreview = true
                        }
                        .foregroundColor(.black)
                        .fontWeight(.medium)
                        
                        Spacer()
                        
                        Menu {
                            Button("Duplicate Invoice") {}
                            Button("Delete Invoice", role: .destructive) {}
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                    
                    // Preview Section with Eye Icon
                    ZStack {
                        // Invoice Preview (behind eye icon)
                        InvoicePreviewMini(invoice: invoice, isExpanded: isPreviewExpanded)
                            .frame(height: isPreviewExpanded ? 500 : 120)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                            .padding(.horizontal, 20)
                        
                        // Eye Icon Button (on top) - only show when not expanded
                        if !isPreviewExpanded {
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    isPreviewExpanded = true
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.95))
                                        .frame(width: 60, height: 60)
                                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
                                    
                                    Image(systemName: "eye")
                                        .font(.system(size: 28))
                                        .foregroundColor(.black)
                                }
                            }
                        }
                        
                        // Close button when expanded
                        if isPreviewExpanded {
                            VStack {
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            isPreviewExpanded = false
                                        }
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 40, height: 40)
                                                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                                            
                                            Image(systemName: "xmark")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.black)
                                        }
                                    }
                                    .padding(.trailing, 30)
                                    .padding(.top, 10)
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding(.bottom, isPreviewExpanded ? 20 : 40)
                    
                    // Client, Amount, and Received Payments in one white box
                    VStack(spacing: 16) {
                        if let client = invoice.client {
                            Text(client.name)
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        
                        Text("$\(String(format: "%.2f", invoice.total))")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text("Due today")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                        
                        Divider()
                            .padding(.horizontal, 16)
                        
                        // Add Received Payment
                        Button(action: {}) {
                            HStack {
                                Text("+ Add received payment")
                                    .font(.system(size: 16))
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                Text("$\(String(format: "%.2f", invoice.receivedPayments))")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 20)
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    
                    // Mark as Paid - in its own white box
                    HStack(spacing: 12) {
                        Text("Has invoice been paid?")
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        Button(action: {
                            isPaid = true
                        }) {
                            Text("Mark as Paid")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(red: 0.2, green: 0.7, blue: 0.4))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.2, green: 0.7, blue: 0.4).opacity(0.15))
                                .cornerRadius(8)
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                    
                    // Details Section
                    VStack(spacing: 0) {
                        DetailRow(label: "Issued", value: formatDate(invoice.issuedDate))
                        
                        Divider()
                            .padding(.leading, 20)
                        
                        DetailRow(label: "Invoice #", value: invoice.number)
                        
                        // Only show Notes section if there are notes
                        if !invoice.notes.isEmpty {
                            Divider()
                                .padding(.leading, 20)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes")
                                    .font(.system(size: 16))
                                    .foregroundColor(.black)
                                Text(invoice.notes)
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    
                    Spacer(minLength: 100)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 16) {
                    // Action Buttons
                    HStack(spacing: 0) {
                        ActionButton(icon: "creditcard", title: "Payment") {
                            showingPaymentMethod = true
                        }
                        ActionButton(icon: "square.and.arrow.up", title: "Share") {
                            shareInvoice()
                        }
                        ActionButton(icon: "printer", title: "Print") {}
                        ActionButton(icon: "pencil", title: "Edit") {
                            showingEditInvoice = true
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Send Invoice Button
                    Button(action: {
                        showingSendOptions = true
                    }) {
                        Text("Send invoice")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .background(Color(UIColor.systemGroupedBackground))
            }
            .navigationBarHidden(true)
        }
        .fullScreenCover(isPresented: $showingPreview) {
            InvoicePreviewView(invoice: invoice)
        }
        .sheet(isPresented: $showingSendOptions) {
            SendOptionsModal(
                invoice: invoice,
                showSuccessAlert: $showSuccessAlert,
                confettiTrigger: $confettiTrigger,
                dismissToMain: dismissToMain
            )
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showingPaymentMethod) {
            PaymentMethodModal()
                .presentationDetents([.height(500)])
        }
        .fullScreenCover(isPresented: $showingEditInvoice) {
            EditInvoiceView(
                invoice: invoice,
                showSuccessAlert: $showSuccessAlert,
                confettiTrigger: $confettiTrigger
            )
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func shareInvoice() {
        let message = "Dear \(invoice.client?.name ?? "Customer"),\n\nPlease find attached your invoice for $\(String(format: "%.2f", invoice.total))."
        
        let activityVC = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            
            var topController = rootVC
            while let presented = topController.presentedViewController {
                topController = presented
            }
            
            activityVC.popoverPresentationController?.sourceView = topController.view
            topController.present(activityVC, animated: true)
        }
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.black)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.black)
                
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Send Options Modal
struct SendOptionsModal: View {
    @Environment(\.dismiss) var dismiss
    let invoice: Invoice
    @Binding var showSuccessAlert: Bool
    @Binding var confettiTrigger: Int
    let dismissToMain: () -> Void
    
    @State private var clientEmail = ""
    @FocusState private var isEmailFieldFocused: Bool
    @State private var isSending = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // To label
                HStack {
                    Text("To")
                    .font(.system(size: 17))
                    .foregroundColor(.black)
                Spacer()
            }
            .padding(.horizontal, 60)
            .padding(.top, 40)
            .padding(.bottom, 12)
            
            // Error message
            if showError {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .padding(.horizontal, 60)
                    .padding(.bottom, 8)
            }
            
            // Email text field
            TextField("", text: $clientEmail)
                .placeholder(when: clientEmail.isEmpty) {
                    Text("Client's email")
                        .foregroundColor(Color(UIColor.placeholderText))
                        .font(.system(size: 17))
                }
                .font(.system(size: 17))
                .focused($isEmailFieldFocused)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .padding(.horizontal, 60)
                .padding(.bottom, 8)
            
            // Divider line under text field
            Rectangle()
                .fill(Color.black)
                .frame(height: 1)
                .padding(.horizontal, 60)
                .padding(.bottom, 24)
            
        // Send button
        Button(action: {
            // Call Firebase function to send invoice
            sendInvoiceToCustomer()
        }) {
                HStack {
                    if isSending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(isSending ? "Sending..." : "Send")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background((clientEmail.isEmpty || isSending) ? Color(UIColor.systemGray3) : Color.black)
                .cornerRadius(12)
            }
            .disabled(clientEmail.isEmpty || isSending)
            .padding(.horizontal, 45)
            .padding(.bottom, 32)
            
            Spacer(minLength: 0)
            }
            .background(Color.white)
            .onAppear {
            // Pre-fill with client email if available
            if let email = invoice.client?.email {
                clientEmail = email
            }
            // Auto-focus the text field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isEmailFieldFocused = true
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        }
        .presentationDetents([.height(280)])
    }
    
    // Send invoice to customer via Firebase Cloud Function
    private func sendInvoiceToCustomer() {
        isSending = true
        showError = false
        
        // Call Firebase Cloud Function
        let functions = Functions.functions()
        functions.httpsCallable("sendInvoice").call([
            "invoiceId": invoice.id.uuidString,
            "recipientEmail": clientEmail,
            "businessName": invoice.businessName,
            "senderEmail": "\(invoice.businessName) <\(invoice.businessEmail ?? "invoices@resend.dev")>"
        ]) { result, error in
            isSending = false
            
            if let error = error {
                // Handle error
                errorMessage = "Failed to send invoice: \(error.localizedDescription)"
                showError = true
                print("❌ Error sending invoice: \(error)")
                return
            }
            
            // Success! Dismiss everything first, then show popup and confetti
            print("✅ Invoice sent successfully")
            print("📧 Sent to: \(clientEmail)")
            
            // Haptic feedback immediately
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Dismiss sheet first
            print("🚪 Step 1: Dismissing send options sheet")
            dismiss()
            
            // Dismiss all views back to main tab
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                print("🚪 Step 2: Dismissing to main tab")
                dismissToMain()
                
                // After dismissing, show alert and confetti on main Invoices tab
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🎉 Step 3: Triggering alert and confetti on main tab")
                    
                    // Show success alert FIRST
                    print("   - Setting showSuccessAlert = true")
                    showSuccessAlert = true
                    
                    // Then trigger confetti with haptic
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        print("   - Setting confettiTrigger += 1")
                        confettiTrigger += 1
                        
                        let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
                        heavyImpact.impactOccurred()
                    }
                }
            }
        }
    }
}

// Custom ViewModifier for placeholder
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Email Composer View
struct EmailComposerView: View {
    @Environment(\.dismiss) var dismiss
    let invoice: Invoice
    @State private var recipientEmail = ""
    @State private var showingSuccessAlert = false
    
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
                
                Button("Customize") {}
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            // Invoice Preview (small)
            ScrollView {
                VStack(spacing: 20) {
                    // Compact Invoice Preview
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) {
                            // Business Logo
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 50, height: 70)
                                .cornerRadius(4)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("INVOICE")
                                    .font(.system(size: 16, weight: .bold))
                                
                                Text(formatDate(invoice.issuedDate))
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // Business Info
                        VStack(alignment: .leading, spacing: 2) {
                            Text("615films")
                                .font(.system(size: 12, weight: .semibold))
                            Text("6154786315")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                            Text("kalebrowland99@gmail.com")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                            Text("800 19th Ave S Nashville Tennessee")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                        
                        // Bill To
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bill To")
                                .font(.system(size: 10, weight: .semibold))
                            if let client = invoice.client {
                                Text(client.name)
                                    .font(.system(size: 11, weight: .semibold))
                                if let email = client.email {
                                    Text(email)
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Items Header
                        HStack {
                            Text("Description")
                                .font(.system(size: 9, weight: .semibold))
                            Spacer()
                            Text("QTY")
                                .font(.system(size: 9, weight: .semibold))
                                .frame(width: 30)
                            Text("Price, USD")
                                .font(.system(size: 9, weight: .semibold))
                                .frame(width: 60, alignment: .trailing)
                            Text("Amount, USD")
                                .font(.system(size: 9, weight: .semibold))
                                .frame(width: 70, alignment: .trailing)
                        }
                        
                        ForEach(invoice.items) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.system(size: 9))
                                    if let desc = item.description {
                                        Text(desc)
                                            .font(.system(size: 8))
                                            .foregroundColor(.gray)
                                    }
                                    if item.discount > 0 {
                                        Text("Incl. $\(String(format: "%.2f", item.discount)) discount")
                                            .font(.system(size: 8))
                                            .foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                                Text("\(Int(item.quantity))")
                                    .font(.system(size: 9))
                                    .frame(width: 30)
                                Text("$\(String(format: "%.2f", item.unitPrice))")
                                    .font(.system(size: 9))
                                    .frame(width: 60, alignment: .trailing)
                                Text("$\(String(format: "%.2f", item.total))")
                                    .font(.system(size: 9))
                                    .frame(width: 70, alignment: .trailing)
                            }
                        }
                        
                        Divider()
                        
                        // Totals
                        VStack(spacing: 4) {
                            HStack {
                                Spacer()
                                Text("Subtotal")
                                    .font(.system(size: 10))
                                Text("$\(String(format: "%.2f", invoice.subtotal))")
                                    .font(.system(size: 10))
                                    .frame(width: 70, alignment: .trailing)
                            }
                            
                            if invoice.discount > 0 {
                                HStack {
                                    Spacer()
                                    Text("Discount")
                                        .font(.system(size: 10))
                                    Text("-$\(String(format: "%.2f", invoice.discount))")
                                        .font(.system(size: 10))
                                        .frame(width: 70, alignment: .trailing)
                                }
                            }
                            
                            if invoice.tax.percentage > 0 {
                                HStack {
                                    Spacer()
                                    Text("Tax \(String(format: "%.1f", invoice.tax.percentage))% (\(invoice.tax.isInclusive ? "Incl." : "Excl."))")
                                        .font(.system(size: 10))
                                    Text("$\(String(format: "%.2f", calculateTaxAmount()))")
                                        .font(.system(size: 10))
                                        .frame(width: 70, alignment: .trailing)
                                }
                            }
                            
                            HStack {
                                Spacer()
                                Text("Total")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("$\(String(format: "%.2f", invoice.total))")
                                    .font(.system(size: 11, weight: .semibold))
                                    .frame(width: 70, alignment: .trailing)
                            }
                            
                            if invoice.receivedPayments > 0 {
                                HStack {
                                    Spacer()
                                    Text("Payments received")
                                        .font(.system(size: 10))
                                    Text("-$\(String(format: "%.2f", invoice.receivedPayments))")
                                        .font(.system(size: 10))
                                        .foregroundColor(.green)
                                        .frame(width: 70, alignment: .trailing)
                                }
                                
                                HStack {
                                    Spacer()
                                    Text("Balance due")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("$\(String(format: "%.2f", invoice.total - invoice.receivedPayments))")
                                        .font(.system(size: 11, weight: .semibold))
                                        .frame(width: 70, alignment: .trailing)
                                }
                            }
                        }
                        
                        if !invoice.notes.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("NOTES & PAYMENT INSTRUCTIONS")
                                    .font(.system(size: 9, weight: .semibold))
                                Text(invoice.notes)
                                    .font(.system(size: 9))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            
            // Email Input Section
            VStack(spacing: 0) {
                Divider()
                
                HStack {
                    Text("To")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .frame(width: 40, alignment: .leading)
                    
                    TextField("", text: $recipientEmail)
                        .font(.system(size: 16))
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .onAppear {
                            recipientEmail = invoice.client?.email ?? ""
                        }
                    
                    if !recipientEmail.isEmpty {
                        Button(action: { recipientEmail = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                // Send Button
                Button(action: {
                    showingSuccessAlert = true
                }) {
                    Text("Send")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(recipientEmail.isEmpty ? Color.gray : Color(red: 0.11, green: 0.11, blue: 0.12))
                        .cornerRadius(12)
                }
                .disabled(recipientEmail.isEmpty)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color(UIColor.systemGroupedBackground))
        }
        .background(Color(UIColor.systemGroupedBackground))
        .alert("Invoice successfully sent", isPresented: $showingSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func calculateTaxAmount() -> Double {
        if invoice.tax.isInclusive {
            return (invoice.subtotal - invoice.discount) * invoice.tax.percentage / (100 + invoice.tax.percentage)
        } else {
            return (invoice.subtotal - invoice.discount) * invoice.tax.percentage / 100
        }
    }
}

// MARK: - Invoice Preview Mini
struct InvoicePreviewMini: View {
    let invoice: Invoice
    let isExpanded: Bool
    @ObservedObject private var profileManager = ProfileManager.shared
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with Logo and Invoice Info
                HStack(alignment: .top) {
                    // Business Logo
                    if let customImage = profileManager.customProfileImage {
                        Image(uiImage: customImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 50)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("INVOICE")
                            .font(.system(size: 14, weight: .bold))
                        Text("#\(invoice.number)")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Text(formatDate(invoice.issuedDate))
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Business Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(invoice.businessName)
                        .font(.system(size: 11, weight: .semibold))
                    if let phone = invoice.businessPhone {
                        Text(phone)
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 16)
                
                // Bill To
                VStack(alignment: .leading, spacing: 2) {
                    Text("BILL TO")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.gray)
                    if let client = invoice.client {
                        Text(client.name)
                            .font(.system(size: 10, weight: .semibold))
                        if let phone = client.phone {
                            Text(phone)
                                .font(.system(size: 8))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 16)
                
                // Show more details when expanded
                if isExpanded {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Items
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(invoice.items) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.system(size: 10, weight: .medium))
                                    if let desc = item.description {
                                        Text(desc)
                                            .font(.system(size: 8))
                                            .foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                                Text("$\(String(format: "%.2f", item.total))")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Totals
                    VStack(spacing: 4) {
                        HStack {
                            Text("Subtotal")
                                .font(.system(size: 10))
                            Spacer()
                            Text("$\(String(format: "%.2f", invoice.subtotal))")
                                .font(.system(size: 10))
                        }
                        
                        if invoice.discount > 0 {
                            HStack {
                                Text("Discount")
                                    .font(.system(size: 10))
                                Spacer()
                                Text("-$\(String(format: "%.2f", invoice.discount))")
                                    .font(.system(size: 10))
                            }
                        }
                        
                        if invoice.tax.percentage > 0 {
                            HStack {
                                Text("Tax")
                                    .font(.system(size: 10))
                                Spacer()
                                Text("$\(String(format: "%.2f", calculateTaxAmount()))")
                                    .font(.system(size: 10))
                            }
                        }
                        
                        HStack {
                            Text("Total")
                                .font(.system(size: 11, weight: .semibold))
                            Spacer()
                            Text("$\(String(format: "%.2f", invoice.total))")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                
                if !isExpanded {
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color.white)
        .disabled(!isExpanded) // Disable scrolling when collapsed
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return "Issued \(formatter.string(from: date))"
    }
    
    private func calculateTaxAmount() -> Double {
        if invoice.tax.isInclusive {
            return (invoice.subtotal - invoice.discount) * invoice.tax.percentage / (100 + invoice.tax.percentage)
        } else {
            return (invoice.subtotal - invoice.discount) * invoice.tax.percentage / 100
        }
    }
}

// MARK: - Payment Method Modal
struct PaymentMethodModal: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Title Section (centered)
            VStack(spacing: 12) {
                Text("Payment method")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.black)
                
                Text("Select how you'd like to get paid")
                    .font(.system(size: 17))
                    .foregroundColor(.gray)
            }
            .padding(.top, 60)
            .padding(.bottom, 40)
            
            // Payment Options
            VStack(spacing: 20) {
                // Tap to Pay
                Button(action: {}) {
                    VStack(spacing: 16) {
                        Image(systemName: "wave.3.right")
                            .font(.system(size: 48))
                            .foregroundColor(.black)
                        
                        Text("Tap to Pay")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(16)
                }
                
                // Payment Link
                Button(action: {}) {
                    VStack(spacing: 16) {
                        Image(systemName: "link")
                            .font(.system(size: 48))
                            .foregroundColor(.black)
                        
                        Text("Payment Link")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(16)
                }
                
                // QR Code
                Button(action: {}) {
                    VStack(spacing: 16) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 48))
                            .foregroundColor(.black)
                        
                        Text("QR Code")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(16)
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .background(Color.white)
    }
}

