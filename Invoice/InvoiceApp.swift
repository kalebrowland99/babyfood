//
//  InvoiceApp.swift
//  Invoice
//
//  Created by Eliana Silva on 8/19/24.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct InvoiceApp: App {
    @StateObject private var authManager = AuthenticationManager.shared
    
    init() {
        // Configure Firebase when app launches
        FirebaseApp.configure()
        print("🔥 Firebase configured successfully")
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
            .onOpenURL { url in
                // Handle Google Sign In URL callback
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
