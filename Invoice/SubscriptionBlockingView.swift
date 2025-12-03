//
//  SubscriptionBlockingView.swift
//  Thrifty
//
//  Blocking paywall shown when subscription is canceled or payment failed
//

import SwiftUI
import SafariServices

struct SubscriptionBlockingView: View {
    @ObservedObject var blockingManager: SubscriptionBlockingManager
    @State private var isLoadingPortal = false
    @State private var showSafari = false
    @State private var portalURL: URL?
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Icon based on reason
                iconView
                
                // Title
                Text(blockingManager.blockingReason.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Message
                Text(blockingManager.blockingReason.message)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                // Payment error details if available
                if let error = blockingManager.lastPaymentError {
                    VStack(spacing: 8) {
                        Text("Error Details:")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.red.opacity(0.9))
                        
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.red.opacity(0.7))
                            .padding(.horizontal, 24)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    // Update payment button (if payment failed)
                    if blockingManager.blockingReason.canUpdatePayment {
                        Button(action: {
                            openCustomerPortal()
                        }) {
                            if isLoadingPortal {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                            } else {
                                HStack {
                                    Image(systemName: "creditcard")
                                    Text("Update Payment Method")
                                }
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                        }
                        .disabled(isLoadingPortal)
                    } else {
                        // Resubscribe button
                        NavigationLink(destination: SubscriptionView()) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Reactivate Subscription")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                    }
                    
                    // Contact support
                    Button(action: {
                        openSupport()
                    }) {
                        HStack {
                            Image(systemName: "envelope")
                            Text("Contact Support")
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showSafari) {
            if let url = portalURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Force check when view appears
            blockingManager.forceCheck()
        }
    }
    
    private var iconView: some View {
        Group {
            switch blockingManager.blockingReason {
            case .paymentFailed, .unpaid:
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                }
                
            case .canceled:
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                }
                
            case .expired, .incompleteExpired:
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "clock.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.yellow)
                }
                
            case .none:
                EmptyView()
            }
        }
    }
    
    private func openCustomerPortal() {
        isLoadingPortal = true
        
        Task {
            do {
                let urlString = try await blockingManager.createCustomerPortalSession()
                
                guard let url = URL(string: urlString) else {
                    throw NSError(domain: "InvalidURL", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Invalid portal URL"
                    ])
                }
                
                await MainActor.run {
                    portalURL = url
                    showSafari = true
                    isLoadingPortal = false
                }
                
                // Check status after a delay
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                await blockingManager.checkSubscriptionStatus()
                
            } catch {
                await MainActor.run {
                    isLoadingPortal = false
                    errorMessage = "Failed to open payment portal: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func openSupport() {
        let email = "support@thriftyapp.com"
        let subject = "Subscription Issue - \(blockingManager.blockingReason.title)"
        let body = "Please describe your issue:\n\n\nSubscription Status: \(blockingManager.subscriptionStatus)"
        
        let urlString = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

// Safari View for Customer Portal
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safari = SFSafariViewController(url: url)
        safari.preferredControlTintColor = .systemBlue
        return safari
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
}

// Preview
struct SubscriptionBlockingView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionBlockingView(blockingManager: SubscriptionBlockingManager.shared)
    }
}

