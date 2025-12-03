//
//  ConsumptionRequestService.swift
//  Thrifty
//
//  Created by Eliana Silva on 9/13/25.
//

import Foundation
import FirebaseFirestore
import FirebaseFunctions

class ConsumptionRequestService {
    static let shared = ConsumptionRequestService()
    private let functions = Functions.functions()
    private var syncTimer: Timer?
    
    // Session tracking
    private var sessionStartTime: Date?
    private var totalPlayTimeSeconds: TimeInterval = 0
    private var hasUsedSubscription: Bool = false
    
    private init() {
        print("📊 ConsumptionRequestService: User account initialized")
        loadPlayTime()
        startSession()
        startPeriodicSync()
    }
    
    // MARK: - API Call Tracking
    
    func trackOpenAICall(successful: Bool, estimatedCostCents: Int) {
        let event = [
            "type": "openai_call",
            "successful": successful,
            "cost_cents": estimatedCostCents,
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        logConsumptionEvent(event)
        print("📊 OpenAI call tracked: \(successful ? "successful" : "failed"), cost: \(estimatedCostCents) cents")
    }
    
    func trackSerpAPICall(successful: Bool, estimatedCostCents: Int) {
        let event = [
            "type": "serpapi_call",
            "successful": successful,
            "cost_cents": estimatedCostCents,
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        logConsumptionEvent(event)
        print("📊 SerpAPI call tracked: \(successful ? "successful" : "failed"), cost: \(estimatedCostCents) cents")
    }
    
    func trackFirebaseCall(successful: Bool, estimatedCostCents: Int) {
        let event = [
            "type": "firebase_call",
            "successful": successful,
            "cost_cents": estimatedCostCents,
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        logConsumptionEvent(event)
        print("📊 Firebase call tracked: \(successful ? "successful" : "failed"), cost: \(estimatedCostCents) cents")
    }
    
    // MARK: - Session Management
    
    func startSession() {
        // Save any previous session time before starting new session
        if let previousStart = sessionStartTime {
            let sessionDuration = Date().timeIntervalSince(previousStart)
            totalPlayTimeSeconds += sessionDuration
            savePlayTime()
        }
        
        sessionStartTime = Date()
        print("📊 ConsumptionRequestService: Session started")
        
        // Track session start
        let sessionEvent = [
            "type": "session_start",
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        logConsumptionEvent(sessionEvent)
    }
    
    func endSession() {
        guard let startTime = sessionStartTime else { return }
        
        let sessionDuration = Date().timeIntervalSince(startTime)
        totalPlayTimeSeconds += sessionDuration
        savePlayTime()
        
        print("📊 ConsumptionRequestService: Session ended. Duration: \(Int(sessionDuration))s, Total: \(Int(totalPlayTimeSeconds))s")
        
        sessionStartTime = nil
    }
    
    func getCurrentPlayTime() -> TimeInterval {
        var currentTotal = totalPlayTimeSeconds
        
        // Add current session time if active
        if let startTime = sessionStartTime {
            currentTotal += Date().timeIntervalSince(startTime)
        }
        
        return currentTotal
    }
    
    private func loadPlayTime() {
        totalPlayTimeSeconds = UserDefaults.standard.double(forKey: "total_play_time_seconds")
        hasUsedSubscription = UserDefaults.standard.bool(forKey: "has_used_subscription")
        print("📊 Loaded play time: \(Int(totalPlayTimeSeconds))s, used subscription: \(hasUsedSubscription)")
    }
    
    private func savePlayTime() {
        UserDefaults.standard.set(totalPlayTimeSeconds, forKey: "total_play_time_seconds")
        print("📊 Saved play time: \(Int(totalPlayTimeSeconds))s")
    }
    
    func trackMapInteraction(interactionType: String) {
        let event = [
            "type": "map_interaction",
            "interaction_type": interactionType,
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        logConsumptionEvent(event)
        print("📊 Map interaction tracked: \(interactionType)")
    }
    
    func trackFeatureUsed(_ feature: String) {
        let event = [
            "type": "feature_used",
            "feature": feature,
            "timestamp": Date().timeIntervalSince1970
        ] as [String : Any]
        
        logConsumptionEvent(event)
        print("📊 Feature usage tracked: \(feature)")
    }
    
    // MARK: - Subscription Usage Tracking
    
    func markSubscriptionAsUsed() {
        if !hasUsedSubscription {
            hasUsedSubscription = true
            UserDefaults.standard.set(true, forKey: "has_used_subscription")
            print("📊 Subscription marked as USED")
            
            // Track this important event
            let event = [
                "type": "subscription_used",
                "timestamp": Date().timeIntervalSince1970
            ] as [String : Any]
            
            logConsumptionEvent(event)
        }
    }
    
    // MARK: - Transaction Recording
    
    func recordTransaction(
        transactionId: String,
        originalTransactionId: String,
        productId: String,
        purchaseDate: Date,
        expiresDate: Date?,
        price: Double,
        currency: String,
        userId: String,
        userEmail: String?,
        revenueCatUserId: String?
    ) {
        let transactionData: [String: Any] = [
            "transactionId": transactionId,
            "originalTransactionId": originalTransactionId,
            "productId": productId,
            "purchaseDate": purchaseDate.timeIntervalSince1970,
            "expiresDate": expiresDate?.timeIntervalSince1970 ?? 0,
            "price": price,
            "currency": currency,
            "userId": userId,
            "userEmail": userEmail ?? "",
            "revenueCatUserId": revenueCatUserId ?? "",
            "usedSubscription": hasUsedSubscription,
            "playTimeSeconds": getCurrentPlayTime(),
            "recordedAt": Date().timeIntervalSince1970
        ]
        
        print("📊 Recording transaction: \(transactionId)")
        
        // Save transaction ID for future updates
        UserDefaults.standard.set(transactionId, forKey: "last_transaction_id")
        
        // Call Firebase Function to store transaction
        functions.httpsCallable("recordTransaction").call(transactionData) { result, error in
            if let error = error {
                print("❌ Failed to record transaction: \(error.localizedDescription)")
            } else {
                print("✅ Transaction recorded successfully: \(transactionId)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func logConsumptionEvent(_ event: [String: Any]) {
        // Store consumption events for later analysis
        var events = UserDefaults.standard.array(forKey: "consumption_events") as? [[String: Any]] ?? []
        events.append(event)
        
        // Keep only last 1000 events to prevent storage bloat
        if events.count > 1000 {
            events = Array(events.suffix(1000))
        }
        
        UserDefaults.standard.set(events, forKey: "consumption_events")
        
        // Trigger sync if we have enough events
        if events.count % 10 == 0 {
            syncConsumptionDataToServer()
        }
    }
    
    // MARK: - Server Sync Methods
    
    private func startPeriodicSync() {
        // Sync consumption data every 5 minutes
        syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            self.syncConsumptionDataToServer()
            self.updateMostRecentTransaction()
        }
    }
    
    func syncConsumptionDataToServer() {
        guard let userEmail = getUserEmail() else {
            print("📊 No user email available for consumption sync")
            return
        }
        
        let events = UserDefaults.standard.array(forKey: "consumption_events") as? [[String: Any]] ?? []
        
        if events.isEmpty {
            print("📊 No consumption events to sync")
            return
        }
        
        let userId = generateUserId(from: userEmail)
        
        let data: [String: Any] = [
            "userId": userId,
            "userEmail": userEmail,
            "consumptionEvents": events,
            "productId": getCurrentProductId()
        ]
        
        print("📊 Syncing \(events.count) consumption events to server...")
        
        functions.httpsCallable("syncConsumptionData").call(data) { result, error in
            if let error = error {
                print("❌ Failed to sync consumption data: \(error.localizedDescription)")
            } else {
                print("✅ Successfully synced consumption data to server")
                // Clear local events after successful sync
                UserDefaults.standard.set([], forKey: "consumption_events")
            }
        }
    }
    
    private func getUserEmail() -> String? {
        // Try to get user email from various sources
        if let email = UserDefaults.standard.string(forKey: "user_email") {
            return email
        }
        
        // Check if we can get it from AuthenticationManager
        // You might need to adjust this based on your auth implementation
        return nil
    }
    
    private func generateUserId(from email: String) -> String {
        // Create a consistent user ID from email
        return email.lowercased().replacingOccurrences(of: "@", with: "_").replacingOccurrences(of: ".", with: "_")
    }
    
    private func getCurrentProductId() -> String {
        // Return the current subscription product ID
        // You might want to make this dynamic based on the actual subscription
        return "com.thrifty.thrifty.unlimited.monthly"
    }
    
    func forceSync() {
        print("📊 Forcing consumption data sync...")
        syncConsumptionDataToServer()
        updateMostRecentTransaction()
    }
    
    // MARK: - Transaction Updates
    
    func updateMostRecentTransaction() {
        guard let userEmail = getUserEmail() else {
            print("📊 No user email available for transaction update")
            return
        }
        
        // Get the most recent transaction ID from UserDefaults
        guard let lastTransactionId = UserDefaults.standard.string(forKey: "last_transaction_id") else {
            print("📊 No recent transaction to update")
            return
        }
        
        let userId = generateUserId(from: userEmail)
        
        let updateData: [String: Any] = [
            "transactionId": lastTransactionId,
            "userId": userId,
            "usedSubscription": hasUsedSubscription,
            "playTimeSeconds": getCurrentPlayTime(),
            "updatedAt": Date().timeIntervalSince1970
        ]
        
        print("📊 Updating transaction \(lastTransactionId) with latest data...")
        print("   - Play Time: \(Int(getCurrentPlayTime()))s")
        print("   - Used Subscription: \(hasUsedSubscription)")
        
        functions.httpsCallable("updateTransaction").call(updateData) { result, error in
            if let error = error {
                print("❌ Failed to update transaction: \(error.localizedDescription)")
            } else {
                print("✅ Transaction updated successfully")
            }
        }
    }
    
    // Add test consumption events for debugging
    func addTestConsumptionEvents() {
        print("🧪 Adding test consumption events...")
        
        // Add some test events
        trackOpenAICall(successful: true, estimatedCostCents: 25)
        trackSerpAPICall(successful: true, estimatedCostCents: 10)
        trackFirebaseCall(successful: true, estimatedCostCents: 2)
        trackFeatureUsed("test_feature_analysis")
        trackFeatureUsed("test_map_interaction")
        
        // Force immediate sync
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.forceSync()
        }
    }
    
    deinit {
        endSession()
        syncTimer?.invalidate()
    }
}
