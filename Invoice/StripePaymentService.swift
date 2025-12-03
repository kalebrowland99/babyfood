//
//  StripePaymentService.swift
//  Thrifty
//
//  Native Stripe payment processing service
//

import Foundation
import UIKit
import StripePaymentSheet

@MainActor
class StripePaymentService: ObservableObject {
    static let shared = StripePaymentService()
    
    @Published var paymentSheet: PaymentSheet?
    @Published var isLoading = false
    
    private init() {}
    
    // Create payment sheet configuration from Firebase
    func createPaymentSheet(
        userId: String?,
        userEmail: String,
        isWinback: Bool = false,
        useProductionMode: Bool = false
    ) async throws -> PaymentSheet {
        
        isLoading = true
        defer { isLoading = false }
        
        print("📱 Creating native Stripe PaymentSheet...")
        print("📧 Email: \(userEmail)")
        print("🔧 Mode: \(useProductionMode ? "PRODUCTION ⚠️" : "TEST ✅")")
        
        let functionUrl = "https://us-central1-thrift-882cb.cloudfunctions.net/createStripePaymentSheet"
        
        guard let url = URL(string: functionUrl) else {
            throw NSError(domain: "InvalidURL", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid function URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add User-Agent for Meta CAPI tracking
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let osVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model
        let userAgent = "Thrifty/\(appVersion) (iOS \(osVersion); \(deviceModel))"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        // Request body
        struct RequestBody: Codable {
            let userId: String?
            let userEmail: String
            let isWinback: Bool
            let useProductionMode: Bool
        }
        
        let requestBody = RequestBody(
            userId: userId,
            userEmail: userEmail,
            isWinback: isWinback,
            useProductionMode: useProductionMode
        )
        
        request.httpBody = try? JSONEncoder().encode(requestBody)
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "HTTPError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ HTTP Error \(httpResponse.statusCode): \(errorMessage)")
            throw NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error: \(errorMessage)"])
        }
        
        // Parse response
        struct StripeResponse: Codable {
            let success: Bool
            let setupIntent: String
            let publishableKey: String
            let priceId: String
            let mode: String
            let message: String
        }
        
        let stripeResponse = try JSONDecoder().decode(StripeResponse.self, from: data)
        
        guard stripeResponse.success else {
            throw NSError(domain: "StripeError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create payment sheet"])
        }
        
        print("✅ PaymentSheet configuration received")
        print("📋 Price ID: \(stripeResponse.priceId)")
        print("🔧 Mode: \(stripeResponse.mode)")
        
        // Configure Stripe with publishable key
        STPAPIClient.shared.publishableKey = stripeResponse.publishableKey
        
        // Create PaymentSheet configuration (no customer - simpler flow)
        var configuration = PaymentSheet.Configuration()
        configuration.merchantDisplayName = "Thrifty: Scan & Flip Items"
        
        // Enable 3D Secure for additional authentication and reduced fraud declines
        configuration.allowsDelayedPaymentMethods = true
        
        // Only allow card and Apple Pay
        configuration.returnURL = "thriftyapp://stripe-return"
        
        // Enable Apple Pay (automatically provides billing info from Apple Wallet)
        configuration.applePay = .init(
            merchantId: "merchant.com.thrifty.thrifty",
            merchantCountryCode: "US"
        )
        
        // Customize primary button label for trial
        configuration.primaryButtonLabel = "Start Free Trial"
        
        // Collect complete billing information for AVS (Address Verification Service)
        // This significantly reduces card declines by enabling bank verification checks
        configuration.billingDetailsCollectionConfiguration.name = .always          // Cardholder name
        configuration.billingDetailsCollectionConfiguration.address = .full         // Full address + ZIP for AVS
        configuration.billingDetailsCollectionConfiguration.phone = .automatic      // Phone when payment method requires it
        configuration.billingDetailsCollectionConfiguration.email = .never          // Already pre-filled below
        configuration.billingDetailsCollectionConfiguration.attachDefaultsToPaymentMethod = true  // CRITICAL: Send to banks
        
        // Pre-fill email to reduce friction
        configuration.defaultBillingDetails.email = userEmail
        
        // Customize appearance
        var appearance = PaymentSheet.Appearance()
        appearance.cornerRadius = 12
        appearance.primaryButton.backgroundColor = UIColor(red: 0, green: 0.478, blue: 1, alpha: 1) // iOS blue
        configuration.appearance = appearance
        
        // Create PaymentSheet with SetupIntent (for subscriptions with trials)
        let paymentSheet = PaymentSheet(
            setupIntentClientSecret: stripeResponse.setupIntent,
            configuration: configuration
        )
        
        self.paymentSheet = paymentSheet
        
        // Store price ID for webhook to create subscription after setup completes
        UserDefaults.standard.set(stripeResponse.priceId, forKey: "pendingStripePriceId")
        UserDefaults.standard.set(Date(), forKey: "stripePaymentSheetOpenedTime")
        
        return paymentSheet
    }
    
    // Present payment sheet
    func presentPaymentSheet(
        from viewController: UIViewController,
        completion: @escaping (PaymentSheetResult) -> Void
    ) {
        guard let paymentSheet = paymentSheet else {
            print("❌ No payment sheet available")
            completion(.failed(error: NSError(domain: "StripeError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Payment sheet not initialized"])))
            return
        }
        
        // Find the topmost view controller
        var topController = viewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        print("📱 Presenting native Stripe PaymentSheet from topmost view controller...")
        
        // Small delay to ensure view hierarchy is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            paymentSheet.present(from: topController, completion: completion)
        }
    }
}

// Helper to get the root view controller
extension UIApplication {
    var keyWindow: UIWindow? {
        return UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .first(where: { $0 is UIWindowScene })
            .flatMap({ $0 as? UIWindowScene })?.windows
            .first(where: \.isKeyWindow)
    }
    
    var rootViewController: UIViewController? {
        return keyWindow?.rootViewController
    }
}

