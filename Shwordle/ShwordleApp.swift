//
//  ShwordleApp.swift
//  Shwordle
//
//  Created by Administrator on 2025-02-23.
//

import FirebaseCore
import FirebaseMessaging
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()

        // Set up Firebase Messaging
        Messaging.messaging().delegate = self

        // Set up notifications
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()

        return true
    }
}

@main
struct ShwordleApp: App {
    // Inject GameManager as an environment object
    @StateObject var gameManager = GameManager.shared

    // Inject UserManager as an environment object
    @StateObject var userManager = UserManager.shared

    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
            .environmentObject(gameManager) // Provide GameManager to the view hierarchy
            .environmentObject(userManager) // Provide UserManager to the view hierarchy
        }
    }
}

// MARK: - Firebase Messaging Delegate
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("Firebase registration token: \(token)")

        // Update the FCM token in UserManager
        UserManager.shared.updateFCMToken(token)
    }
}

// MARK: - Notification Center Delegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notifications even when the app is in the foreground
        completionHandler([.banner, .sound])
    }
}
