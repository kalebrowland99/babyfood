//
//  InvoiceApp.swift
//  Invoice
//
//  Created by Eliana Silva on 8/19/24.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging
import GoogleSignIn
import BackgroundTasks
import UserNotifications
import RevenueCat
import FBSDKCoreKit

@main
struct InvoiceApp: App {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var remoteConfig = RemoteConfigManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        configureFirebase()
        configureFacebookSDK()
        configureGoogleServices()
        configurePushNotifications()
        configureRevenueCat()
        configureAnalyticsServices()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if authManager.isLoggedIn {
                        if authManager.hasCompletedSubscription {
                            MainAppView()
                                .transition(.opacity)
                        } else {
                            OnboardingView()
                                .transition(.opacity)
                        }
                    } else {
                        ContentView()
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: authManager.isLoggedIn)
                .animation(.easeInOut(duration: 0.3), value: authManager.hasCompletedSubscription)
                
                // Blocking paywall overlay (only shown when user is logged in and blocked)
                if authManager.isLoggedIn && authManager.hasCompletedSubscription && blockingManager.showBlockingPaywall {
                    SubscriptionBlockingView(blockingManager: blockingManager)
                        .transition(.opacity)
                        .zIndex(999)
                }
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .onAppear {
                print("🚀 App launched - showing \(authManager.isLoggedIn ? (authManager.hasCompletedSubscription ? "MainAppView" : "OnboardingView") : "ContentView")")
                print("🎛️ Current paywall config - hardPaywall: \(remoteConfig.hardPaywall)")
                
                // Check subscription status from Firestore on launch
                Task {
                    await checkSubscriptionStatusFromFirestore()
                    
                    // Check for subscription blocking (canceled, payment failed, etc.)
                    if authManager.isLoggedIn && authManager.hasCompletedSubscription {
                        await blockingManager.checkSubscriptionStatus()
                    }
                    
                    // Also check for pending Stripe subscriptions (in case user paid but force quit before linking)
                    if authManager.isLoggedIn {
                        await checkAndLinkPendingSubscription()
                    }
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            print("📱 App became active")
            ConsumptionRequestService.shared.startSession()
        case .inactive:
            print("📱 App became inactive")
            // User might be switching apps or looking at notifications
        case .background:
            print("📱 App moved to background")
            ConsumptionRequestService.shared.endSession()
            ConsumptionRequestService.shared.syncConsumptionDataToServer()
            ConsumptionRequestService.shared.updateMostRecentTransaction()
        @unknown default:
            break
        }
    }
}

// MARK: - Configuration Methods
private extension InvoiceApp {
    
    func configureFirebase() {
        // Ensure Firebase is configured on the main thread to avoid CoreData issues
        if Thread.isMainThread {
            FirebaseApp.configure()
        } else {
            DispatchQueue.main.sync {
                FirebaseApp.configure()
            }
        }
        print("✅ Firebase configured successfully")
        
        // Initialize remote config after Firebase is ready
        DispatchQueue.main.async {
            RemoteConfigManager.shared.initializeConfig()
        }
    }
    
    func configureFacebookSDK() {
        // Initialize Facebook SDK with App Events
        ApplicationDelegate.shared.application(
            UIApplication.shared,
            didFinishLaunchingWithOptions: nil
        )
        
        // Enable automatic event logging (for AEM)
        Settings.shared.isAutoLogAppEventsEnabled = true
        Settings.shared.isAdvertiserIDCollectionEnabled = true
        Settings.shared.isAdvertiserTrackingEnabled = true
        
        // Disable Privacy Manifest domain errors (required for iOS 17+)
        // This prevents silent failures in deeplink verification
        Settings.shared.isDomainErrorEnabled = false
        
        print("✅ Facebook SDK configured successfully")
        print("📱 FB App ID: \(APIKeys.facebookAppID)")
    }
    
    func configureGoogleServices() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("⚠️ GoogleService-Info.plist not found or CLIENT_ID missing - Google services will not work")
            return
        }
        
        // Configure Google Sign In
        GoogleSignIn.GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
        print("✅ Google Sign In configured successfully")
    }
    
    func configurePushNotifications() {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("❌ Push notification permission error: \(error)")
                return
            }
            
            if granted {
                print("✅ Push notification permissions granted")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("⚠️ Push notification permissions denied")
            }
        }
        
        // Set up Firebase Messaging delegate (if permissions granted)
        DispatchQueue.main.async {
            // We'll implement a fallback system that works without push permissions
            print("📱 Push notification setup will be handled after permissions check")
        }
        
        print("📱 Push notifications configured")
    }
    
    func configureAnalyticsServices() {
        // Initialize Mixpanel service first (this ensures it's ready before other services use it)
        _ = MixpanelService.shared
        print("📊 Analytics services configured successfully")
        
        // Initialize tracking services after Mixpanel is ready
        _ = ConsumptionRequestService.shared
        _ = AppUsageTracker.shared  // Initialize the singleton
        _ = TransactionUsageTracker.shared  // Initialize consumption tracking
        
        print("📊 All analytics services initialized successfully")
    }
    
    func configureRevenueCat() {
        // Configure RevenueCat with your API key
        // You'll need to get this from your RevenueCat dashboard
        Purchases.logLevel = .debug // Remove in production
        Purchases.configure(withAPIKey: "appl_KKcROFfkXkzRqreINLSiQWOGbvX")
        print("💰 RevenueCat configured successfully")
    }
}
