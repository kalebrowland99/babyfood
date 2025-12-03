//
//  InvoiceViews.swift
//  Thrifty
//
//  Created by Invoice App
//

import SwiftUI
import ConfettiSwiftUI
import FirebaseFirestore

// MARK: - Invoices View
struct InvoicesView: View {
    @State private var showCreateInvoice = false
    @State private var showSettings = false
    @State private var showSuccessAlert = false
    @State private var confettiTrigger = 0
    @State private var invoices: [Invoice] = []
    @State private var selectedFilter: InvoiceFilter = .all
    @State private var selectedInvoice: Invoice?
    @ObservedObject private var profileManager = ProfileManager.shared
    @StateObject private var songManager = SongManager()
    @StateObject private var streakManager = StreakManager()
    
    enum InvoiceFilter: String, CaseIterable {
        case all = "All"
        case unpaid = "Unpaid"
        case paid = "Paid"
    }
    
    var filteredInvoices: [Invoice] {
        switch selectedFilter {
        case .all:
            return invoices
        case .unpaid:
            return invoices.filter { $0.total > $0.receivedPayments }
        case .paid:
            return invoices.filter { $0.total <= $0.receivedPayments }
        }
    }
    
    var totalAmount: Double {
        invoices.reduce(0) { $0 + $1.total }
    }
    
