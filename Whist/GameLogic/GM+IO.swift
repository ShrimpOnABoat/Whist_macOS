//
//  GM+IO.swift
//  Whist
//
//  Created by Tony Buffard on 2024-12-01.
//

import Foundation
import SwiftUI

extension GameManager {
    // MARK: - Subscription Setup
    func setupSubscriptions() {
        gameState.$players
            .receive(on: DispatchQueue.main)
            .sink { [weak self] players in
                guard let self = self else { return }
                
                print("Updated players: \(players.map { $0.username })")

                let totalPlayers = self.gameState.players.count
                let connectedPlayers = self.gameState.players.filter { $0.connected }.count
                print("setupSubscriptions - Total players created: \(totalPlayers), Players connected: \(connectedPlayers)")
                
                // Proceed only if all players have connected
                let expectedNumberOfPlayers: Int = 3
                guard players.count >= expectedNumberOfPlayers,
                      players.allSatisfy({ $0.connected }) else {
                    print("Waiting for all players to connect...")
                    return
                }

                self.setupGame()
                self.checkAndAdvanceStateIfNeeded()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - ConnectionManagerDelegate Method
    
    func handleReceivedAction(_ action: GameAction) {
        DispatchQueue.main.async {
            // Check if the action is valid for the current phase
            if self.isActionValidInCurrentPhase(action.type) {
                self.processAction(action)
            } else {
                // Store the action for later
                self.pendingActions.append(action)
                print("Stored action \(action.type) for later because currentPhase = \(self.currentPhase)")
            }
        }
    }
    
    func processAction(_ action: GameAction) {
        switch action.type {
        case .playCard:
            guard let card = try? JSONDecoder().decode(Card.self, from: action.payload) else {
                print("Failed to decode played card.")
                return
            }
            withAnimation(.easeOut(duration: 0.5)) {
                self.updateGameStateWithPlayedCard(from: action.playerId, with: card)
            }
            self.checkAndAdvanceStateIfNeeded()
            
        case .sendDeck:
            self.updateDeck(with: action.payload)

        case .choseBet:
            if let bet = try? JSONDecoder().decode(Int.self, from: action.payload) {
                self.updateGameStateWithBet(from: action.playerId, with: bet)
            } else {
                print("Failed to decode bet value.")
            }

        case .choseTrump:
            print("Received trump")
            // Process trump selection

        case .discard:
            print("Received discard")
            // Process discard
        }
    }
    
    // MARK: - Send data
    
    func sendDeckToPlayers() {
        print("Sending deck to players")
        // Ensure localPlayer is defined
        guard let localPlayer = gameState.localPlayer else {
            print("Error: Local player is not defined")
            return
        }
        
        // Encode the filtered deck and create the action
        if let deckData = try? JSONEncoder().encode(gameState.deck) {
            let action = GameAction(
                playerId: localPlayer.id,
                type: .sendDeck,
                payload: deckData,
                timestamp: Date().timeIntervalSince1970
            )
            sendAction(action)
        } else {
            print("Error: Failed to encode the deck cards")
        }
    }

    
    func sendPlayCardtoPlayers(_ card: Card) {
        print("Sending play card \(card) to players")
        guard let localPlayer = gameState.localPlayer else {
            print("Error: Local player is not defined")
            return
        }
        
        if let cardData = try? JSONEncoder().encode(card) {
            let action = GameAction(
                playerId: localPlayer.id,
                type: .playCard,
                payload: cardData,
                timestamp: Date().timeIntervalSince1970
            )
            sendAction(action)
        } else {
            print("Error: Failed to encode the card")
        }
    }
    
    func sendBetToPlayers(_ bet: Int) {
        print("Sending bet \(bet) to players")
        guard let localPlayer = gameState.localPlayer else {
            print("Error: Local player is not defined")
            return
        }
        
        if let betData = try? JSONEncoder().encode(bet) {
            let action = GameAction(
                playerId: localPlayer.id,
                type: .choseBet,
                payload: betData,
                timestamp: Date().timeIntervalSince1970
            )
            sendAction(action)
        } else {
            print("Error: Failed to encode the bet")
        }
    }
    
    func sendTrumpToPlayers(_ trump: Card) {
        print("Sending trump \(trump) to players")
        guard let localPlayer = gameState.localPlayer else {
            print("Error: Local player is not defined")
            return
        }
        
        if let trumpData = try? JSONEncoder().encode(trump) {
            let action = GameAction(
                playerId: localPlayer.id,
                type: .choseTrump,
                payload: trumpData,
                timestamp: Date().timeIntervalSince1970
            )
            sendAction(action)
        } else {
            print("Error: Failed to encode the trump card")
        }
    }
    
    func sendAction(_ action: GameAction) {
        if let actionData = try? JSONEncoder().encode(action) {
            connectionManager?.sendData(actionData)
            print("Sent action \(action.type) to other players")
        } else {
            print("Failed to encode action")
        }
    }
    
    func syncPlayersFromConnections(_ connectedPeers: [PeerConnection]) {
        var connectedPlayerIDs = connectedPeers.compactMap { $0.playerID }
        print("--> Connected players: \(connectedPlayerIDs)")
        
        // Add the local player since they're always "connected" by definition
        if let localPlayerID = connectionManager?.localPlayerID {
            connectedPlayerIDs.append(localPlayerID)
        }
        print("--> Connected players: \(connectedPlayerIDs)")

        for (index, player) in gameState.players.enumerated() {
            let wasConnected = player.connected
            let isConnected = connectedPlayerIDs.contains(player.id)
            
            // Update the player connected status by replacing it in the array (if Player is a class this might not be needed, but it's safer)
            if wasConnected != isConnected {
                gameState.players[index].connected = isConnected
                print("Player \(gameState.players[index].id) is updated to \(gameState.players[index].connected ? "connected" : "disconnected")")
            } else {
                print("Player \(gameState.players[index].id) stays \(gameState.players[index].connected ? "connected" : "disconnected")")
            }
        }

        // Force update
        self.objectWillChange.send()
        
        checkAndAdvanceStateIfNeeded()
    }
}
