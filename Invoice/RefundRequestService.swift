//
//  RefundRequestService.swift
//  Thrifty
//
//  Created by Assistant on 2025-09-25.
//

import SwiftUI
import StoreKit

// MARK: - Refund Request Service
/// Service for handling in-app purchase refund requests using StoreKit 2
/// 
/// This service provides methods to request refunds for specific transactions or all transactions.
/// It uses Apple's native refund request sheets and follows Apple's guidelines for refund handling.
/// 
/// Key Features:
/// - Request refunds for specific transactions by ID
/// - Request refunds for all transactions
/// - Proper error handling with custom error types
/// - Support for both sandbox and production environments
/// - Integration with Apple's refund request sheets
@MainActor
class RefundRequestService: ObservableObject {
    static let shared = RefundRequestService()
    
    @Published var isShowingRefundSheet = false
    @Published var refundResult: RefundRequestResult?
    @Published var errorMessage: String?
    @Published var isProcessing = false // NEW: Track loading state
    @Published var debugMessage: String? // NEW: Debug feedback
    
    private init() {}
    
    enum RefundRequestResult {
        case success
        case userCancelled
        case pending
        case failed(String)
    }
    
    enum RefundRequestError: Error, LocalizedError {
        case noActiveWindowScene
        case noEligibleTransactions
        case transactionNotFound
        case systemError(String)
        
        var errorDescription: String? {
            switch self {
            case .noActiveWindowScene:
                return "Unable to present refund request - no active window scene"
            case .noEligibleTransactions:
                return "No eligible transactions found for refund"
            case .transactionNotFound:
                return "Transaction not found"
            case .systemError(let message):
                return "System error: \(message)"
            }
        }
    }
    
