//
//  ContentView.swift
//  Shwordle
//
//  Created by Administrator on 2025-02-23.
//

import SwiftUI

// ContentView.swift
struct ContentView: View {
    @EnvironmentObject var userManager: UserManager
    @EnvironmentObject var gameManager: GameManager
    @State private var showWordInput = false

    var body: some View {
        Group {
            if userManager.isLoggedIn {
                if gameManager.activeGameID != nil {
                    ShwordleGameView()
                } else if let result = gameManager.lastGameResult {
                    VStack {
                        Text(result.winnerID == userManager.currentUser?.uid ? "You Won! 🎉" : "Game Over")
                        Text("Word: \(result.word.uppercased())")
                        
                        if gameManager.canStartNewGame {
                            Button("Start New Game") {
                                showWordInput = true
                            }
                        } else {
                            Text("Waiting for \(result.winnerID)...")
                        }
                    }
                } else {
                    VStack {
                        Text("No Active Game")
                        Button("Start New Game") {
                            showWordInput = true
                        }
                    }
                }
            } else {
                LoginView(isLoggedIn: $userManager.isLoggedIn)
            }
        }
        .onAppear {
            if userManager.isLoggedIn {
                print("🔍 Checking for active games...")
                gameManager.listenForActiveGame() // Critical add-on
            }
        }
        .sheet(isPresented: $showWordInput) {
            WordInputView()
        }
    }
}

