//
//  ShwordleGameView.swift
//  Shwordle
//
//  Created by Administrator on 2025-02-23.
//

import FirebaseFirestore
import SwiftUI

struct ShwordleGameView: View {
    @EnvironmentObject var gameManager: GameManager // Use @EnvironmentObject
    @StateObject var userManager = UserManager.shared
    @State private var showLoginView: Bool = false // Add this state
    @State private var grid: [[(letter: String, state: TileState)]] = Array(
        repeating: Array(repeating: ("", .empty), count: 5), // 5 columns
        count: 6 // 6 rows
    )
    @State private var currentRow: Int = 0
    @State private var currentColumn: Int = 0
    @State private var keyStates: [String: TileState] = [:]
    @State private var gameOver: Bool = false
    @State private var showWinAlert: Bool = false
    @State private var showLoseAlert: Bool = false
    @State private var showSetNewWord: Bool = false
    @State private var newWordInput: String = ""
    @State private var targetWord: String = "swift"
    @State private var shake: Bool = false

    let db = Firestore.firestore()
    let keyboardLetters: [[String]] = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["Z", "X", "C", "V", "B", "N", "M"]
    ]

    var body: some View {
        ZStack {
            if userManager.currentUser == nil {
                // Show login view if not authenticated
                LoginView(isLoggedIn: $showLoginView)
            } else {
                VStack {
                    WordleGridView(grid: grid, shake: $shake)
                    KeyboardView(
                        letters: keyboardLetters,
                        onKeyTap: handleKeyTap,
                        keyStates: keyStates,
                        isDisabled: gameOver
                    )
                    Spacer()
                }
                .padding()
                .onAppear {
                    fetchCurrentWord()
                    listenToGameUpdates()
                }

                // Win Alert
                if showWinAlert {
                    resultAlert(
                        title: "You Win! 🎉",
                        message: "Congratulations! You guessed the word!",
                        primaryAction: { showSetNewWord = true }
                    )
                }

                // Lose Alert
                if showLoseAlert {
                    resultAlert(
                        title: "Game Over 😞",
                        message: "The word was: \(targetWord.uppercased())",
                        primaryAction: { showSetNewWord = true }
                    )
                }

                // Set New Word Popup
                if showSetNewWord {
                    newWordPopup
                }
            }
        }
    }

    // MARK: - UI Components

    private func resultAlert(title: String, message: String, primaryAction: @escaping () -> Void) -> some View {
        Color.black.opacity(0.4).ignoresSafeArea()
        return VStack {
            Text(title)
                .font(.title)
                .padding()
                .foregroundColor(.gray)
            Text(message)
                .font(.headline)
                .padding()
                .foregroundColor(.gray)
            HStack {
                Button("New Game") {
                    primaryAction()
                    showWinAlert = false
                    showLoseAlert = false
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .frame(width: 300, height: 200)
        .background(Color.white)
        .cornerRadius(12)
    }

    private var newWordPopup: some View {
        Color.black.opacity(0.4).ignoresSafeArea()
        return VStack {
            TextField("Enter New Word", text: $newWordInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .autocapitalization(.none)

            HStack {
                Button("Cancel") {
                    showSetNewWord = false
                    newWordInput = ""
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)

                Button("Set") {
                    validateAndSetNewWord()
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .frame(width: 300, height: 200)
        .background(Color.white)
        .cornerRadius(12)
    }

    // MARK: - Input Handling

    private func handleKeyTap(_ letter: String) {
        guard !gameOver else { return }

        if letter == "DELETE" {
            deleteLastLetter()
        } else {
            addLetter(letter)
        }
    }

    private func deleteLastLetter() {
        if currentColumn > 0 {
            currentColumn -= 1
            grid[currentRow][currentColumn] = ("", .empty)
        }
    }

    private func addLetter(_ letter: String) {
        if currentColumn < 5 {
            grid[currentRow][currentColumn] = (letter, .empty)
            currentColumn += 1

            if currentColumn == 5 {
                submitGuess()
            }
        }
    }

    // MARK: - Game Logic

    private func submitGuess() {
        let guess = grid[currentRow].map { $0.letter }.joined().lowercased()

        // Word validation
        guard WordList.contains(guess) else {
            withAnimation { shake.toggle() }
            return
        }

        // Check letters
        let targetLetters = Array(targetWord)
        var guessLetters = Array(guess)
        var remainingLetters = targetLetters

        // First pass: Check correct letters
        for i in 0 ..< 5 {
            if guessLetters[i] == targetLetters[i] {
                grid[currentRow][i].state = .correct
                remainingLetters[i] = " "
                guessLetters[i] = " "
            }
        }

        // Second pass: Check misplaced letters
        for i in 0 ..< 5 {
            guard guessLetters[i] != " " else { continue }

            if let matchIndex = remainingLetters.firstIndex(of: guessLetters[i]) {
                grid[currentRow][i].state = .misplaced
                remainingLetters[matchIndex] = " "
            } else {
                grid[currentRow][i].state = .incorrect
            }
        }

        updateKeyboardStates(for: guess.uppercased())

        // Check win/lose conditions
        if guess == targetWord {
            showWinAlert = true
            gameOver = true
        } else if currentRow == 5 {
            showLoseAlert = true
            gameOver = true
        } else {
            currentRow += 1
            currentColumn = 0
        }

        // Submit move to Firestore
        gameManager.submitMove(guess: guess)
    }

    // MARK: - Firebase Integration

    private func fetchCurrentWord() {
        db.collection("gameState").document("currentWord").getDocument { snapshot, error in
            if let error = error {
                print("Error fetching word: \(error)")
                return
            }
            if let word = snapshot?.data()?["word"] as? String {
                targetWord = word.lowercased()
            }
        }
    }

    private func listenToGameUpdates() {
        guard let gameId = gameManager.currentGame?.id else { return }

        db.collection("games").document(gameId)
            .addSnapshotListener { document, error in
                guard let document = document else { return }
                if let game = try? document.data(as: GameManager.Game.self) {
                    self.updateGrid(with: game.moves)
                }
            }
    }

    private func updateGrid(with moves: [GameManager.Move]) {
        // Reset the grid to 6 rows and 5 columns
        grid = Array(repeating: Array(repeating: ("", .empty), count: 5), count: 6) // 6 rows, 5 columns
        currentRow = 0
        currentColumn = 0

        // Replay all moves
        for move in moves {
            for (index, char) in move.guess.enumerated() {
                grid[currentRow][index] = (String(char), .empty)
            }
            currentRow += 1
        }
    }

    private func validateAndSetNewWord() {
        let newWord = newWordInput.trimmingCharacters(in: .whitespaces).lowercased()

        guard newWord.count == 5 else {
            print("Word must be 5 letters!")
            return
        }

        guard WordList.contains(newWord) else {
            print("Invalid word!")
            return
        }

        db.collection("gameState").document("currentWord").setData(["word": newWord]) { error in
            if let error = error {
                print("Error saving word: \(error)")
                return
            }
            targetWord = newWord
            resetGame()
            showSetNewWord = false
            newWordInput = ""
        }
    }

    // MARK: - Helpers

    private func updateKeyboardStates(for guess: String) {
        let targetLetters = Array(targetWord.uppercased())
        let guessLetters = Array(guess)
        var newStates = keyStates

        for (index, letter) in guessLetters.enumerated() {
            if letter == targetLetters[index] {
                newStates[String(letter)] = .correct
            } else if targetLetters.contains(letter) {
                if newStates[String(letter)] != .correct {
                    newStates[String(letter)] = .misplaced
                }
            } else {
                newStates[String(letter)] = .incorrect
            }
        }
        keyStates = newStates
    }

    private func resetGame() {
        grid = Array(repeating: Array(repeating: ("", .empty), count: 5), count: 6) // Fixed syntax
        currentRow = 0
        currentColumn = 0
        keyStates = [:]
        gameOver = false
        shake = false
    }
}

#Preview {
    ShwordleGameView()
}

struct WordList {
    static let words: Set<String> = {
        guard let fileURL = Bundle.main.url(forResource: "words", withExtension: "txt") else {
            fatalError("Could not find words.txt in bundle")
        }
        do {
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            return Set(contents.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces).lowercased() })
        } catch {
            fatalError("Error loading words: \(error)")
        }
    }()

    static func contains(_ word: String) -> Bool {
        words.contains(word.lowercased())
    }
}
