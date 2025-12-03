//
//  SubscriptionBlockingManager.swift
//  Thrifty
//
//  Manages subscription status and blocks app access when needed
//

import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseFunctions

@MainActor
class SubscriptionBlockingManager: ObservableObject {
    static let shared = SubscriptionBlockingManager()
    
    @Published var isBlocked: Bool = false
    @Published var blockingReason: BlockingReason = .none
    @Published var subscriptionStatus: String = ""
    @Published var showBlockingPaywall: Bool = false
    
    // Payment failure details
    @Published var lastPaymentError: String?
    @Published var needsPaymentUpdate: Bool = false
    
    private var checkTimer: Timer?
    
    enum BlockingReason {
        case none
        case canceled
        case paymentFailed
        case expired
        case incompleteExpired
        case unpaid
        
        var title: String {
            switch self {
            case .none:
                return ""
            case .canceled:
                return "Subscription Canceled"
            case .paymentFailed:
                return "Payment Failed"
            case .expired:
                return "Subscription Expired"
            case .incompleteExpired:
                return "Payment Not Completed"
            case .unpaid:
                return "Payment Required"
            }
        }
        
        var message: String {
            switch self {
            case .none:
                return ""
            case .canceled:
                return "Your subscription has been canceled. Please reactivate to continue using premium features."
            case .paymentFailed:
                return "We couldn't process your payment. Please update your payment method to continue."
            case .expired:
                return "Your subscription has expired. Renew now to regain access to premium features."
            case .incompleteExpired:
                return "Your payment wasn't completed. Please try again to activate your subscription."
            case .unpaid:
                return "Your payment is overdue. Update your payment method to restore access."
            }
        }
        
        var canUpdatePayment: Bool {
            switch self {
            case .paymentFailed, .unpaid:
                return true
            default:
                return false
            }
        }
    }
    
    private init() {
        // Start periodic checks
        startPeriodicChecks()
    }
    
    // Check subscription status from Firestore
    func checkSubscriptionStatus() async {
        guard let userId = AuthenticationManager.shared.currentUser?.id else {
            print("⚠️ No user ID for subscription check")
            isBlocked = false
            return
        }
        
        print("🔍 Checking subscription blocking status for user: \(userId)")
        
        do {
            let db = Firestore.firestore()
            let userDoc = try await db.collection("users").document(userId).getDocument()
            
            guard let data = userDoc.data() else {
                print("ℹ️ No user document found")
                isBlocked = false
                return
            }
            
            let isPremium = data["isPremium"] as? Bool ?? false
            let status = data["subscriptionStatus"] as? String ?? ""
            let cancelAtPeriodEnd = data["cancelAtPeriodEnd"] as? Bool ?? false
            let paymentError = data["lastPaymentError"] as? String
            
            subscriptionStatus = status
            lastPaymentError = paymentError
            
            print("📊 Subscription check:")
            print("   isPremium: \(isPremium)")
            print("   status: \(status)")
            print("   cancelAtPeriodEnd: \(cancelAtPeriodEnd)")
            print("   paymentError: \(paymentError ?? "none")")
            
            // Determine if user should be blocked
            let shouldBlock = determineBlockingStatus(
                isPremium: isPremium,
                status: status,
                cancelAtPeriodEnd: cancelAtPeriodEnd,
                paymentError: paymentError
            )
            
            if shouldBlock != isBlocked || blockingReason.title != "" {
                isBlocked = shouldBlock
                showBlockingPaywall = shouldBlock
                print(isBlocked ? "🚫 USER BLOCKED: \(blockingReason.title)" : "✅ User has access")
            }
            
        } catch {
            print("❌ Error checking subscription status: \(error.localizedDescription)")
            // Don't block on error - graceful degradation
            isBlocked = false
        }
    }
    
    private func determineBlockingStatus(
        isPremium: Bool,
        status: String,
        cancelAtPeriodEnd: Bool,
        paymentError: String?
    ) -> Bool {
        // Active statuses that should have access
        let activeStatuses = ["active", "trialing", "paused"]
        
        // Check various blocking conditions
        if status == "canceled" {
            blockingReason = .canceled
            needsPaymentUpdate = false
            return true
        }
        
        if status == "incomplete_expired" {
            blockingReason = .incompleteExpired
            needsPaymentUpdate = true
            return true
        }
        
        if status == "past_due" || status == "unpaid" {
            blockingReason = .unpaid
            needsPaymentUpdate = true
            return true
        }
        
        // Payment failed but subscription still active (grace period)
        if paymentError != nil && !activeStatuses.contains(status) {
            blockingReason = .paymentFailed
            needsPaymentUpdate = true
            return true
        }
        
        // Subscription canceled and period ended
        if !isPremium && (status.isEmpty || !activeStatuses.contains(status)) {
            blockingReason = .expired
            needsPaymentUpdate = false
            return true
        }
        
        // Has active subscription
        if isPremium && activeStatuses.contains(status) {
            blockingReason = .none
            needsPaymentUpdate = false
            return false
        }
        
        // Default: don't block
        blockingReason = .none
        needsPaymentUpdate = false
        return false
    }
    
    // Start periodic subscription checks
    private func startPeriodicChecks() {
        // Check every 60 seconds
        checkTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkSubscriptionStatus()
            }
        }
    }
    
    // Force immediate check
    func forceCheck() {
        Task {
            await checkSubscriptionStatus()
        }
    }
    
    // Create Stripe Customer Portal session for payment updates
    func createCustomerPortalSession() async throws -> String {
        guard let userId = AuthenticationManager.shared.currentUser?.id else {
            throw NSError(domain: "SubscriptionError", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "User not logged in"
            ])
        }
        
        print("🔗 Creating Stripe Customer Portal session...")
        
        let functions = Functions.functions()
        let result = try await functions.httpsCallable("createCustomerPortalSession").call([
            "userId": userId
        ])
        
        guard let data = result.data as? [String: Any],
              let url = data["url"] as? String else {
            throw NSError(domain: "SubscriptionError", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create portal session"
            ])
        }
        
        print("✅ Customer Portal URL created")
        return url
    }
    
    deinit {
        checkTimer?.invalidate()
    }
}