    var totalReceived: Double {
        invoices.reduce(0) { $0 + $1.receivedPayments }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Navigation Bar
                    HStack {
                        Button(action: {
                            // Message action
                        }) {
                            Image(systemName: "message")
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                        }
                        
                        Spacer()
                        
                        Text("Invoices")
                            .font(.system(size: 34, weight: .bold))
                        
                        Spacer()
                        
                        Button(action: {
                            showSettings = true
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                    
                    if invoices.isEmpty {
                        // Empty State
                        Spacer()
                        
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.3))
                            
                            Text("Start by creating an invoice. Look\nprofessional to your clients")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        
                        Spacer()
                    } else {
                        // Filter Tabs
                        HStack(spacing: 0) {
                            ForEach(InvoiceFilter.allCases, id: \.self) { filter in
                                Button(action: {
                                    selectedFilter = filter
                                }) {
                                    Text(filter.rawValue)
                                        .font(.system(size: 17))
                                        .foregroundColor(selectedFilter == filter ? .black : .gray)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)
                                        .background(selectedFilter == filter ? Color.white : Color.clear)
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(24)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                        
                        // Total and Received
                        VStack(spacing: 4) {
                            HStack {
                                Text("total:")
                                    .font(.system(size: 15))
                                    .foregroundColor(.gray)
                                Text("$\(String(format: "%.2f", totalAmount))")
                                    .font(.system(size: 15))
                                    .foregroundColor(.gray)
                            }
                            HStack {
                                Text("received:")
                                    .font(.system(size: 15))
                                    .foregroundColor(.gray)
                                Text("$\(String(format: "%.2f", totalReceived))")
                                    .font(.system(size: 15))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.bottom, 16)
                        
                        // Invoices List
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(filteredInvoices) { invoice in
                                    Button(action: {
                                        print("📱 Tapped invoice: #\(invoice.number) - \(invoice.client?.name ?? "no client")")
                                        selectedInvoice = invoice
                                    }) {
                                        InvoiceRowView(invoice: invoice)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.horizontal, 20)
                                }
                            }
                            .padding(.bottom, 100)
                        }
                    }
                    
                    Spacer()
                    
                    // Create Invoice Button
                    Button(action: {
                        showCreateInvoice = true
                    }) {
                        Text("Create invoice")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // Space for tab bar
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                fetchInvoices()
            }
        }
        .fullScreenCover(isPresented: $showCreateInvoice) {
            CreateInvoiceView(
                showSuccessAlert: $showSuccessAlert,
                confettiTrigger: $confettiTrigger
            )
        }
        .onChange(of: showCreateInvoice) { isShowing in
            if !isShowing {
                // Refresh invoices when returning from create flow
                fetchInvoices()
            }
        }
        .alert("Invoice successfully sent", isPresented: $showSuccessAlert) {
            Button("OK") {
                print("✅ Alert dismissed by user")
                // Trigger haptic when dismissing
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
        }
        .onChange(of: showSuccessAlert) { isShowing in
            if isShowing {
                print("🎉 SUCCESS ALERT IS NOW SHOWING")
            }
        }
        .confettiCannon(
            trigger: $confettiTrigger,
            num: 60,
            colors: [.red, .yellow, .blue, .green, .purple, .pink, .orange, .cyan],
            confettiSize: 6.0,
            radius: 350,
            repetitions: 1,
            repetitionInterval: 0.1
        )
        .onChange(of: confettiTrigger) { newValue in
            print("🎊 CONFETTI TRIGGERED! Value: \(newValue)")
            // Haptic feedback when confetti triggers
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
        }
        .sheet(isPresented: $showSettings) {
            ProfileSettingsView(
                profileManager: profileManager,
                songManager: songManager,
                streakManager: streakManager
            )
        }
        .fullScreenCover(item: $selectedInvoice) { invoice in
            InvoiceDetailView(
                invoice: invoice,
                showSuccessAlert: $showSuccessAlert,
                confettiTrigger: $confettiTrigger,
                dismissToMain: {
                    // Dismiss the invoice detail view
                    selectedInvoice = nil
                }
            )
        }
    }
    
    private func fetchInvoices() {
        let db = Firestore.firestore()
        db.collection("invoices")
            .order(by: "issuedDate", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Error fetching invoices: \(error.localizedDescription)")
                    self.invoices = []
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("⚠️ No invoices found in Firestore - showing empty state")
                    self.invoices = []
                    return
                }
                
                print("📄 Found \(documents.count) invoice documents in Firestore")
                print("   Document IDs: \(documents.map { $0.documentID })")
                
                // Decode all invoices
                var decodedInvoices: [Invoice] = []
                
                for doc in documents {
                    do {
                        let decoder = Firestore.Decoder()
                        let data = doc.data()
                        print("🔍 Decoding invoice: \(doc.documentID)")
                        let invoice = try decoder.decode(Invoice.self, from: data)
                        print("   ✅ Decoded: #\(invoice.number) - \(invoice.client?.name ?? "no client") - $\(invoice.total)")
                        decodedInvoices.append(invoice)
                    } catch {
                        print("❌ Error decoding invoice \(doc.documentID): \(error)")
                    }
                }
                
                // Remove duplicates based on invoice ID
                var uniqueInvoices: [Invoice] = []
                var seenIDs = Set<UUID>()
                
                for invoice in decodedInvoices {
                    if !seenIDs.contains(invoice.id) {
                        seenIDs.insert(invoice.id)
                        uniqueInvoices.append(invoice)
                    } else {
                        print("⚠️ Skipping duplicate invoice ID: \(invoice.id)")
                    }
                }
                
                // Sort by issued date (most recent first)
                self.invoices = uniqueInvoices.sorted { $0.issuedDate > $1.issuedDate }
                
                print("✅ Final invoices count: \(self.invoices.count)")
                print("   Unique invoices (sorted newest first):")
                for invoice in self.invoices {
                    print("     - #\(invoice.number) - \(invoice.client?.name ?? "no client") - \(invoice.issuedDate) - $\(String(format: "%.2f", invoice.total))")
                }
                
                if self.invoices.isEmpty {
                    print("ℹ️ No valid invoices to display - will show empty state")
                }
            }
    }
}

// MARK: - Invoice Row View
struct InvoiceRowView: View {
    let invoice: Invoice
    
    var invoiceStatus: String {
        // Check if invoice has been sent
        if invoice.status == "sent" || invoice.sentAt != nil {
            return "Sent"
        }
        // Check if invoice is paid
        if invoice.total <= invoice.receivedPayments && invoice.receivedPayments > 0 {
            return "Paid"
        }
        // Default to viewed for draft invoices
        return "Viewed"
    }
    
    var isDueSoon: Bool {
        guard case .customDate(let date) = invoice.dueDate else { return false }
        let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        return daysUntilDue >= 0 && daysUntilDue <= 7
    }
    
    var isOverdue: Bool {
        guard case .customDate(let date) = invoice.dueDate else { return false }
        let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        return daysUntilDue < 0
    }
    
