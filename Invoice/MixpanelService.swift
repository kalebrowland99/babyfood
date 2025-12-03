//
//  MixpanelService.swift
//  Thrifty
//
//  Created by Eliana Silva on 9/13/25.
//

import Foundation
import Mixpanel

class MixpanelService {
    static let shared = MixpanelService()
    private var isInitialized = false
    
    private init() {
        // Initialize Mixpanel with API key from APIKeys
        Mixpanel.initialize(token: APIKeys.mixpanel, trackAutomaticEvents: true)
        isInitialized = true
        print("✅ Mixpanel initialized successfully with token: \(APIKeys.mixpanel.prefix(10))...")
    }
    
    // MARK: - Helper Methods
    
    private func trackEvent(_ eventName: String, properties: [String: MixpanelType] = [:]) {
        guard isInitialized else {
            print("⚠️ Mixpanel not initialized, skipping event: \(eventName)")
            return
        }
        
        Mixpanel.mainInstance().track(event: eventName, properties: properties)
    }
    
    // MARK: - Tracking Methods
    
    func trackQuestionViewed(questionTitle: String, stepNumber: Int, timeSpent: TimeInterval? = nil) {
        
        var properties: [String: MixpanelType] = [
            "question_title": questionTitle,
            "step_number": stepNumber
        ]
        if let time = timeSpent {
            properties["time_spent"] = time
        }
        
        trackEvent("Question Viewed", properties: properties)
        print("📊 Tracked: Question Viewed - \(questionTitle) (Step \(stepNumber))")
    }
    
    func trackQuestionAnswered(answer: String, stepNumber: Int? = nil) {
        var properties: [String: MixpanelType] = ["answer": answer]
        if let step = stepNumber {
            properties["step_number"] = step
        }
        
        trackEvent("Question Answered", properties: properties)
        print("📊 Tracked: Question Answered - \(answer)")
    }
    
    func trackQuestionAnswered(questionTitle: String, answer: String, stepNumber: Int, timeSpent: TimeInterval?) {
        var properties: [String: MixpanelType] = [
            "question_title": questionTitle,
            "answer": answer,
            "step_number": stepNumber
        ]
        if let time = timeSpent {
            properties["time_spent"] = time
        }
        
        trackEvent("Question Answered", properties: properties)
        print("📊 Tracked: Question Answered - \(questionTitle): \(answer)")
    }
    
    func trackSubscriptionViewed(planType: String) {
        trackEvent("Subscription Viewed", properties: [
            "plan_type": planType
        ])
        print("📊 Tracked: Subscription Viewed - \(planType)")
    }
    
    func trackOnboardingCompleted(totalTime: TimeInterval? = nil) {
        var properties: [String: MixpanelType] = [:]
        if let time = totalTime {
            properties["total_time"] = time
        }
        
        trackEvent("Onboarding Completed", properties: properties)
        print("📊 Tracked: Onboarding Completed")
    }
    
    func trackAppLaunched() {
        trackEvent("App Launched")
        print("📊 Tracked: App Launched")
    }
    
    func trackUserSignedIn(method: String) {
        trackEvent("User Signed In", properties: [
            "method": method
        ])
        print("📊 Tracked: User Signed In - \(method)")
    }
    
    // MARK: - User Properties
    
    func setUserProperty(key: String, value: MixpanelType) {
        guard isInitialized else {
            print("⚠️ Mixpanel not initialized, skipping user property: \(key)")
            return
        }
        
        Mixpanel.mainInstance().people.set(property: key, to: value)
        print("📊 Set user property: \(key) = \(value)")
    }
    
    func identifyUser(userId: String) {
        guard isInitialized else {
            print("⚠️ Mixpanel not initialized, skipping user identification: \(userId)")
            return
        }
        
        Mixpanel.mainInstance().identify(distinctId: userId)
        print("📊 Identified user: \(userId)")
    }
    
    // MARK: - Additional Tracking Methods
    
    func trackOnboardingStarted() {
        trackEvent("Onboarding Started")
        print("📊 Tracked: Onboarding Started")
    }
    
    func trackOnboardingDropoff(step: Int, stepName: String, timeSpent: TimeInterval?) {
        var properties: [String: MixpanelType] = [
            "step": step,
            "step_name": stepName
        ]
        if let time = timeSpent {
            properties["time_spent"] = time
        }
        
        trackEvent("Onboarding Dropoff", properties: properties)
        print("📊 Tracked: Onboarding Dropoff - Step \(step): \(stepName)")
    }
    
    func trackSubscriptionPurchased(planType: String, price: Double? = nil) {
        var properties: [String: MixpanelType] = ["plan_type": planType]
        if let price = price {
            properties["price"] = price
        }
        
        trackEvent("Subscription Purchased", properties: properties)
        print("📊 Tracked: Subscription Purchased - \(planType)")
    }
    
    // Generic track method for custom events
    func track(event: String, properties: [String: MixpanelType] = [:]) {
        trackEvent(event, properties: properties)
    }
}
