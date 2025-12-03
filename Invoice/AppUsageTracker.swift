//
//  AppUsageTracker.swift
//  Thrifty
//
//  Created by Eliana Silva on 9/13/25.
//

import Foundation

class AppUsageTracker: ObservableObject {
    static let shared = AppUsageTracker()
    
    @Published var sessionStartTime: Date?
    @Published var totalScans: Int = 0
    @Published var totalAnalyses: Int = 0
    @Published var totalFeatureUsage: [String: Int] = [:]
    
    init() {
        // Initialize with safe defaults first
        totalScans = 0
        totalAnalyses = 0
        totalFeatureUsage = [:]
        
        // Load data safely
        DispatchQueue.main.async { [weak self] in
            self?.loadUsageData()
        }
        
        print("📱 AppUsageTracker: Initialized")
    }
    
    // MARK: - Session Management
    
    func startSession() {
        guard sessionStartTime == nil else {
            print("📱 AppUsageTracker: Session already active, skipping start")
            return
        }
        
        sessionStartTime = Date()
        print("📱 AppUsageTracker: Session started")
        
        // Track session start - safely handle Mixpanel initialization
        DispatchQueue.main.async { [weak self] in
            guard self?.sessionStartTime != nil else { return }
            MixpanelService.shared.trackAppLaunched()
        }
    }
    
    func endSession() {
        guard let startTime = sessionStartTime else { return }
        
        let sessionDuration = Date().timeIntervalSince(startTime)
        print("📱 AppUsageTracker: Session ended - Duration: \(sessionDuration) seconds")
        
        // Track session end - safely on main thread
        DispatchQueue.main.async {
            MixpanelService.shared.setUserProperty(key: "last_session_duration", value: sessionDuration)
        }
        
        sessionStartTime = nil
        saveUsageData()
    }
    
    // MARK: - Feature Tracking
    
    func trackScan() {
        totalScans += 1
        saveUsageData()
        print("📊 Scan tracked: \(totalScans) total scans")
        
        // Track in Mixpanel - safely on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            MixpanelService.shared.setUserProperty(key: "total_scans", value: self.totalScans)
        }
    }
    
    func trackFeatureUsage(_ feature: String) {
        totalFeatureUsage[feature, default: 0] += 1
        saveUsageData()
        print("📱 AppUsageTracker: Feature usage tracked - \(feature)")
        
        // Track in Mixpanel - safely on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            MixpanelService.shared.setUserProperty(key: "feature_usage_\(feature)", value: self.totalFeatureUsage[feature] ?? 0)
        }
    }
    
    func trackSuccessfulAnalysis() {
        totalAnalyses += 1
        saveUsageData()
        print("📊 Successful analysis tracked: \(totalAnalyses) total")
        
        // Track in Mixpanel - safely on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            MixpanelService.shared.setUserProperty(key: "total_analyses", value: self.totalAnalyses)
        }
    }
    
    // MARK: - Data Persistence
    
    private func saveUsageData() {
        UserDefaults.standard.set(totalScans, forKey: "app_usage_total_scans")
        UserDefaults.standard.set(totalAnalyses, forKey: "app_usage_total_analyses")
        
        if let encoded = try? JSONEncoder().encode(totalFeatureUsage) {
            UserDefaults.standard.set(encoded, forKey: "app_usage_feature_usage")
        }
    }
    
    private func loadUsageData() {
        totalScans = UserDefaults.standard.integer(forKey: "app_usage_total_scans")
        totalAnalyses = UserDefaults.standard.integer(forKey: "app_usage_total_analyses")
        
        if let data = UserDefaults.standard.data(forKey: "app_usage_feature_usage"),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            totalFeatureUsage = decoded
        }
    }
    
    // MARK: - Analytics
    
    func getUsageStats() -> [String: Any] {
        return [
            "total_scans": totalScans,
            "total_analyses": totalAnalyses,
            "feature_usage": totalFeatureUsage,
            "current_session_duration": sessionStartTime?.timeIntervalSinceNow.magnitude ?? 0
        ]
    }
}
