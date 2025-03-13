//
//  ShwordleApp.swift
//  Shwordle
//
//  Created by Administrator on 2025-02-23.
//

import FirebaseAuth
import FirebaseCore
import FirebaseMessaging
import SwiftUI
import UserNotifications

func requestNotificationPermissions() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        if granted {
            print("Notification permissions granted ✅")
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } else if let error = error {
            print("Notification permissions denied: \(error.localizedDescription) ❌")
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()

        setupNotifications(application: application)

        restoreAuthState()

        Messaging.messaging().delegate = self

        return true
    }

    // MARK: - Notification Configuration

    private func setupNotifications(application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermissions(application: application)

        application.registerForRemoteNotifications()
    }

    private func requestNotificationPermissions(application: UIApplication) {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .provisional]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
            if let error = error {
                print("🔔 Notification permission error: \(error.localizedDescription)")
                return
            }

            print("🔔 Notification permission granted: \(granted)")
            guard granted else { return }

            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }

    // MARK: - Auth State Management

    private func restoreAuthState() {
        if let user = Auth.auth().currentUser {
            UserManager.shared.currentUser = user
            UserManager.shared.isLoggedIn = true
            print("🔑 Restored authenticated user: \(user.uid)")
        }
    }
}

@main
struct ShwordleApp: App {
    @StateObject var gameManager = GameManager.shared

    @StateObject var userManager = UserManager.shared

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
            .environmentObject(gameManager)
            .environmentObject(userManager)
        }
    }
}

// MARK: - Messaging Delegate

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("🔥 New FCM Token: \(token)")

        if UserManager.shared.isLoggedIn {
            UserManager.shared.updateFCMToken(token)
        } else {
            print("💤 Deferring FCM token storage until login")
            UserManager.shared.pendingFCMToken = token
        }
    }
}

// MARK: - Notification Center Delegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("📲 Received foreground notification: \(userInfo)")

        NotificationCenter.default.post(
            name: .didReceiveGameUpdateNotification,
            object: nil,
            userInfo: userInfo
        )

        completionHandler([.banner, .sound])
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
}
