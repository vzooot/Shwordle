//
//  GameManager.swift
//  Shwordle
//
//  Created by Administrator on 2025-03-01.
//

import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging

class GameManager: ObservableObject {
    static let shared = GameManager()
    private let db = Firestore.firestore()

    @Published var currentGame: Game?
    @Published var activeGameID: String?

    @Published var lastGameResult: (word: String, winnerID: String)? = nil
    @Published var canStartNewGame: Bool = false

    private var gameListener: ListenerRegistration?
    private var movesListener: ListenerRegistration?

    struct Game: Codable, Identifiable {
        let id: String
        let word: String
        var players: [String]
        var status: String
        let createdAt: Date
        var moves: [Move]
        var lastPlayerId: String?
    }

    struct Move: Codable {
        let playerId: String
        let guess: String
        let timestamp: Date
    }

    // MARK: - Game Lifecycle

    func prepareForNewGame() {
        if activeGameID != nil {
            forceReset()
        }
    }

    func initializeGameSession() {
        listenForActiveGame()
    }

    func createNewGame(word: String) {
        // Reset state ONCE
        forceReset() // Handles activeGameID/currentGame cleanup
        lastGameResult = nil
        canStartNewGame = false

        print("🔄 Starting new game...")

        print("🔥 CREATE NEW GAME TRIGGERED")
        guard let userID = UserManager.shared.currentUser?.uid else {
            print("🚨 No user ID")
            return
        }
        guard WordList.contains(word) else {
            print("🚨 Word not in list: \(word)")
            return
        }
        guard word.count == 5 else {
            print("🚨 Invalid word length: \(word)")
            return
        }

        forceReset() // Critical: Clean previous game first

        let gameRef = db.collection("games").document()
        print("🔥 New game ID: \(gameRef.documentID)")

        let game = Game(
            id: gameRef.documentID,
            word: word.lowercased(),
            players: [userID],
            status: "in_progress",
            createdAt: Date(),
            moves: [],
            lastPlayerId: nil
        )

        do {
            try gameRef.setData(from: game)
            print("🔥 Firestore write succeeded")
            activeGameID = game.id
            currentGame = game
            listenToGameChanges() // Reconnect listeners
        } catch {
            print("🚨 Firestore write failed: \(error.localizedDescription)")
        }
    }

    func forceReset() {
        if let activeID = activeGameID {
            cleanupGame(gameId: activeID)
        }
        activeGameID = nil
        currentGame = nil
    }

    // Update cleanupGame
    func cleanupGame(gameId: String) {
        if activeGameID == gameId {
            gameListener?.remove()
            movesListener?.remove()
            activeGameID = nil
            currentGame = nil
            print("🔄 Cleaned up game \(gameId)")
        }
    }

