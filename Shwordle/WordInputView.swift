//
//  WordInputView.swift
//  Shwordle
//
//  Created by Administrator on 2025-03-16.
//

import SwiftUI

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


#Preview {
    WordInputView()
}
