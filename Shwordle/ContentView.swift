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
    @State private var showWordInput = false // Add this

    var body: some View {
        Group {
            if userManager.isLoggedIn {
                if gameManager.activeGameID != nil {
                    ShwordleGameView()
                } else {
                    VStack {
                        Text("No Active Game")
                            .font(.title)
                        Button("Start New Game") {
                            showWordInput = true // Trigger word input
                        }
                        .padding()
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                LoginView(isLoggedIn: $userManager.isLoggedIn)
            }
        }
        .onAppear {
            if userManager.isLoggedIn {
                gameManager.listenForActiveGame()
            }
        }
        .sheet(isPresented: $showWordInput) {
            WordInputView()
        }
    }
}

// Add this new view
struct WordInputView: View {
    @EnvironmentObject var gameManager: GameManager
    @Environment(\.dismiss) var dismiss
    @State private var newWord = ""

    var body: some View {
        VStack {
            TextField("Enter 5-letter word", text: $newWord)
                .textFieldStyle(.roundedBorder)
                .padding()
            
            Button("Create Game") {
                guard WordList.contains(newWord.lowercased()),
                      newWord.count == 5 else { return }
                
                gameManager.createNewGame(word: newWord.lowercased())
                dismiss()
            }
            .disabled(!WordList.contains(newWord.lowercased()) || newWord.count != 5)
        }
        .padding()
    }
}
