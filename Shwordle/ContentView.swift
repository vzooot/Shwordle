//
//  ContentView.swift
//  Shwordle
//
//  Created by Administrator on 2025-02-23.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var gameManager: GameManager

    var body: some View {
        if userManager.isLoggedIn {
            ShwordleGameView()
        } else {
            LoginView(isLoggedIn: $userManager.isLoggedIn) // Pass the binding
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(UserManager.shared) // Provide UserManager for preview
        .environmentObject(GameManager.shared) // Provide GameManager for preview
}
