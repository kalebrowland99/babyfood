//
//  TransactionUsageTracker.swift
//  Thrifty
//
//  Logs current StoreKit entitlements to Firestore when a user signs in.
//

import Foundation
import StoreKit
import FirebaseFirestore
import FirebaseAuth
import RevenueCat

@MainActor
final class TransactionUsageTracker {
    static let shared = TransactionUsageTracker()

    private var authListenerHandle: AuthStateDidChangeListenerHandle?
    private var sessionStartTime: Date?
    private var recordedSeachedByImage = false

    private init() {
        setupAuthStateListener()
    }

    // MARK: - Live updates

    private var updatesTask: Task<Void, Never>? = nil

    /// Starts listening to StoreKit transaction updates and writes verified ones.
    func startListeningToTransactionUpdates() {
        // Avoid starting multiple listeners
        if updatesTask != nil { return }

        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { break }
                switch result {
                case .verified(let transaction):
                    await self.writeTransaction(transaction: transaction)
                case .unverified(let transaction, let error):
                    print("⚠️ Skipping unverified transaction for product: \(transaction.productID). Error: \(String(describing: error))")
                }
            }
        }
    }

    /// Stops listening to StoreKit transaction updates.
    func stopListeningToTransactionUpdates() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    // MARK: - Current Transaction Tracking

    private var currentTransactionId: String? = nil
    private var currentTransactionPurchaseDate: Date? = nil

    private func considerAsCurrentTransaction(_ transaction: StoreKit.Transaction) {
        let candidateId = String(transaction.id)
        let candidateDate = transaction.purchaseDate
        // Prefer the most recent purchase date
        if let existingDate = currentTransactionPurchaseDate {
            if candidateDate > existingDate {
                currentTransactionId = candidateId
                currentTransactionPurchaseDate = candidateDate
            }
        } else {
            currentTransactionId = candidateId
            currentTransactionPurchaseDate = candidateDate
        }
    }

    private func setupAuthStateListener() {
        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            if let user = user {
                // Start listening once authenticated
                self.startListeningToTransactionUpdates()
                // Optionally backfill current entitlements on sign-in
                Task { @MainActor in
                    await self.recordCurrentEntitlements(userId: user.uid)
                    // Attempt to start a session if we have both a logged-in user and a current transaction
                    self.startSessionIfReady()
                    self.checkIfRecordedSeachedByImage()
                }
            } else {
                // Stop listening when signed out
                self.stopListeningToTransactionUpdates()
                // Clear current transaction context
                self.currentTransactionId = nil
                self.currentTransactionPurchaseDate = nil
            }
        }
    }

    /// Records all current entitlements for the signed-in user.
    /// For each entitlement, writes a Firestore document with id = transactionId
    /// and includes the userId along with basic transaction metadata.
    func recordCurrentEntitlements(userId: String) async {
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                // Track as potential current transaction
                considerAsCurrentTransaction(transaction)
                await writeTransaction(transaction: transaction, userId: userId)
            case .unverified(let transaction, let error):
                print("⚠️ Skipping unverified entitlement for product: \(transaction.productID). Error: \(String(describing: error))")
            }
        }
    }
    
    private func getRevenueCatId() -> String {
        if Purchases.isConfigured {
            return Purchases.shared.appUserID
        }
        return ""
    }

    private func writeTransaction(transaction: StoreKit.Transaction, userId: String) async {
        let db = Firestore.firestore()

        let docId = String(transaction.id) // transaction.id is the App Store transaction identifier
        let collection = db.collection("transactions")
        let revenueCatUserId = getRevenueCatId()

        var data: [String: Any] = [
            "userId": userId,
            "revenueCatUserId": revenueCatUserId,
            "productId": transaction.productID,
            "transactionId": String(transaction.id),
            "originalTransactionId": String(transaction.originalID),
            "purchaseDate": Timestamp(date: transaction.purchaseDate),
            "environment": transaction.environment == .sandbox ? "sandbox" : "production",
            "updatedAt": FieldValue.serverTimestamp()
        ]

        // Maintain current transaction pointer when we write
        considerAsCurrentTransaction(transaction)

        do {
            try await collection.document(docId).setData(data, merge: true)
            print("✅ Recorded entitlement for product \(transaction.productID) with docId=\(docId)")
        } catch {
            print("❌ Failed to write entitlement docId=\(docId): \(error)")
        }
    }

    // MARK: - Auth-based write helpers

    private func writeTransaction(transaction: StoreKit.Transaction) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("ℹ️ No Firebase user is signed in; skipping transaction write.")
            return
        }
        await writeTransaction(transaction: transaction, userId: uid)
    }

    private func checkIfRecordedSeachedByImage() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let docId = currentTransactionId else { return }
        
        let db = Firestore.firestore()
        let docRef = db.collection("transactions").document(docId)
        Task {
            do {
                let document = try await docRef.getDocument()
                if let data = document.data(),
                   let usedSubscription = data["usedSubscription"] as? Bool {
                    recordedSeachedByImage = usedSubscription
                }
                print("recorded search \(recordedSeachedByImage)")
            } catch {
                print("❌ Failed to get transaction: \(error)")
            }
        }
    }
    
    func recordSeachedByImage() async {
        guard (Auth.auth().currentUser?.uid) != nil else { return }
        guard let docId = currentTransactionId else { return }
        guard !recordedSeachedByImage else { return }
        
        let db = Firestore.firestore()
        let docRef = db.collection("transactions").document(docId)
        do {
            try await docRef.setData([
                "usedSubscription": true,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            print("❌ Failed to increment playTimeSeconds: \(error)")
        }
    }

    /// Public API: increments playtime for the current transaction document.
    private func incrementCurrentTransactionPlayTime(by seconds: Int) async {
        guard seconds > 0 else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let docId = currentTransactionId else { return }
        
        print("incrementing by seconds \(seconds)")

        let db = Firestore.firestore()
        let docRef = db.collection("transactions").document(docId)
        do {
            try await docRef.setData([
                "userId": uid,
                "transactionId": docId,
                "playTimeSeconds": FieldValue.increment(Int64(seconds)),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            print("❌ Failed to increment playTimeSeconds: \(error)")
        }
    }

    func startSession() {
        sessionStartTime = Date()
    }

    func endSession() {
        guard let startTime = sessionStartTime else { return }
        let sessionDuration = Date().timeIntervalSince(startTime)
        sessionStartTime = nil
        Task { await incrementCurrentTransactionPlayTime(by: Int(sessionDuration)) }
        
    }

    // MARK: - Session Readiness
    public var isReadyForSession: Bool {
        return Auth.auth().currentUser != nil && currentTransactionId != nil
    }

    public func startSessionIfReady() {
        guard isReadyForSession else { return }
        guard sessionStartTime == nil else { return }
        startSession()
    }
}


