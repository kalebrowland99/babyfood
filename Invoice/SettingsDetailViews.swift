//
//  SettingsDetailViews.swift
//  Thrifty
//
//  Detail views for each settings menu item
//

import SwiftUI

// MARK: - Personal Account View
struct PersonalAccountView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var profileManager: ProfileManager
    @State private var showingLogoutAlert = false
    
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
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 30)
            
            // Title
            Text("Personal")
                .font(.system(size: 34, weight: .bold))
                .padding(.bottom, 40)
            
            // User Info Card
            VStack(spacing: 16) {
                Text(profileManager.userName.replacingOccurrences(of: "@", with: ""))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.black)
                
                if let email = AuthenticationManager.shared.currentUser?.email {
                    Text(email)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            
            // Sync Message
            Text("All your invoices are now synced to your account. Remind yourself to log in when reinstalling the app")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            // Log out button
            Button(action: {
                showingLogoutAlert = true
            }) {
                Text("Log out")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationBarHidden(true)
        .alert("Log Out", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                AuthenticationManager.shared.logOut()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to log out?")
        }
    }
}

// MARK: - Business Information View
struct BusinessInformationView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var profileManager: ProfileManager
    @State private var businessName = "615films"
    @State private var contactName = ""
    @State private var phone = "6154786315"
    @State private var email = "kalebrowland99@gmail.com"
    @State private var address = "800 19th Ave S Nashville Tennessee"
    @State private var showingPhotoPicker = false
    
    var body: some View {
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
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 30)
                
                // Business Logo
                Button(action: { showingPhotoPicker = true }) {
                    VStack(spacing: 8) {
                        if let customImage = profileManager.customProfileImage {
                            Image(uiImage: customImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(profileManager.profilePicture)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        Text("tap to change")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                }
                .sheet(isPresented: $showingPhotoPicker) {
                    ImagePicker(image: $profileManager.customProfileImage)
                }
                .padding(.bottom, 30)
                
                // Form Fields
                VStack(alignment: .leading, spacing: 20) {
                    // Business Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Business Name")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        
                        TextField("", text: $businessName)
                            .font(.system(size: 16))
                            .padding()
                            .background(Color.white)
                            .cornerRadius(8)
                    }
                    
                    // Business Contacts
                    Text("Business Contacts")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .padding(.top, 10)
                    
                    // Name
                    HStack {
                        Text("Name")
                            .font(.system(size: 16))
                            .frame(width: 80, alignment: .leading)
                        
                        TextField("Optional", text: $contactName)
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)
                    
                    // Phone
                    HStack {
                        Text("Phone")
                            .font(.system(size: 16))
                            .frame(width: 80, alignment: .leading)
                        
                        TextField("", text: $phone)
                            .font(.system(size: 16))
                            .keyboardType(.phonePad)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)
                    
                    // E-Mail
                    HStack {
                        Text("E-Mail")
                            .font(.system(size: 16))
                            .frame(width: 80, alignment: .leading)
                        
                        TextField("", text: $email)
                            .font(.system(size: 16))
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
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
                        
                        TextField("", text: $address, axis: .vertical)
                            .font(.system(size: 16))
                            .lineLimit(2...3)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                
                // Switch Profile Button
                Button(action: {}) {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.stack.person.crop")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                        
                        Text("Switch profile")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                
                Text("More than one business? Add them here")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .padding(.bottom, 40)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationBarHidden(true)
    }
}

// MARK: - Accepting Payments View
struct AcceptingPaymentsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showingPaymentFeeModal = false
    
    var body: some View {
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
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 30)
                
                // Title
                Text("Secure Online\nPayments")
                    .font(.system(size: 34, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)
                
                // Subtitle
                Text("Only the standard Stripe processing fees + 1% platform fee.")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
                
                // Stripe Card
                VStack(spacing: 16) {
                    HStack {
                        Text("stripe")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color(red: 0.38, green: 0.44, blue: 1.0))
                        
                        Spacer()
                        
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.yellow)
                    }
                    
                    Text("Your account setup is incomplete. Additional verification information is required to enable capabilities on this account. Please finish y...")
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Button(action: {}) {
                        Text("Complete Set-Up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {}) {
                        Text("Disconnect")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                
                // Online payment fee
                Button(action: { showingPaymentFeeModal = true }) {
                    HStack(spacing: 16) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 22))
                            .foregroundColor(.black)
                            .frame(width: 28)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Online payment fee")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                            
                            Text("You cover fee")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // How it works
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Text("How it works")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                        
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationBarHidden(true)
        .sheet(isPresented: $showingPaymentFeeModal) {
            OnlinePaymentFeeModal()
        }
    }
}

// MARK: - Online Payment Fee Modal
struct OnlinePaymentFeeModal: View {
    @Environment(\.dismiss) var dismiss
    @State private var clientPaysFee = false
    
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
            Text("Online payment fee")
                .font(.system(size: 28, weight: .bold))
                .padding(.bottom, 30)
            
            // Toggle
            HStack {
                Text("Client pays fee")
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                
                Spacer()
                
                Toggle("", isOn: $clientPaysFee)
                    .labelsHidden()
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(12)
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            
            // Example Section
            VStack(alignment: .leading, spacing: 16) {
                Text("For example")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                
                Text("When a customer pays online, Stripe standard fee + 1% platform fee will be charged to you")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
                
                VStack(spacing: 12) {
                    HStack {
                        Text("Total")
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                        Spacer()
                        Text("$100")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    
                    HStack {
                        Text("Client will pay")
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                        Spacer()
                        Text("$100")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("You will receive")
                                .font(.system(size: 16))
                                .foregroundColor(.black)
                            Text("(Depends on the client'...")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text("$96–$99")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)
                
                Text("Pro tip: As a registered business, payment processing fees may be tax deductible!")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Save Button
            Button(action: { dismiss() }) {
                Text("Save")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.gray)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Payment Requests View
struct PaymentRequestsView: View {
    @Environment(\.dismiss) var dismiss
    
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
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 50)
            
            // Title
            Text("Request payments\nfrom customers")
                .font(.system(size: 34, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.bottom, 50)
            
            // Features
            VStack(spacing: 30) {
                FeatureRow(
                    icon: "link",
                    backgroundColor: Color.green.opacity(0.2),
                    text: "Create a link to get paid for an item or service"
                )
                
                FeatureRow(
                    icon: "sparkles",
                    backgroundColor: Color.blue.opacity(0.2),
                    text: "Customers can pay any way they want"
                )
                
                FeatureRow(
                    icon: "creditcard",
                    backgroundColor: Color.purple.opacity(0.2),
                    text: "Only the standard Stripe processing fees + 1% platform fee."
                )
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Request Payment Button
            Button(action: {}) {
                Text("Request payment")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color(red: 0.11, green: 0.11, blue: 0.12))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationBarHidden(true)
    }
}

struct FeatureRow: View {
    let icon: String
    let backgroundColor: Color
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.black)
                .frame(width: 50, height: 50)
                .background(backgroundColor)
                .cornerRadius(12)
            
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.black)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

// MARK: - Price Book View
struct PriceBookView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var manager = PriceBookManager.shared
    @State private var selectedFilter: PriceBookItemType? = nil
    @State private var showingAddSheet = false
    @State private var itemToEdit: PriceBookItem? = nil
    
    var filteredItems: [PriceBookItem] {
        if let filter = selectedFilter {
            return manager.items.filter { $0.type == filter }
        }
        return manager.items
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 30)
                
                // Title
                Text("Price book")
                    .font(.system(size: 34, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                
                // Category Tabs
                categoryTabs
                
                // Items List or Empty State
                if filteredItems.isEmpty {
                    emptyStateView
                } else {
                    itemsList
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            
            // Add Button
            addButton
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingAddSheet) {
            AddPriceBookItemView(itemToEdit: itemToEdit)
        }
        .onChange(of: showingAddSheet) { newValue in
            if !newValue {
                itemToEdit = nil
            }
        }
    }
    
    // MARK: - Category Tabs
    private var categoryTabs: some View {
        HStack(spacing: 0) {
            CategoryTab(
                title: "All",
                isSelected: selectedFilter == nil,
                action: { selectedFilter = nil }
            )
            
            CategoryTab(
                title: "Services",
                isSelected: selectedFilter == .service,
                action: { selectedFilter = .service }
            )
            
            CategoryTab(
                title: "Materials",
                isSelected: selectedFilter == .material,
                action: { selectedFilter = .material }
            )
            
            CategoryTab(
                title: "Other",
                isSelected: selectedFilter == .other,
                action: { selectedFilter = .other }
            )
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }
    
    // MARK: - Items List
    private var itemsList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(filteredItems) { item in
                    PriceBookItemRow(item: item, onEdit: {
                        itemToEdit = item
                        showingAddSheet = true
                    }, onDelete: {
                        manager.deleteItem(item)
                    })
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100) // Extra padding for the add button
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Add Button
    private var addButton: some View {
        Button(action: {
            itemToEdit = nil
            showingAddSheet = true
        }) {
            Text("Add new item")
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
}

// MARK: - Category Tab Component
struct CategoryTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .black : .gray)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(isSelected ? Color.white : Color.clear)
                .cornerRadius(8)
        }
    }
}

// MARK: - Price Book Item Row
struct PriceBookItemRow: View {
    let item: PriceBookItem
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        Button(action: onEdit) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if item.isTaxable {
                        Text("Taxable")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text(item.formattedPrice)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(role: .destructive, action: {
                showingDeleteAlert = true
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert("Delete Item", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("Are you sure you want to delete \"\(item.name)\"?")
        }
    }
}

