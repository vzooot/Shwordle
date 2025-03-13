//
//  UserManager.swift
//  Shwordle
//
//  Created by Administrator on 2025-03-01.
//

import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging

class UserManager: NSObject, ObservableObject {
    static let shared = UserManager()
    private let db = Firestore.firestore()
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?

    @Published var currentUser: User?
    @Published var fcmToken: String?
    @Published var isLoggedIn = false
    var pendingFCMToken: String?

    deinit {
        if let handle = authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}

// MARK: - Auth Configuration

extension UserManager {
    private func configureAuthStateListener() {
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }

            self.currentUser = user
            self.isLoggedIn = user != nil

            if let user = user {
                self.handleUserLogin(user: user)
            } else {
                self.handleUserLogout()
            }
        }
    }

    private func handleUserLogin(user: User) {
        createUserDocument(user: user) { [weak self] in
            self?.processPendingFCMToken()
        }

        setupUserListeners(userId: user.uid)
    }

    private func handleUserLogout() {
        currentUser = nil
        isLoggedIn = false
        pendingFCMToken = nil
        GameManager.shared.resetGame()
    }
}

// MARK: - FCM Token Management

extension UserManager: MessagingDelegate {
    private func configureMessagingDelegate() {
        Messaging.messaging().delegate = self
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }

        if isLoggedIn {
            updateFCMToken(token)
        } else {
            pendingFCMToken = token
        }
    }

    private func processPendingFCMToken() {
        guard let token = pendingFCMToken, isLoggedIn else { return }
        updateFCMToken(token)
        pendingFCMToken = nil
    }

    func updateFCMToken(_ token: String) {
        guard let userId = currentUser?.uid else {
            pendingFCMToken = token
            return
        }

        db.collection("users").document(userId).updateData([
            "fcmTokens": FieldValue.arrayUnion([token])
        ]) { error in
            if let error = error {
                print("FCM Token Update Error: \(error.localizedDescription)")
            } else {
                print("FCM Token Successfully Updated")
            }
        }
    }
}

// MARK: - User Operations

extension UserManager {
    func login(email: String, password: String, completion: @escaping (Bool) -> Void) {
        print("🔐 Attempting login with: \(email)")
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                print("Login Error: \(error.localizedDescription)")
                completion(false)
                return
            }

            guard let user = result?.user else {
                completion(false)
                return
            }

            self.currentUser = user
            self.isLoggedIn = true
            completion(true)
        }
    }

    func signUp(email: String, password: String, completion: @escaping (Bool) -> Void) {
        print("🔐 Attempting signup with: \(email)")
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                print("Signup Error: \(error.localizedDescription)")
                completion(false)
                return
            }

            guard let user = result?.user else {
                completion(false)
                return
            }

            self.createUserDocument(user: user) {
                self.currentUser = user
                self.isLoggedIn = true
                completion(true)
            }
        }
    }

    func logout() {
        do {
            try Auth.auth().signOut()
            currentUser = nil
            isLoggedIn = false
            pendingFCMToken = nil
            print("✅ Logout successful - UI should update automatically")

            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .authenticationStateChanged, object: nil)
            }
        } catch {
            print("❌ Logout error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Firestore Operations

extension UserManager {
    private func createUserDocument(user: User, completion: @escaping () -> Void) {
        let userRef = db.collection("users").document(user.uid)

        userRef.getDocument { [weak self] snapshot, _ in
            guard let self = self else { return }

            if let snapshot = snapshot, !snapshot.exists {
                userRef.setData([
                    "uid": user.uid,
                    "email": user.email ?? "",
                    "fcmTokens": [],
                    "score": 0,
                    "createdAt": FieldValue.serverTimestamp()
                ]) { error in
                    if let error = error {
                        print("Document Creation Error: \(error.localizedDescription)")
                    } else {
                        print("New User Document Created")
                    }
                    completion()
                }
            } else {
                completion()
            }
        }
    }

    private func setupUserListeners(userId: String) {
        db.collection("users").document(userId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("Listener Error: \(error.localizedDescription)")
                    return
                }

                guard let data = snapshot?.data() else { return }
                print("User Data Updated: \(data)")
            }
    }
}
