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
    // ADD: Constant for the document ID
    private let currentGameStateDocumentId = "current"
    private let gameStatesCollection = "gameStates"
    private let scoresCollection = "scores"

    // MARK: - GameState

    func saveGameState(_ state: GameState) async throws {
        // CHANGE: Use constants for collection and document ID
        try db.collection(gameStatesCollection)
            .document(currentGameStateDocumentId)
            .setData(from: state)
    }

    func loadGameState() async throws -> GameState {
        // CHANGE: Use constants for collection and document ID
        let snapshot = try await db.collection(gameStatesCollection)
            .document(currentGameStateDocumentId)
            .getDocument()
        return try snapshot.data(as: GameState.self)
    }

    // ADD: Function to delete the current game state document
    func deleteCurrentGameState() async throws {
        try await db.collection(gameStatesCollection)
            .document(currentGameStateDocumentId)
            .delete()
        logger.log("Successfully deleted game state document: \(currentGameStateDocumentId)")
    }

    // MARK: - GameScore

    func saveGameScore(_ score: GameScore) async throws {
        let id = score.id.uuidString
        // CHANGE: Use constant for collection
        try db.collection(scoresCollection)
            .document(id)
            .setData(from: score)
    }

    func loadAllScores() async throws -> [GameScore] {
        // CHANGE: Use constant for collection
        let snapshot = try await db.collection(scoresCollection)
            .order(by: "date", descending: true)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: GameScore.self) }
    }
}
