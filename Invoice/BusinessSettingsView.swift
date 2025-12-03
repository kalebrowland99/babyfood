//
//  BusinessSettingsView.swift
//  Invoice
//
//  Business information settings
//

import SwiftUI

struct BusinessSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var profileManager = ProfileManager.shared
    @State private var businessName: String
    @State private var businessEmail: String
    @State private var businessPhone: String
    @State private var businessAddress: String
    @State private var showingPhotoPicker = false
    
    init() {
        // Load saved values or use defaults
        _businessName = State(initialValue: UserDefaults.standard.string(forKey: "businessName") ?? "615films")
        _businessEmail = State(initialValue: UserDefaults.standard.string(forKey: "businessEmail") ?? "")
        _businessPhone = State(initialValue: UserDefaults.standard.string(forKey: "businessPhone") ?? "")
        _businessAddress = State(initialValue: UserDefaults.standard.string(forKey: "businessAddress") ?? "")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Business Information")
                            .font(.system(size: 24, weight: .bold))
                        
                        Text("This information will appear on all your invoices")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    
                    // Business Logo/Photo
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Business Logo")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                        
                        Button(action: {
                            showingPhotoPicker = true
                        }) {
                            HStack {
                                Spacer()
                                
                                ZStack(alignment: .bottomTrailing) {
                                    // Photo
                                    if let customImage = profileManager.customProfileImage {
                                        Image(uiImage: customImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 120, height: 120)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    } else {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(width: 120, height: 120)
                                            
                                            VStack(spacing: 8) {
                                                Image(systemName: "camera.fill")
                                                    .font(.system(size: 30))
                                                    .foregroundColor(.gray)
                                                Text("Add Logo")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                    
                                    // Camera badge
                                    ZStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 32, height: 32)
                                        Circle()
                                            .fill(Color.black)
                                            .frame(width: 30, height: 30)
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 13))
                                            .foregroundColor(.white)
                                    }
                                    .offset(x: 4, y: 4)
                                }
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showingPhotoPicker) {
                            ImagePicker(image: $profileManager.customProfileImage)
                        }
                        .onChange(of: profileManager.customProfileImage) { _ in
                            // Auto-save when photo changes
                            profileManager.saveUserData()
                            print("✅ Business logo auto-saved to UserDefaults")
                        }
                    }
                    
                    // Business Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Business Name")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "building.2")
                                    .foregroundColor(.gray)
                                TextField("Your Business Name", text: $businessName)
                                    .font(.system(size: 17))
                            }
                            .padding(16)
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                    
                    // Business Email
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.gray)
                                ZStack(alignment: .leading) {
                                    if businessEmail.isEmpty {
                                        Text("invoices@yourbusiness.com")
                                            .font(.system(size: 17))
                                            .foregroundColor(.gray.opacity(0.5))
                                    }
                                    TextField("", text: $businessEmail)
                                        .font(.system(size: 17))
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .tint(.black)
                                }
                            }
                            .padding(16)
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                    
                    // Business Phone
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Phone")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "phone")
                                    .foregroundColor(.gray)
                                TextField("(555) 123-4567", text: $businessPhone)
                                    .font(.system(size: 17))
                                    .keyboardType(.phonePad)
                            }
                            .padding(16)
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                    
                    // Business Address
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Address")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            HStack(alignment: .top) {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(.gray)
                                    .padding(.top, 4)
                                TextField("123 Main St, City, State 12345", text: $businessAddress, axis: .vertical)
                                    .font(.system(size: 17))
                                    .lineLimit(3...6)
                            }
                            .padding(16)
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                    
                    // Info box
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("How this works")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        
                        Text("This information will be automatically included in all new invoices you create. It will appear in both the PDF and email sent to your clients.")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(16)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveBusinessInfo()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                }
            }
        }
    }
    
    private func saveBusinessInfo() {
        UserDefaults.standard.set(businessName, forKey: "businessName")
        UserDefaults.standard.set(businessEmail, forKey: "businessEmail")
        UserDefaults.standard.set(businessPhone, forKey: "businessPhone")
        UserDefaults.standard.set(businessAddress, forKey: "businessAddress")
        
        // Save the profile image as well
        profileManager.saveUserData()
        
        print("✅ Business information saved:")
        print("   Name: \(businessName)")
        print("   Email: \(businessEmail)")
        print("   Phone: \(businessPhone)")
        print("   Address: \(businessAddress)")
        print("   Logo: \(profileManager.customProfileImage != nil ? "Set" : "Not set")")
    }
}

#Preview {
    BusinessSettingsView()
}