    var dueText: String? {
        guard case .customDate(let date) = invoice.dueDate else { return nil }
        let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        
        if daysUntilDue < 0 {
            return "overdue \(abs(daysUntilDue))d"
        } else if daysUntilDue <= 7 {
            return "due \(daysUntilDue)d"
        }
        return nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                // Client name and invoice number
                VStack(alignment: .leading, spacing: 4) {
                    Text(invoice.client?.name ?? "No Client")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text("#\(invoice.number), \(formatDate(invoice.issuedDate))")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Amount and status
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(String(format: "%.2f", invoice.total))")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                    
                    HStack(spacing: 8) {
                        // Due status
                        if let dueText = dueText {
                            Text(dueText)
                                .font(.system(size: 13))
                                .foregroundColor(isOverdue ? .red : .gray)
                        }
                        
                        // Sent/Viewed status
                        Text(invoiceStatus)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.all, 16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Estimates View
struct EstimatesView: View {
    @State private var showCreateEstimate = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Navigation Bar
                    HStack {
                        Button(action: {
                            // Message action
                        }) {
                            Image(systemName: "message")
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                        }
                        
                        Spacer()
                        
                        Text("Estimates")
                            .font(.system(size: 34, weight: .bold))
                        
                        Spacer()
                        
                        Button(action: {
                            // Settings action
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                    
                    Spacer()
                    
                    // Empty State
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.3))
                        
                        Text("Start by creating an estimate. Send\nquotes to your clients")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    
                    Spacer()
                    
                    // Create Estimate Button
                    Button(action: {
                        showCreateEstimate = true
                    }) {
                        Text("Create estimate")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // Space for tab bar
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showCreateEstimate) {
            CreateEstimateView()
        }
    }
}

// MARK: - Clients View
struct ClientsView: View {
    @StateObject private var clientManager = ClientManager.shared
    @State private var showAddClient = false
    @State private var showImportFromContacts = false
    @State private var searchText = ""
    
    var filteredClients: [Client] {
        if searchText.isEmpty {
            return clientManager.clients
        }
        return clientManager.clients.filter { client in
            client.name.localizedCaseInsensitiveContains(searchText) ||
            (client.email?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (client.phone?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Navigation Bar
                    HStack {
                        Button(action: {
                            // Message action
                        }) {
                            Image(systemName: "message")
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                        }
                        
                        Spacer()
                        
                        Text("Clients")
                            .font(.system(size: 34, weight: .bold))
                        
                        Spacer()
                        
                        HStack(spacing: 20) {
                            Button(action: {
                                // Search action - could toggle search bar visibility
                            }) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 20))
                                    .foregroundColor(.black)
                            }
                            
                            Button(action: {
                                // Settings action
                            }) {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 20))
                                    .foregroundColor(.black)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                    
                    if clientManager.clients.isEmpty {
                        // Empty State
                        Spacer()
                        
                        VStack(spacing: 16) {
                            Image(systemName: "person.2")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.3))
                            
                            Text("Add client or import\nfrom contacts")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        
                        Spacer()
                        
                        // Import from contacts Button
                        Button(action: {
                            showImportFromContacts = true
                        }) {
                            Text("Import from contacts")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                        
                        // Add Client Button
                        Button(action: {
                            showAddClient = true
                        }) {
                            Text("Add client")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100) // Space for tab bar
                    } else {
                        VStack(spacing: 0) {
                            // Clients List
                            ScrollView {
                                VStack(spacing: 12) {
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
                                    .padding(.bottom, 8)
                                    
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
                                    
                                    // Client Cards
                                    VStack(spacing: 0) {
                                        ForEach(filteredClients) { client in
                                            NavigationLink(destination: ClientDetailView(client: client)) {
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
                                    .padding(.bottom, 80) // Extra padding for button
                                }
                                .padding(.top, 8)
                            }
                            
                            // Add Client Button (Fixed at bottom)
                            VStack {
                                Button(action: {
                                    showAddClient = true
                                }) {
                                    Text("Add client")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 56)
                                        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                                        .cornerRadius(12)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                                .padding(.bottom, 100) // Space for tab bar
                            }
                            .background(Color(UIColor.systemGroupedBackground))
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showAddClient) {
            AddClientModal(onSave: { client in
                clientManager.addClient(client)
            })
        }
        .sheet(isPresented: $showImportFromContacts) {
            // TODO: Implement contact picker
            Text("Contact picker will be implemented here")
        }
    }
}

// MARK: - Reports View
struct ReportsView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Navigation Bar
                    HStack {
                        Button(action: {
                            // Message action
                        }) {
                            Image(systemName: "message")
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                        }
                        
                        Spacer()
                        
                        Text("Reports")
                            .font(.system(size: 34, weight: .bold))
                        
                        Spacer()
                        
                        Button(action: {
                            // Settings action
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                    
                    Spacer()
                    
                    // Empty State
                    VStack(spacing: 16) {
                        Image(systemName: "chart.pie")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.3))
                        
                        Text("No reports yet. Create invoices to\nsee your business analytics")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    
                    Spacer()
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Create Estimate View (Placeholder)
struct CreateEstimateView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Create Estimate")
                    .font(.largeTitle)
                    .padding()
                
                Spacer()
                
                Text("Estimate creation form will go here")
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .navigationTitle("New Estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Client Detail View
struct ClientDetailView: View {
    let client: Client
    @StateObject private var clientManager = ClientManager.shared
    @State private var showEditClient = false
    @Environment(\.tabBarHidden) private var tabBarHidden
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        // Client Name
                        Text(client.name)
                            .font(.system(size: 34, weight: .bold))
                            .padding(.top, 20)
                            .padding(.bottom, 30)
                    
                    // Invoices Section
                    VStack(spacing: 0) {
                        HStack(spacing: 16) {
                            // Icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green.opacity(0.1))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "doc.text")
                                    .font(.system(size: 24))
                                    .foregroundColor(.green)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Invoices")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.black)
                                
                                Text("0 unpaid")
                                    .font(.system(size: 15))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                        }
                        .padding(20)
                        .background(Color.white)
                    }
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    
                    // Estimates Section
                    VStack(spacing: 0) {
                        HStack(spacing: 16) {
                            // Icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green.opacity(0.1))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.green)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Estimates")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.black)
                                
                                Text("0 total")
                                    .font(.system(size: 15))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                        }
                        .padding(20)
                        .background(Color.white)
                    }
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                    
                    // Contact Information Section
                    VStack(spacing: 0) {
                        // Email
                        if let email = client.email, !email.isEmpty {
                            HStack(spacing: 16) {
                                Image(systemName: "envelope")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray)
                                    .frame(width: 30)
                                
                                Text(email)
                                    .font(.system(size: 16))
                                    .foregroundColor(.black)
                                
                                Spacer()
                            }
                            .padding(20)
                            .background(Color.white)
                            
                            Divider()
                                .padding(.leading, 66)
                        }
                        
                        // Phone
                        if let phone = client.phone, !phone.isEmpty {
                            HStack(spacing: 16) {
                                Image(systemName: "phone")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray)
                                    .frame(width: 30)
                                
                                Text(phone)
                                    .font(.system(size: 16))
                                    .foregroundColor(.black)
                                
                                Spacer()
                            }
                            .padding(20)
                            .background(Color.white)
                            
                            Divider()
                                .padding(.leading, 66)
                        }
                        
                        // Address
                        if let address = client.address, !address.isEmpty {
                            HStack(spacing: 16) {
                                Image(systemName: "location")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray)
                                    .frame(width: 30)
                                
                                Text(address)
                                    .font(.system(size: 16))
                                    .foregroundColor(.black)
                                
                                Spacer()
                            }
                            .padding(20)
                            .background(Color.white)
                        }
                    }
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 180) // Space for the fixed buttons at bottom
                    }
                }
            }
            
            // Action Buttons (Absolutely positioned at bottom, covering tab bar)
            VStack(spacing: 12) {
                // Create Estimate Button
                Button(action: {
                    // Create estimate action
                }) {
                    Text("Create estimate")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // Create Invoice Button
                Button(action: {
                    // Create invoice action
                }) {
                    Text("Create invoice")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.black)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 34)
            .background(
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showEditClient = true
                }
                .foregroundColor(.black)
            }
        }
        .sheet(isPresented: $showEditClient) {
            EditClientModal(client: client, onSave: { updatedClient in
                clientManager.updateClient(updatedClient)
            }, onRemove: {
                clientManager.deleteClient(client)
            })
        }
        .onAppear {
            tabBarHidden.wrappedValue = true
        }
        .onDisappear {
            tabBarHidden.wrappedValue = false
        }
    }
}

// MARK: - Add Client View (Placeholder)
struct AddClientView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Add Client")
                    .font(.largeTitle)
                    .padding()
                
                Spacer()
                
                Text("Client form will go here")
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .navigationTitle("New Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

