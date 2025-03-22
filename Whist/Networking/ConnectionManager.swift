// ConnectionManager.swift
// Whist
//
// Created by Tony Buffard on 2024-11-18.
// Manages data transmission between players.

import Foundation
import SwiftUI

import GameKit

enum TestModeMessageType: String, Codable {
    case playerConnected
    case playerDisconnected
}

struct TestModeMessage: Codable {
    let type: TestModeMessageType
    let playerID: PlayerId
}

class ConnectionManager: NSObject, ObservableObject {
    weak var gameManager: GameManager?
    @Published private(set) var localPlayerID: PlayerId?
    
    @Published var match: GKMatch?
    
    override init() {
        super.init()
    }
    
    // MARK: - Test Mode Networking (Sockets)
    
    func setLocalPlayerID(_ playerID: PlayerId) {
        self.localPlayerID = playerID
        logger.log("Local player ID set to: \(playerID.rawValue)")
    }
    
    // MARK: - Data Transmission
    
    func sendData(_ data: Data) {
        // GameKit implementation: send data to all players reliably.
        guard let match = self.match else {
            logger.log("No active GameKit match to send data.")
            return
        }
        do {
            try match.sendData(toAllPlayers: data, with: .reliable)
            logger.log("Data sent via GameKit.")
        } catch {
            logger.log("Error sending data via GameKit: \(error)")
        }
    }
    
    // MARK: - GameKit Match Configuration
    
    func configureMatch(_ match: GKMatch) {
        self.match = match
        logger.log("Configuring match with \(match.players.count) remote players")
        
        // Process remote players
        for player in match.players {
            let playerID = GCPlayerIdAssociation[player.displayName, default: .dd]
            processRemotePlayer(player, playerID: playerID)
        }
        
        // When all players are processed, check and advance game state
        if match.players.isEmpty {
            gameManager?.checkAndAdvanceStateIfNeeded()
        }
    }
    
    private func processRemotePlayer(_ player: GKPlayer, playerID: PlayerId) {
        player.loadPhoto(for: .normal) { [weak self] image, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    logger.log("Error loading photo for \(player.displayName): \(error)")
                }
                
                // Update the player with the image (nil is fine)
                self.gameManager?.updatePlayer(playerID, name: player.displayName, image: image)
                
                // Check if all players are now processed
                if self.areAllPlayersProcessed() {
                    logger.log("All players processed, advancing game state")
                    self.gameManager?.checkAndAdvanceStateIfNeeded()
                }
            }
        }
    }

    private func areAllPlayersProcessed() -> Bool {
        // Check if all expected players are in the game state and connected
        guard let match = self.match else { return false }
        let expectedPlayerCount = match.players.count + 1 // including local player
        
        return gameManager?.gameState.players.filter { $0.isConnected }.count == expectedPlayerCount
    }

    
    func handleReceivedGameKitData(_ data: Data, from player: GKPlayer) {
        logger.log("Received some data from \(player.displayName)")
        // Attempt to decode a GameAction (or other message) from the received data
        do {
            let action = try JSONDecoder().decode(GameAction.self, from: data)
            DispatchQueue.main.async {
                logger.log("Received action \(action.type) from \(player.displayName)")
                self.gameManager?.handleReceivedAction(action)
            }
        } catch {
            logger.log("Failed to decode GameAction from GameKit data: \(error)")
        }
    }
    
    func handleMatchFailure(error: Error?) {
        logger.log("Match failed with error: \(error?.localizedDescription ?? "Unknown error")")
        
        // Handle any cleanup or UI updates needed
        self.match = nil
    }
    
    func updatePlayerConnectionStatus(playerID: PlayerId, isConnected: Bool) {
        logger.log("Player \(playerID.rawValue) disconnected")
        // Update player connection status in game manager
        gameManager?.updatePlayerConnectionStatus(playerID: playerID, isConnected: isConnected)
    }
}

protocol ConnectionManagerDelegate: AnyObject {
    func handleReceivedAction(_ action: GameAction)
}
