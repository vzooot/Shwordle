//
//  GameManager.swift
//  Shwordle
//
//  Created by Administrator on 2025-03-01.
//

import FirebaseFirestore

class GameManager: ObservableObject {
    static let shared = GameManager()
    private let db = Firestore.firestore()
    
    @Published var currentGame: Game? // Use @Published
    
    struct Game: Codable, Identifiable {
        let id: String
        let word: String
        let players: [String]
        var moves: [Move]
    }
    
    struct Move: Codable {
        let playerId: String
        let guess: String
        let timestamp: Date
    }
    
    func createGame(word: String) {
        guard let user = UserManager.shared.currentUser else { return }
        let gameRef = db.collection("games").document()
        
        let game = Game(
            id: gameRef.documentID,
            word: word.lowercased(),
            players: [user.uid],
            moves: []
        )
        
        do {
            try gameRef.setData(from: game)
            currentGame = game
            listenToGameChanges()
        } catch {
            print("Error creating game: \(error)")
        }
    }
    
    func listenToGameChanges() {
        guard let gameId = currentGame?.id else { return }
        
        db.collection("games").document(gameId)
            .addSnapshotListener { document, error in
                guard let document = document else { return }
                self.currentGame = try? document.data(as: Game.self)
            }
        
        db.collection("games").document(gameId)
            .collection("moves").order(by: "timestamp")
            .addSnapshotListener { querySnapshot, error in
                guard let documents = querySnapshot?.documents else { return }
                self.currentGame?.moves = documents.compactMap { try? $0.data(as: Move.self) }
            }
    }
    
    func submitMove(guess: String) {
        guard let game = currentGame, let user = UserManager.shared.currentUser else { return }
        
        let move = Move(
            playerId: user.uid,
            guess: guess.lowercased(),
            timestamp: Date()
        )
        
        do {
            try db.collection("games").document(game.id)
                .collection("moves").addDocument(from: move)
            sendNotifications()
        } catch {
            print("Error submitting move: \(error)")
        }
    }
    
    private func sendNotifications() {
        guard let game = currentGame else { return }
        
        let players = game.players.filter { $0 != UserManager.shared.currentUser?.uid }
        let db = Firestore.firestore()
        
        db.collection("users").whereField("uid", in: players).getDocuments { snapshot, _ in
            snapshot?.documents.forEach { document in
                guard let tokens = document.get("fcmTokens") as? [String] else { return }
                self.sendPushNotification(tokens: tokens, gameId: game.id)
            }
        }
    }
    
    private func sendPushNotification(tokens: [String], gameId: String) {
        let url = URL(string: "https://fcm.googleapis.com/fcm/send")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("key=YOUR_SERVER_KEY", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = [
            "registration_ids": tokens,
            "notification": [
                "title": "New Move!",
                "body": "Your opponent made a move",
                "sound": "default"
            ],
            "data": [
                "gameId": gameId
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        URLSession.shared.dataTask(with: request).resume()
    }
}