    func endGame(won: Bool, gameId: String) {
        guard let game = currentGame else { return }
        
        // Capture last player from moves
        let lastPlayerId = game.moves.last?.playerId ?? ""
        print("🔑 Last player: \(lastPlayerId)")

        // Update Firestore
        db.collection("games").document(gameId).updateData([
            "status": won ? "completed" : "failed",
            "lastPlayerId": lastPlayerId
        ]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.lastGameResult = (game.word, lastPlayerId)
                self?.canStartNewGame = (lastPlayerId == UserManager.shared.currentUser?.uid)
                print("🚦 canStartNewGame: \(self?.canStartNewGame ?? false)")
            }
        }
    }

    // MARK: - Game Actions

    func listenForActiveGame() {
        gameListener?.remove()
        print("🔥 STARTED Listening for ACTIVE games")
        
        gameListener = db.collection("games")
            .whereField("status", isEqualTo: "in_progress")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self else { return }
                
                print("🔥 Found \(snapshot?.documents.count ?? 0) active games")
                
                guard let document = snapshot?.documents.first else {
                    print("🔥 No active games found")
                    return
                }
                
                do {
                    let game = try document.data(as: Game.self)
                    print("✅ Active game loaded: \(game.id)")
                    DispatchQueue.main.async {
                        self.activeGameID = game.id
                        self.currentGame = game
                    }
                } catch {
                    print("🚨 Error decoding active game: \(error)")
                }
            }
    }

    func submitMove(guess: String, completion: @escaping (Bool) -> Void) {
        guard let game = currentGame,
              let userID = UserManager.shared.currentUser?.uid,
              game.status == "in_progress" else {
            print("⚠️ Move rejected - invalid game state")
            completion(false)
            return
        }

        let move = Move(
            playerId: userID,
            guess: guess,
            timestamp: Date()
        )

        let db = Firestore.firestore()
        db.runTransaction { transaction, errorPointer in
            let gameRef = db.collection("games").document(game.id)
            guard let gameDoc = try? transaction.getDocument(gameRef),
                  let gameStatus = (try? gameDoc.data(as: Game.self))?.status,
                  gameStatus == "in_progress" else {
                errorPointer?.pointee = NSError(
                    domain: "GameError",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Game no longer active"]
                )
                return nil
            }

            let moveRef = gameRef.collection("moves").document()
            do {
                try transaction.setData(from: move, forDocument: moveRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            return moveRef.documentID
        } completion: { moveID, error in
            if let error = error {
                print("❌ Move submission failed: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ Move submitted successfully: \(moveID ?? "N/A")")
                self.sendNotifications()
                completion(true)
            }
        }
    }

    func cleanupOldGame(gameId: String) {
        db.collection("games").document(gameId).updateData([
            "players": FieldValue.arrayRemove([UserManager.shared.currentUser?.uid ?? ""])
        ])
    }

    func reloadActiveGame() {
        guard let gameID = activeGameID else { return }

        db.collection("games").document(gameID).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                print("Error reloading game: \(error)")
                return
            }

            guard let snapshot = snapshot, snapshot.exists else {
                print("Game document no longer exists")
                self.resetGame()
                return
            }

            do {
                let game = try snapshot.data(as: Game.self)
                DispatchQueue.main.async {
                    self.currentGame = game
                    self.listenToGameChanges()
                }
            } catch {
                print("Error decoding reloaded game: \(error)")
            }
        }
    }

    func resetGame() {
        guard let gameID = activeGameID else { return }

        cleanupGame(gameId: gameID)
        print("✅ Game state reset successfully")

        DispatchQueue.main.async {
            self.activeGameID = nil
            self.currentGame = nil
            NotificationCenter.default.post(name: .resetGameUI, object: nil)
        }
    }

    // MARK: - Real-time Updates

    func listenToGameChanges() {
        guard let gameID = currentGame?.id else { return }

        gameListener = db.collection("games").document(gameID)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    print("🚨 Game listener error: \(error)")
                    return
                }

                guard let snapshot = snapshot, snapshot.exists else {
                    print("🔥 Game document removed")
                    self.cleanupGame(gameId: gameID)
                    return
                }

                do {
                    let game = try snapshot.data(as: Game.self)
                    DispatchQueue.main.async {
                        self.currentGame = game

                        if game.status != "in_progress" {
                            print("🔔 Game ended. Resetting activeGameID")
                            self.activeGameID = nil // Clear active game
                            self.lastGameResult = (game.word, game.lastPlayerId ?? "")
                            self.canStartNewGame = (game.lastPlayerId == UserManager.shared.currentUser?.uid)
                        }
                    }
                } catch {
                    print("🚨 Game decoding error: \(error)")
                }
            }

        // Moves subcollection listener
        movesListener = db.collection("games").document(gameID)
            .collection("moves").order(by: "timestamp")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("🚨 Moves listener error: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                let moves = documents.compactMap { doc in
                    try? doc.data(as: Move.self)
                }

                print("✅ Received \(moves.count) moves")
                DispatchQueue.main.async {
                    self?.currentGame?.moves = moves
                    NotificationCenter.default.post(
                        name: .didReceiveGameUpdateNotification,
                        object: nil
                    )
                }
            }
    }

    // MARK: - Notifications

    private func sendNotifications() {
        guard let game = currentGame else { return }

        game.players.forEach { playerID in
            db.collection("users").document(playerID).getDocument { [weak self] snapshot, _ in
                guard let tokens = snapshot?.get("fcmTokens") as? [String] else { return }
                self?.sendPushNotification(tokens: tokens, gameId: game.id)
            }
        }
    }

    private func sendPushNotification(tokens: [String], gameId: String) {}
}
