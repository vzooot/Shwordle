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

class UserManager: ObservableObject {
    static let shared = UserManager()
    private let db = Firestore.firestore()
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?

    @Published var currentUser: User?
    @Published var fcmToken: String?
    @Published var isLoggedIn: Bool = false

    private init() {
        // Listen for authentication state changes
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            guard let self = self else { return }
            self.currentUser = user
            self.isLoggedIn = (user != nil)
            if let user = user {
                self.setupUserListeners(userId: user.uid)
            }
        }
    }

    deinit {
        // Remove the auth state listener when the object is deallocated
        if let handle = authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func login(email: String, password: String, completion: @escaping (Bool) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let user = result?.user {
                self.currentUser = user
                self.isLoggedIn = true
                self.setupUserListeners(userId: user.uid)
                completion(true)
            } else {
                completion(false)
            }
        }
    }

    func signUp(email: String, password: String, completion: @escaping (Bool) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let user = result?.user {
                self.currentUser = user
                self.isLoggedIn = true
                self.setupUserListeners(userId: user.uid)
                completion(true)
            } else {
                completion(false)
            }
        }
    }

    func logout() {
        do {
            try Auth.auth().signOut()
            self.currentUser = nil
            self.isLoggedIn = false
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }

    private func setupUserListeners(userId: String) {
        db.collection("users").document(userId).addSnapshotListener { document, error in
            guard let document = document, document.exists else { return }
            if let data = document.data() {
                // Handle user data updates
                print("User data updated: \(data)")
            }
        }
    }

    func updateFCMToken(_ token: String) {
        guard let userId = currentUser?.uid else { return }
        fcmToken = token
        db.collection("users").document(userId).updateData([
            "fcmTokens": FieldValue.arrayUnion([token])
        ]) { error in
            if let error = error {
                print("Error updating FCM token: \(error.localizedDescription)")
            } else {
                print("FCM token updated successfully")
            }
        }
    }
}
