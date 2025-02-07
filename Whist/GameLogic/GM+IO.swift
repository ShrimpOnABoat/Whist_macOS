//
//  GM+IO.swift
//  Whist
//
//  Created by Tony Buffard on 2024-12-01.
//

import Foundation
import SwiftUI

extension GameManager {
    
    // MARK: - handleReceivedAction
    
    func handleReceivedAction(_ action: GameAction) {
        DispatchQueue.main.async {
            // Check if the action is valid for the current phase
            if self.isActionValidInCurrentPhase(action.type) {
                self.processAction(action)
                if action.type != .sendState {
                    self.checkAndAdvanceStateIfNeeded()
                }
            } else {
                // Store the action for later
                self.pendingActions.append(action)
                logWithTimestamp("Stored action \(action.type) from \(action.playerId) for later because currentPhase = \(self.gameState.currentPhase)")
            }
        }
    }
    
    func processAction(_ action: GameAction) {
        logWithTimestamp("Processing action \(action.type) from player \(action.playerId)...")
        switch action.type {
        case .playCard:
            guard let card = try? JSONDecoder().decode(Card.self, from: action.payload) else {
                logWithTimestamp("Failed to decode played card.")
                return
            }
            self.updateGameStateWithPlayedCard(from: action.playerId, with: card) {
//                self.checkAndAdvanceStateIfNeeded()
                return
            }
            
        case .sendDeck:
            logWithTimestamp("Received deck from \(action.playerId).")
            self.updateDeck(with: action.payload)

        case .choseBet:
            if let bet = try? JSONDecoder().decode(Int.self, from: action.payload) {
                self.updateGameStateWithBet(from: action.playerId, with: bet)
            } else {
                logWithTimestamp("Failed to decode bet value.")
            }
            
        case .choseTrump:
            logWithTimestamp("Received trump")
            if let trumpCard = try? JSONDecoder().decode(Card.self, from: action.payload) {
                self.updateGameStateWithTrump(from: action.playerId, with: trumpCard)
            } else {
                logWithTimestamp("Failed to decode trump suit.")
            }
            
        case .discard:
            logWithTimestamp("Received discard")
            if let discardedCards = try? JSONDecoder().decode([Card].self, from: action.payload) {
                self.updateGameStateWithDiscardedCards(from: action.playerId, with: discardedCards) {}
            } else {
                logWithTimestamp("Failed to decode discarded cards.")
            }
            
        case .sendState:
//            logWithTimestamp("Received state")
            if let state = try? JSONDecoder().decode(PlayerState.self, from: action.payload) {
                self.updatePlayerWithState(from: action.playerId, with: state)
            } else {
                logWithTimestamp("Failed to decode discarded cards.")
            }
            
        case .startNewGame:
            self.startNewGame()

        }
    }
    
    // MARK: - Send data
    
    func sendDeckToPlayers() {
        logWithTimestamp("Sending deck to players")
        // Ensure localPlayer is defined
        guard let localPlayer = gameState.localPlayer else {
            logWithTimestamp("Error: Local player is not defined")
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
            logWithTimestamp("Error: Failed to encode the deck cards")
        }
    }

    
    func sendPlayCardtoPlayers(_ card: Card) {
        logWithTimestamp("Sending play card \(card) to players")
        guard let localPlayer = gameState.localPlayer else {
            logWithTimestamp("Error: Local player is not defined")
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
            logWithTimestamp("Error: Failed to encode the card")
        }
    }
    
    func sendBetToPlayers(_ bet: Int) {
        logWithTimestamp("Sending bet \(bet) to players")
        guard let localPlayer = gameState.localPlayer else {
            logWithTimestamp("Error: Local player is not defined")
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
            logWithTimestamp("Error: Failed to encode the bet")
        }
    }
    
    func sendTrumpToPlayers(_ trump: Card) {
        logWithTimestamp("Sending trump \(trump) to players")
        guard let localPlayer = gameState.localPlayer else {
            logWithTimestamp("Error: Local player is not defined")
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
            logWithTimestamp("Error: Failed to encode the trump card")
        }
    }
    
    func sendDiscardedCards(_ discardedCards: [Card]) {
        logWithTimestamp("Sending discarded cards \(discardedCards) to players")
        guard let localPlayer = gameState.localPlayer else {
            logWithTimestamp("Error: Local player is not defined")
            return
        }
        
        if let discardedCardsData = try? JSONEncoder().encode(discardedCards) {
            let action = GameAction(
                playerId: localPlayer.id,
                type: .discard,
                payload: discardedCardsData,
                timestamp: Date().timeIntervalSince1970
            )
            sendAction(action)
        } else {
            logWithTimestamp("Error: Failed to encode the trump card")
        }
    }
    
    func sendStateToPlayers() {
        guard let localPlayer = gameState.localPlayer else {
            logWithTimestamp("Error: Local player is not defined")
            return
        }
        let state = localPlayer.state
//        logWithTimestamp("Sending new state \(state.message) to players")
        
        if let state = try? JSONEncoder().encode(state) {
            let action = GameAction(
                playerId: localPlayer.id,
                type: .sendState,
                payload: state,
                timestamp: Date().timeIntervalSince1970
            )
            sendAction(action)
        } else {
            logWithTimestamp("Error: Failed to encode player's state")
        }
    }
    
    func sendStartNewGameAction() {
        logWithTimestamp("Sending start new game action to players")
        guard let localPlayer = gameState.localPlayer else { return }

        let action = GameAction(
            playerId: localPlayer.id,
            type: .startNewGame,
            payload: Data(),
            timestamp: Date().timeIntervalSince1970
        )
        sendAction(action)
    }
    
    func sendAction(_ action: GameAction) {
        if let actionData = try? JSONEncoder().encode(action) {
            connectionManager?.sendData(actionData)
//            logWithTimestamp("Sent action \(action.type) to other players")
        } else {
            logWithTimestamp("Failed to encode action")
        }
    }
    
    func syncPlayersFromConnections(_ connectedPeers: [PeerConnection]) {
        var connectedPlayerIDs = connectedPeers.compactMap { $0.playerID }
        logWithTimestamp("--> Connected players: \(connectedPlayerIDs)")
        
        // Add the local player since they're always "connected" by definition
        if let localPlayerID = connectionManager?.localPlayerID {
            connectedPlayerIDs.append(localPlayerID)
        }
        logWithTimestamp("--> Connected players: \(connectedPlayerIDs)")

        for (index, player) in gameState.players.enumerated() {
            let wasConnected = player.connected
            let isConnected = connectedPlayerIDs.contains(player.id)
            
            // Update the player connected status by replacing it in the array (if Player is a class this might not be needed, but it's safer)
            if wasConnected != isConnected {
                gameState.players[index].connected = isConnected
                logWithTimestamp("Player \(gameState.players[index].id) is updated to \(gameState.players[index].connected ? "connected" : "disconnected")")
            } else {
                logWithTimestamp("Player \(gameState.players[index].id) stays \(gameState.players[index].connected ? "connected" : "disconnected")")
            }
        }

        // Force update
        self.objectWillChange.send()
        
//        checkAndAdvanceStateIfNeeded()
    }
}