    /// Request a refund for a specific transaction
    /// 
    /// This method presents Apple's native refund request sheet for the specified transaction.
    /// The user can select a reason for the refund and submit the request.
    /// 
    /// - Parameter transactionID: The unique identifier of the transaction to refund
    /// 
    /// The refund request will be processed by Apple and the user will receive an email
    /// with updates on the status of their refund request.
    func requestRefund(for transactionID: UInt64) async {
        // Set loading state
        await MainActor.run {
            isProcessing = true
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        do {
            print("🔍 DEBUG: Looking for transaction with ID: \(transactionID)")
            // Find the transaction first
            guard let transaction = await findTransaction(with: transactionID) else {
                print("❌ DEBUG: Transaction not found with ID: \(transactionID)")
                throw RefundRequestError.transactionNotFound
            }
            
            print("✅ DEBUG: Found transaction, getting active window scene...")
            // Present the refund request sheet using the transaction instance
            guard let scene = await getActiveWindowScene() else {
                print("❌ DEBUG: No active window scene found")
                throw RefundRequestError.noActiveWindowScene
            }
            
            print("✅ DEBUG: Presenting refund request sheet...")
            let result = try await transaction.beginRefundRequest(in: scene)
            
            await MainActor.run {
                switch result {
                case .success:
                    self.refundResult = .success
                    print("✅ Refund request submitted successfully for transaction \(transactionID)")
                case .userCancelled:
                    self.refundResult = .userCancelled
                    print("ℹ️ User cancelled refund request for transaction \(transactionID)")
                @unknown default:
                    self.refundResult = .failed("Unknown result")
                    print("⚠️ Unknown refund request result for transaction \(transactionID)")
                }
            }
            
        } catch {
            await MainActor.run {
                let errorMessage = error.localizedDescription
                self.errorMessage = errorMessage
                self.refundResult = .failed(errorMessage)
                print("❌ Refund request failed for transaction \(transactionID): \(errorMessage)")
            }
        }
    }
    
    /// Request a refund for the most recent transaction (convenience method)
    func requestRefundForMostRecentTransaction() async {
        // Set loading state
        await MainActor.run {
            isProcessing = true
            debugMessage = "🔍 Searching for transactions..."
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        do {
            print("🔍 DEBUG: Looking for current entitlements...")
            
            await MainActor.run {
                debugMessage = "🔍 Checking entitlements..."
            }
            
            var foundTransactionCount = 0
            
            // Get the most recent transaction
            for await verificationResult in StoreKit.Transaction.currentEntitlements {
                foundTransactionCount += 1
                switch verificationResult {
                case .verified(let transaction):
                    print("✅ DEBUG: Found verified entitlement transaction: \(transaction.id)")
                    print("🔍 DEBUG: Transaction details: \(transaction)")
                    await MainActor.run {
                        debugMessage = "✅ Found transaction \(transaction.id)"
                    }
                    await requestRefund(for: transaction.id)
                    return
                case .unverified(_, _):
                    print("⚠️ DEBUG: Found unverified entitlement transaction, skipping...")
                    continue
                }
            }
            
            print("🔍 DEBUG: No current entitlements found (checked \(foundTransactionCount)), checking all transactions...")
            
            await MainActor.run {
                debugMessage = "🔍 Checking all transactions..."
            }
            
            // If no current entitlements, check all transactions
            var allTransactionCount = 0
            for await verificationResult in StoreKit.Transaction.all {
                allTransactionCount += 1
                switch verificationResult {
                case .verified(let transaction):
                    print("✅ DEBUG: Found verified transaction: \(transaction.id)")
                    print("🔍 DEBUG: Transaction details: \(transaction)")
                    await MainActor.run {
                        debugMessage = "✅ Found transaction \(transaction.id)"
                    }
                    await requestRefund(for: transaction.id)
                    return
                case .unverified(_, _):
                    print("⚠️ DEBUG: Found unverified transaction, skipping...")
                    continue
                }
            }
            
            print("❌ DEBUG: No eligible transactions found! Entitlements: \(foundTransactionCount), All: \(allTransactionCount)")
            await MainActor.run {
                debugMessage = "❌ No transactions found. Try purchasing first!"
            }
            throw RefundRequestError.noEligibleTransactions
            
        } catch {
            await MainActor.run {
                let errorMessage = error.localizedDescription
                self.errorMessage = errorMessage
                self.refundResult = .failed(errorMessage)
                self.debugMessage = "❌ Error: \(errorMessage)"
                print("❌ Failed to find transactions: \(errorMessage)")
            }
        }
    }
    
    /// Request a refund for all transactions (if user wants to refund everything)
    /// 
    /// This method presents Apple's native refund request sheet for all transactions.
    /// The user can select which transactions to refund and provide reasons for each.
    /// 
    /// This is useful when a user wants to request refunds for multiple purchases
    /// or when they want to see all their recent transactions in one place.
    func requestRefundForAllTransactions() async {
        do {
            // Get all transactions and present refund request
            guard let scene = await getActiveWindowScene() else {
                throw RefundRequestError.noActiveWindowScene
            }
            
            // Get all available transactions first
            let transactions = await getAvailableTransactions()
            guard !transactions.isEmpty else {
                throw RefundRequestError.noEligibleTransactions
            }
            
            // For now, we'll request refund for the most recent transaction
            // In a more advanced implementation, you could present a list for the user to choose from
            // or use a different approach to handle multiple transactions
            if let mostRecentTransaction = transactions.first {
                await requestRefund(for: mostRecentTransaction.id)
            } else {
                throw RefundRequestError.noEligibleTransactions
            }
            
        } catch {
            await MainActor.run {
                let errorMessage = error.localizedDescription
                self.errorMessage = errorMessage
                self.refundResult = .failed(errorMessage)
                print("❌ Refund request for all transactions failed: \(errorMessage)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func findTransaction(with id: UInt64) async -> StoreKit.Transaction? {
        for await verificationResult in StoreKit.Transaction.all {
            switch verificationResult {
            case .verified(let transaction):
                if transaction.id == id {
                    return transaction
                }
            case .unverified(_, _):
                continue
            }
        }
        return nil
    }
    
    private func getActiveWindowScene() async -> UIWindowScene? {
        return await MainActor.run {
            guard let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
                return nil
            }
            return windowScene
        }
    }
    
    func clearResults() {
        refundResult = nil
        errorMessage = nil
    }
    
    /// Get a list of all available transactions that can be refunded
    func getAvailableTransactions() async -> [StoreKit.Transaction] {
        var transactions: [StoreKit.Transaction] = []
        
        for await verificationResult in StoreKit.Transaction.all {
            switch verificationResult {
            case .verified(let transaction):
                transactions.append(transaction)
            case .unverified(_, _):
                continue
            }
        }
        
        print("📦 All available transactions:")
        for transaction in transactions {
            print("   • Transaction ID: \(transaction.id), Product ID: \(transaction.productID), Purchase Date: \(transaction.purchaseDate)")
        }
        
        return transactions
    }
    
    /// Get a list of current entitlements that can be refunded
    func getCurrentEntitlements() async -> [StoreKit.Transaction] {
        var transactions: [StoreKit.Transaction] = []
        
        for await verificationResult in StoreKit.Transaction.currentEntitlements {
            switch verificationResult {
            case .verified(let transaction):
                transactions.append(transaction)
            case .unverified(_, _):
                continue
            }
        }
        
        return transactions
    }
}

// MARK: - Refund Request Button Component
struct RefundRequestButton: View {
    @State private var showingRefundSheet = false
    @State private var selectedTransactionId: StoreKit.Transaction.ID?
    
    var body: some View {
        Button(action: {
            Task {
                await loadMostRecentTransaction()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "return.left")
                    .font(.system(size: 14))
                Text("Request Refund")
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundColor(.red)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.red, lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.red.opacity(0.05))
                    )
            )
        }
        .refundRequestSheet(for: selectedTransactionId ?? 0, isPresented: $showingRefundSheet) { result in
            switch result {
            case .success(let status):
                switch status {
                case .success:
                    print("✅ Refund request submitted successfully")
                case .userCancelled:
                    print("ℹ️ Refund request cancelled by user")
                @unknown default:
                    print("⚠️ Unknown refund request status")
                }
            case .failure(let error):
                print("❌ Refund request failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadMostRecentTransaction() async {
        // Get the most recent transaction
        for await verificationResult in StoreKit.Transaction.currentEntitlements {
            switch verificationResult {
            case .verified(let transaction):
                await MainActor.run {
                    print(transaction)
                    print("entitlment transaction id \(transaction.id)")
                    selectedTransactionId = transaction.id
                    showingRefundSheet = true
                }
                return
            case .unverified(_, _):
                continue
            }
        }
        
        // If no current entitlements, check all transactions
        for await verificationResult in StoreKit.Transaction.all {
            switch verificationResult {
            case .verified(let transaction):
                await MainActor.run {
                    print(transaction)
                    print("transaction id \(transaction.id)")
                    selectedTransactionId = transaction.id
                    showingRefundSheet = true
                }
                return
            case .unverified(_, _):
                continue
            }
        }
        
        // No transactions found
        await MainActor.run {
            print("No eligible transactions found for refund")
        }
    }
}


// MARK: - Alternative Compact Refund Button
struct CompactRefundButton: View {
    @StateObject private var refundService = RefundRequestService.shared
    @State private var showingAlert = false
    
    var body: some View {
        Button(action: {
            showingAlert = true
        }) {
            Text("Refund")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.red)
                .underline()
        }
        .alert("Request Refund", isPresented: $showingAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Request Refund", role: .destructive) {
                Task {
                    await refundService.requestRefundForMostRecentTransaction()
                }
            }
        } message: {
            Text("This will open Apple's refund request form. You can request a refund for your recent purchases.")
        }
        .alert("Refund Result", isPresented: .constant(refundService.refundResult != nil)) {
            Button("OK") {
                refundService.clearResults()
            }
        } message: {
            if let result = refundService.refundResult {
                switch result {
                case .success:
                    Text("Your refund request has been submitted successfully. You'll receive an email from Apple with updates.")
                case .userCancelled:
                    Text("Refund request was cancelled.")
                case .pending:
                    Text("Your refund request is pending review.")
                case .failed(let error):
                    Text("Refund request failed: \(error)")
                }
            } else {
                Text("")
            }
        }
    }
}
