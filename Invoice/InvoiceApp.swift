//
//  InvoiceApp.swift
//  Invoice
//
//  Created by Eliana Silva on 8/19/24.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn

@main
struct InvoiceApp: App {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    
    init() {
        // Configure Firebase when app launches
        FirebaseApp.configure()
        
        // Suppress verbose Firebase internal logs AFTER configuration
        // This stops the constant [FirebaseFirestore][I-FST000001] messages
        let firestore = Firestore.firestore()
        let settings = firestore.settings
        settings.isSSLEnabled = true // Ensure secure connection
        
        // Enable offline persistence for better user experience
        // This allows the app to work even when offline and sync when back online
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited // Allow unlimited cache
        
        firestore.settings = settings
        
        // Disable Firebase internal logging
        #if DEBUG
        FirebaseConfiguration.shared.setLoggerLevel(.warning) // Only show warnings/errors in debug
        #else
        FirebaseConfiguration.shared.setLoggerLevel(.error) // Only show errors in production
        #endif
        
        print("🔥 Firebase configured successfully with offline persistence")
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                // Show main app if user is logged in and has completed subscription
                // Otherwise show welcome/onboarding/subscription flow
                if authManager.isLoggedIn && authManager.hasCompletedSubscription {
                    MainAppView()
                } else {
                    ContentView()
                }
            }
            .environment(\.locale, languageManager.currentLocale)
            .onOpenURL { url in
                // Handle Google Sign In URL callback
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
