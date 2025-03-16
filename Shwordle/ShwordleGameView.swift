//
//  ShwordleGameView.swift
//  Shwordle
//
//  Created by Administrator on 2025-02-23.
//

import FirebaseFirestore
import SwiftUI

extension Notification.Name {
    static let resetGameUI = Notification.Name("resetGameUI")
}

struct ShwordleGameView: View {
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var userManager: UserManager

    @State private var targetWord: String = ""
    @State private var currentGameId: String?
    @State private var currentRow: Int = 0
    @State private var currentColumn: Int = 0
    @State private var keyStates: [String: TileState] = [:]
    @State private var gameOver: Bool = false
    @State private var showWinAlert: Bool = false
    @State private var showLoseAlert: Bool = false
    @State private var newWordInput: String = ""
    @State private var shake: Bool = false
    @State private var showJoinGameAlert: Bool = false
    @State private var grid: [[(letter: String, state: TileState)]] = Array(
        repeating: Array(repeating: ("", .empty), count: 5),
        count: 6
    )

    @State private var showGameEndAlert: Bool = false
    @State private var gameResult: GameResult? = nil
    @State private var allowNewGameCreation: Bool = false

    enum GameResult: Identifiable {
        case win
        case lose
        var id: Self { self }
    }

    @State private var showNewGameButton: Bool = false
    @State private var alertDismissed: Bool = false

