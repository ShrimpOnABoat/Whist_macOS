//
//  GameBackupManager.swift
//  Whist
//
//  Created by Tony Buffard on 2025-01-21.
//

import Foundation

class GamePersistence {
    private let playerID: PlayerId
    private let fileURL: URL

    init(playerID: PlayerId) {
        self.playerID = playerID
        let fileManager = FileManager.default
        if let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            self.fileURL = documentDirectory.appendingPathComponent("gameState_\(playerID).json")
        } else {
            fatalError("Unable to access document directory")
        }
    }

    func saveGameState(_ state: GameState) {
        do {
            let encodedData = try JSONEncoder().encode(state)
            try encodedData.write(to: fileURL)
//            logger.log("State saved in \(fileURL.path)")
        } catch {
            logger.log("Error saving game state to file: \(error.localizedDescription)")
        }
    }

    func loadGameState() -> GameState? {
        do {
            let data = try Data(contentsOf: fileURL)
            let decodedState = try JSONDecoder().decode(GameState.self, from: data)
//            logger.log("Game state loaded from: \(fileURL.path)")
            return decodedState
        } catch {
            logger.log("Error loading game state from file: \(error.localizedDescription)")
            return nil
        }
    }

    func clearSavedGameState() {
        let fileManager = FileManager.default
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
//                logger.log("Cleared saved game state for player: \(playerID)")
            }
        } catch {
            logger.log("Error clearing saved game state: \(error.localizedDescription)")
        }
    }
}

