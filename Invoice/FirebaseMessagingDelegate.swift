//
//  FirebaseMessagingDelegate.swift
//  Thrifty
//
//  Created by Eliana Silva on 9/16/25.
//

import Foundation
import FirebaseMessaging
import UserNotifications

class FirebaseMessagingDelegate: NSObject {
    static let shared = FirebaseMessagingDelegate()
    
    private override init() {
        super.init()
    }
}

// MARK: - MessagingDelegate
extension FirebaseMessagingDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else {
            print("❌ FCM token is nil")
            return
        }
        
        print("📱 FCM token received: \(fcmToken.prefix(20))...")
        print("🔑 FCM token updated - will be stored when user signs in")
        
        // Store the token in UserDefaults for later use
        UserDefaults.standard.set(fcmToken, forKey: "fcm_token")
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension FirebaseMessagingDelegate: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        
        print("📱 Received notification while app in foreground")
        print("📦 Notification data: \(userInfo)")
        
        // Show notifications normally
        completionHandler([.alert, .badge, .sound])
    }
    
    // Handle notification tap when app is in background/closed
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        print("📱 User tapped notification")
        print("📦 Notification data: \(userInfo)")
        
        // Handle notification tap here if needed
        
        completionHandler()
    }
}
