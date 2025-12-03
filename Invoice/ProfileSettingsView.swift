//
//  ProfileSettingsView.swift
//  Thrifty
//
//  Profile & Settings screen matching invoice app design
//

import SwiftUI

struct ProfileSettingsView: View {
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var songManager: SongManager
    @ObservedObject var streakManager: StreakManager
    @Environment(\.dismiss) var dismiss
    @State private var showingPhotoPicker = false
    @State private var showingSupportEmail = false
    @State private var showingCopiedFeedback = false
    @State private var showingDeleteAlert = false
    @State private var showingLogoutAlert = false
    @State private var showingPersonalAccount = false
    @State private var showingBusinessInfo = false
    @State private var showingAcceptingPayments = false
    @State private var showingPaymentRequests = false
    @State private var showingPriceBook = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Back button
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 30)
                
                // Profile Picture
                Button(action: { showingPhotoPicker = true }) {
                    ZStack(alignment: .bottomTrailing) {
                        // Photo
                        if let customImage = profileManager.customProfileImage {
                            Image(uiImage: customImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            // Default gray box with camera icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // Camera badge overlay
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 26, height: 26)
                            
                            Circle()
                                .fill(Color.black)
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "camera.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.white)
                        }
                        .offset(x: 2, y: 2)
                    }
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showingPhotoPicker) {
                    ImagePicker(image: $profileManager.customProfileImage)
                }
                .onChange(of: profileManager.customProfileImage) { _ in
                    // Auto-save when photo changes
                    profileManager.saveUserData()
                    print("✅ Profile photo auto-saved to UserDefaults")
                }
                .padding(.bottom, 12)
                
                // Username (Business Name)
                Text(UserDefaults.standard.string(forKey: "businessName") ?? "615films")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.bottom, 20)
                
                // Business Email (if available)
                if let email = UserDefaults.standard.string(forKey: "businessEmail"), !email.isEmpty {
                    Text(email)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .padding(.bottom, 20)
                } else {
                    Color.clear.frame(height: 20)
                }
                
                // Menu Items Card
                VStack(spacing: 0) {
                    SettingsMenuItem(
                        icon: "person",
                        title: "Personal account",
                        subtitle: nil,
                        action: {
                            showingPersonalAccount = true
                        }
                    )
                    
                    Divider()
                        .padding(.leading, 60)
                    
                    SettingsMenuItem(
                        icon: "building.2",
                        title: "Business information",
                        subtitle: nil,
                        action: {
                            showingBusinessInfo = true
                        }
                    )
                    
                    Divider()
                        .padding(.leading, 60)
                    
                    SettingsMenuItem(
                        icon: "creditcard",
                        title: "Accepting payments",
                        subtitle: "Activate to receive payments",
                        action: {
                            showingAcceptingPayments = true
                        }
                    )
                    
                    Divider()
                        .padding(.leading, 60)
                    
                    SettingsMenuItem(
                        icon: "dollarsign.circle",
                        title: "Payment requests",
                        subtitle: "Get paid without invoicing",
                        action: {
                            showingPaymentRequests = true
                        }
                    )
                    
                    Divider()
                        .padding(.leading, 60)
                    
                    SettingsMenuItem(
                        icon: "book",
                        title: "Price book",
                        subtitle: nil,
                        action: {
                            showingPriceBook = true
                        }
                    )
                }
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                
                // Message Button
                Button(action: {
                    showingSupportEmail = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "message")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                        
                        Text("Shoot us a message ❤️")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                
                // OLD APP BUTTONS - Added at bottom
                VStack(spacing: 0) {
                    // Support Email Section (conditional)
                    if showingSupportEmail {
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                Image(systemName: "envelope")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.black)
                                    .frame(width: 24, height: 24)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Contact Support")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.black)
                                    
                                    // Email contact
                                    Button(action: {
                                        UIPasteboard.general.string = "helpthrifty@gmail.com"
                                        showingCopiedFeedback = true
                                        
                                        // Hide the feedback after 2 seconds
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                            showingCopiedFeedback = false
                                        }
                                    }) {
                                        Text(showingCopiedFeedback ? "Copied!" : "helpthrifty@gmail.com")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(showingCopiedFeedback ? .green : .blue)
                                            .animation(.easeInOut(duration: 0.2), value: showingCopiedFeedback)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    showingSupportEmail = false
                                    showingCopiedFeedback = false
                                }) {
                                    Text("Hide")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.black.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.blue.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    
                    // Menu Items Group (from old app)
                    VStack(spacing: 0) {
                        // Support
                        OldProfileMenuItem(
                            icon: "envelope",
                            title: "Support",
                            showChevron: false,
                            action: {
                                showingSupportEmail = true
                                showingCopiedFeedback = false
                            }
                        )
                        
                        // Divider
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 0.5)
                            .padding(.leading, 68)
                        
                        // Log Out
                        OldProfileMenuItem(
                            icon: "rectangle.portrait.and.arrow.right",
                            title: "Log Out",
                            showChevron: false,
                            action: {
                                showingLogoutAlert = true
                            }
                        )
                        
                        // Divider
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 0.5)
                            .padding(.leading, 68)
                        
                        // Delete Account
                        OldProfileMenuItem(
                            icon: "xmark",
                            title: "Delete Account",
                            showChevron: false,
                            isDestructive: true,
                            action: {
                                showingDeleteAlert = true
                            }
                        )
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.gray.opacity(0.12), lineWidth: 0.5)
                            )
                    )
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 30)
                
                // Privacy & Terms Links
                HStack(spacing: 4) {
                    Button(action: {}) {
                        Text("privacy policy")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                    
                    Text("and")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    
                    Button(action: {}) {
                        Text("terms of use")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 40)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationBarHidden(true)
        .alert("Delete Account", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone. All your data will be permanently deleted.")
        }
        .alert("Log Out", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                logOut()
            }
        } message: {
            Text("Are you sure you want to log out? Your data will be saved.")
        }
        .sheet(isPresented: $showingPersonalAccount) {
            PersonalAccountView(profileManager: profileManager)
        }
        .sheet(isPresented: $showingBusinessInfo) {
            BusinessSettingsView()
        }
        .sheet(isPresented: $showingAcceptingPayments) {
            AcceptingPaymentsView()
        }
        .sheet(isPresented: $showingPaymentRequests) {
            PaymentRequestsView()
        }
        .sheet(isPresented: $showingPriceBook) {
            PriceBookView()
        }
    }
    
    private func deleteAccount() {
        // Clear all user data
        profileManager.customProfileImage = nil
        
        // Clear business info
        UserDefaults.standard.removeObject(forKey: "businessName")
        UserDefaults.standard.removeObject(forKey: "businessEmail")
        UserDefaults.standard.removeObject(forKey: "businessPhone")
        UserDefaults.standard.removeObject(forKey: "businessAddress")
        
        // Clear streak data
        streakManager.writingDays.removeAll()
        streakManager.currentStreak = 0
        streakManager.debugDayOffset = 0
        streakManager.isDebugSkipActive = false
        
        // Clear UserDefaults
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "ProfileManager_UserName")
        defaults.removeObject(forKey: "ProfileManager_ProfilePicture")
        defaults.removeObject(forKey: "ProfileManager_TotalWords")
        defaults.removeObject(forKey: "ProfileManager_CustomImage")
        defaults.removeObject(forKey: "SavedSongs")
        defaults.removeObject(forKey: "StreakManager_WritingDays")
        defaults.removeObject(forKey: "StreakManager_DebugOffset")
        defaults.removeObject(forKey: "StreakManager_LastAppOpen")
        defaults.removeObject(forKey: "ToolResponses")
        
        // Save the reset profile state
        profileManager.saveUserData()
        streakManager.saveData()
        
        print("🗑️ Account deleted - all user data cleared")
        
        // Log out the user after account deletion
        AuthenticationManager.shared.logOut()
        
        print("🚪 User logged out after account deletion - redirecting to sign in")
        dismiss()
    }
    
    private func logOut() {
        // Log out through authentication manager
        AuthenticationManager.shared.logOut()
        
        print("🚪 User logged out - redirecting to sign in")
        dismiss()
    }
}

// MARK: - Settings Menu Item
struct SettingsMenuItem: View {
    let icon: String
    let title: String
    let subtitle: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.black)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Old Profile Menu Item (from previous app)
struct OldProfileMenuItem: View {
    let icon: String
    let title: String
    let showChevron: Bool
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isDestructive ? .red : .black)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDestructive ? .red : .black)
                
                Spacer()
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black.opacity(0.3))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