    let db = Firestore.firestore()
    let keyboardLetters: [[String]] = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["Z", "X", "C", "V", "B", "N", "M"]
    ]

    private var isLastPlayer: Bool {
        guard let game = gameManager.currentGame,
              let userID = userManager.currentUser?.uid else { return false }
        return game.lastPlayerId == userID
    }

    var body: some View {
        ZStack {
            if userManager.currentUser == nil {
                LoginView(isLoggedIn: $userManager.isLoggedIn)
            } else {
                gameContentView
            }
        }
    }

    private var gameContentView: some View {
        ZStack {
            VStack {
                WordleGridView(grid: grid, shake: $shake)
                KeyboardView(
                    letters: keyboardLetters,
                    onKeyTap: handleKeyTap,
                    keyStates: keyStates,
                    isDisabled: gameOver
                )

                Spacer()

                Button("Logout") {
                    userManager.logout()
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
        }
        // Replace the alert code with:
        .alert(item: $gameResult) { result in
            Alert(title: Text(result == .win ? "You Win! 🎉" : "Game Over 😞"),
                  message: Text(result == .win ?
                      "Congratulations! You guessed the word!" :
                      "The word was: \(targetWord.uppercased())"),
                  dismissButton: .default(Text("New Game"), action: {
                      gameManager.forceReset()
                  }))
        }
        .onAppear {
            if let game = gameManager.currentGame {
                targetWord = game.word
                currentGameId = game.id
            }
            gameManager.listenToGameChanges()
        }
        // In ShwordleGameView's .onReceive modifier
        .onReceive(NotificationCenter.default.publisher(for: .didReceiveGameUpdateNotification)) { _ in
            print("🔔 Received game update notification")
            guard let game = gameManager.currentGame else {
                print("🔔 No current game, resetting")
                self.resetGame()
                return
            }

            self.updateGrid(with: game.moves)

            if game.status == "completed" && !self.showWinAlert {
                self.showWinAlert = true
                self.gameOver = true
            } else if game.status == "failed" && !self.showLoseAlert {
                self.showLoseAlert = true
                self.gameOver = true
            }
        }
        .onChange(of: gameManager.currentGame?.status) { newStatus in
            guard let status = newStatus else { return }
            gameOver = (status != "in_progress")
        }
        .onChange(of: gameManager.activeGameID) { newValue in
            if newValue != nil {
                showNewGameButton = false
                alertDismissed = false
                resetGame()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                gameManager.reloadActiveGame()
            }
        }
    }

    private func startNewGameWithValidation() {
        guard !newWordInput.isEmpty else { return }
        gameManager.forceReset()
        gameManager.createNewGame(word: newWordInput.lowercased())
        newWordInput = ""
        allowNewGameCreation = false
        resetGame()
    }

    private func determineTileState(guess: String, targetWord: String, position: Int) -> TileState {
        let guessLetters = Array(guess)
        let targetLetters = Array(targetWord)

        if guessLetters[position] == targetLetters[position] {
            return .correct
        }

        let remainingLetters = targetLetters.enumerated().filter {
            guessLetters[$0.offset] != targetLetters[$0.offset]
        }.map { $0.element }

        if remainingLetters.contains(guessLetters[position]) {
            return .misplaced
        }

        return .incorrect
    }

    // MARK: - UI Components

    private func resultAlert(title: String, message: String) -> some View {
        Color.black.opacity(0.4).ignoresSafeArea()
        return VStack {
            Text(title)
                .font(.title)
                .padding()
            Text(message)
                .font(.headline)
                .padding()

            if isLastPlayer {
                Button("Start New Game") {
                    alertDismissed = true
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("OK") {
                    alertDismissed = true
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(width: 300, height: 200)
        .background(.regularMaterial)
        .cornerRadius(12)
    }

    private func createNewGameIfValid() {
        print("🔄 Create new game validation started")
        guard validateNewWord() else {
            print("🚨 Validation failed")
            return
        }

        print("✅ Validation passed")
        gameManager.forceReset()
        gameManager.createNewGame(word: newWordInput.lowercased())

        newWordInput = ""
        resetGame()

        print("🔥 New game ID: \(gameManager.activeGameID ?? "nil")")
    }

    // MARK: - Input Handling

    private func validateNewWord() -> Bool {
        let newWord = newWordInput.trimmingCharacters(in: .whitespaces).lowercased()

        guard !newWord.isEmpty else {
            print("⚠️ Word cannot be empty")
            return false
        }

        guard newWord.count == 5 else {
            print("⚠️ Word must be 5 letters")
            return false
        }

        guard WordList.contains(newWord) else {
            print("⚠️ Not a valid word")
            return false
        }

        return true
    }

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
        guard currentRow < 6, currentColumn < 5 else { return }

        grid[currentRow][currentColumn] = (letter, .empty)
        currentColumn += 1

        if currentColumn == 5 {
            submitGuess()
        }

        print("✍️ Adding letter: \(letter) at row: \(currentRow), column: \(currentColumn)")
    }

    // MARK: - Game Logic

    private func submitGuess() {
        guard !gameOver,
              let game = gameManager.currentGame,
              game.status == "in_progress" else { return }

        let originalGuess = grid[currentRow].map { $0.letter }.joined()
        guard originalGuess.count == 5,
              WordList.contains(originalGuess.lowercased()) else {
            withAnimation { shake.toggle() }
            return
        }

        let targetWord = game.word.lowercased() // Use current game's word
        let guess = originalGuess.lowercased()
        let tempStates = calculateTileStates(guess: guess, targetWord: targetWord)

        DispatchQueue.main.async {
            self.updateRowStates(states: tempStates, guess: originalGuess)
        }

        let isCorrect = guess == targetWord
        let isLastRow = currentRow == 5

        gameManager.submitMove(guess: originalGuess) { success in
            guard success else { return }

            if isCorrect || isLastRow {
                gameManager.endGame(won: isCorrect, gameId: game.id)
                DispatchQueue.main.async {
                    self.showEndAlert(won: isCorrect, word: game.word)
                }
            } else {
                advanceToNextRow()
            }
        }
    }

    private func calculateTileStates(guess: String, targetWord: String) -> [TileState] {
        var states = Array(repeating: TileState.incorrect, count: 5)
        var remainingLetters = Array(targetWord)

        for i in 0 ..< 5 {
            let guessChar = guess[guess.index(guess.startIndex, offsetBy: i)]
            if guessChar == remainingLetters[i] {
                states[i] = .correct
                remainingLetters[i] = " "
            }
        }

        for i in 0 ..< 5 {
            guard states[i] != .correct else { continue }
            let guessChar = guess[guess.index(guess.startIndex, offsetBy: i)]

            if let index = remainingLetters.firstIndex(of: guessChar) {
                states[i] = .misplaced
                remainingLetters[index] = " "
            }
        }

        return states
    }

    private func updateRowStates(states: [TileState], guess: String) {
        for i in 0 ..< 5 {
            grid[currentRow][i].state = states[i]
        }
        updateKeyboardStates(for: guess)
    }

    private func showEndAlert(won: Bool, word: String) {
        gameResult = won ? .win : .lose
        gameOver = true
    }

    private func advanceToNextRow() {
        currentRow += 1
        currentColumn = 0
    }

    // MARK: - Firebase Integration

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
        guard let currentGame = gameManager.currentGame else { return }
        let targetWord = currentGame.word.lowercased()

        grid = Array(repeating: Array(repeating: ("", .empty), count: 5), count: 6)
        currentRow = 0
        currentColumn = 0

        for (row, move) in moves.enumerated() {
            guard row < 6 else { break }
            for (col, char) in move.guess.enumerated() {
                guard col < 5 else { break }
                let state = determineTileState(
                    guess: move.guess.lowercased(),
                    targetWord: targetWord,
                    position: col
                )
                grid[row][col] = (String(char), state)
            }
            currentRow += 1
        }
    }

    private func validateAndSetNewWord() {
        let newWord = newWordInput.trimmingCharacters(in: .whitespaces).lowercased()

        guard newWord.count == 5, WordList.contains(newWord) else {
            print("❌ Invalid word: \(newWord)")
            return
        }

        guard let oldGameId = gameManager.currentGame?.id else {
            gameManager.createNewGame(word: newWord)
            return
        }

        gameManager.endGame(won: false, gameId: oldGameId)

        gameManager.cleanupOldGame(gameId: oldGameId)

        DispatchQueue.main.async {
            self.gameManager.createNewGame(word: newWord)
        }

        newWordInput = ""
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
        print("🔄 Resetting game UI")
        grid = Array(repeating: Array(repeating: ("", .empty), count: 5), count: 6)
        currentRow = 0
        currentColumn = 0
        keyStates = [:]
        gameOver = false
        shake = false
    }
}

#Preview {
    ShwordleGameView()
        .environmentObject(UserManager.shared)
        .environmentObject(GameManager.shared)
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
