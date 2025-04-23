//
//  FirebaseService.swift
//  Whist
//
//  Created by Tony Buffard on 2025-04-19.
//


// FirebaseService.swift
// Handles all Firebase read/write operations for game state and score history.

import Foundation
import FirebaseFirestore

class FirebaseService {
    static let shared = FirebaseService()
    private let db = Firestore.firestore()

    // MARK: - GameState

    func saveGameState(_ state: GameState) async throws {
        try db.collection("gameStates")
            .document("current")
            .setData(from: state)
    }

    func loadGameState() async throws -> GameState {
        let snapshot = try await db.collection("gameStates")
            .document("current")
            .getDocument()
        return try snapshot.data(as: GameState.self)
    }

    // MARK: - GameScore

    func saveGameScore(_ score: GameScore) async throws {
        let id = score.id.uuidString
        try db.collection("scores")
            .document(id)
            .setData(from: score)
    }

    func loadAllScores() async throws -> [GameScore] {
        let snapshot = try await db.collection("scores")
            .order(by: "date", descending: true)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: GameScore.self) }
    }
}
