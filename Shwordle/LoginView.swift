//
//  LoginView.swift
//  Shwordle
//
//  Created by Administrator on 2025-02-23.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String = ""
    @Binding var isLoggedIn: Bool

    var body: some View {
        VStack {
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .padding()

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }

            Button(action: login) {
                Text("Login")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            Button(action: signUp) {
                Text("Sign Up")
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }

    private func login() {
        userManager.login(email: email, password: password) { success in
            if success {
                isLoggedIn = true
            } else {
                errorMessage = "Login failed. Please check your credentials."
            }
        }
    }

    private func signUp() {
        userManager.signUp(email: email, password: password) { success in
            if success {
                isLoggedIn = true
            } else {
                errorMessage = "Sign-up failed. Please try again."
            }
        }
    }
}

#Preview {
    LoginView(isLoggedIn: .constant(false))
        .environmentObject(UserManager.shared)
}
