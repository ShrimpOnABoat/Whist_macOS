//
//  GM+IO.swift
//  Whist
//
//  Created by Tony Buffard on 2024-12-01.
//

import Foundation
import SwiftUI
import AppKit

extension Image {
    func asNSImage(size: CGSize = CGSize(width: 100, height: 100)) -> NSImage? {
        let hostingView = NSHostingView(rootView: self.resizable())
        hostingView.frame = CGRect(origin: .zero, size: size)

        let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds)
        hostingView.cacheDisplay(in: hostingView.bounds, to: rep!)
        let image = NSImage(size: size)
        image.addRepresentation(rep!)
        return image
    }
}

extension GameManager {
    
    struct PlayerIdentification: Codable {
        let id: PlayerId
        let username: String
        let imageData: Data?
    }

    // MARK: - handleReceivedAction
    
    func handleReceivedAction(_ action: GameAction) {
        logger.log("Handling action \(action.type) from \(action.playerId)")
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
                logger.log("Stored action \(action.type) from \(action.playerId) for later because currentPhase = \(self.gameState.currentPhase)")
            }
        }
    }
    
    func processAction(_ action: GameAction) {
        logger.log("Processing action \(action.type) from player \(action.playerId)...")
        switch action.type {
            
        case .id:
            guard let playerIdentification = try? JSONDecoder().decode(PlayerIdentification.self, from: action.payload) else {
                logger.log("Failed to decode player ID.")
                return
            }
            self.updatePlayerGCId(action.playerId, with: playerIdentification)
            
        case .seed:
            guard let seed = try? JSONDecoder().decode(UInt64.self, from: action.payload) else {
                logger.log("Failed to decode random seed.")
                return
            }
            randomSeed = seed

        case .playCard:
            guard let card = try? JSONDecoder().decode(Card.self, from: action.payload) else {
                logger.log("Failed to decode played card.")
                return
            }
            self.updateGameStateWithPlayedCard(from: action.playerId, with: card) {
                return
            }
            
        case .sendDeck:
            logger.log("Received deck from \(action.playerId).")
            self.updateDeck(with: action.payload)

        case .choseBet:
            if let bet = try? JSONDecoder().decode(Int.self, from: action.payload) {
                self.updateGameStateWithBet(from: action.playerId, with: bet)
            } else {
                logger.log("Failed to decode bet value.")
            }
            
        case .choseTrump:
            logger.log("Received trump")
            if let trumpCard = try? JSONDecoder().decode(Card.self, from: action.payload) {
                self.updateGameStateWithTrump(from: action.playerId, with: trumpCard)
            } else {
                logger.log("Failed to decode trump suit.")
            }
            
        case .cancelTrump:
            logger.log("Received cancellation of trump suit")
            // Do something only if last
            if gameState.localPlayer?.place == 3 {
                self.updateGameStateWithTrumpCancellation()
            }
            
        case .discard:
            logger.log("Received discard")
            if let discardedCards = try? JSONDecoder().decode([Card].self, from: action.payload) {
                self.updateGameStateWithDiscardedCards(from: action.playerId, with: discardedCards) {}
            } else {
                logger.log("Failed to decode discarded cards.")
            }
            
        case .sendState:
            if let state = try? JSONDecoder().decode(PlayerState.self, from: action.payload) {
                self.updatePlayerWithState(from: action.playerId, with: state)
            } else {
                logger.log("Failed to decode state.")
            }
            
        case .startNewGame:
            self.startNewGame()

        }
    }
    
    // MARK: - Send data
    
    func sendGCIdToPlayers() {
        guard let localPlayer = gameState.localPlayer else {
            logger.log("Local player not defined. Can't send PlayerIdentification.")
            return
        }
        
        let playerIdentification = PlayerIdentification(
            id: localPlayer.id,
            username: localPlayer.username,
            imageData: localPlayer.image?.asNSImage()?.tiffRepresentation
        )
        if let idData = try? JSONEncoder().encode(playerIdentification) {
            let action = GameAction(
                playerId: localPlayer.id,
                type: .id,
                payload: idData,
                timestamp: Date().timeIntervalSince1970
            )
            sendAction(action)
        } else {
            logger.log("Failed to encode PlayerIdentification.")
        }
    }
    
    func sendSeedToPlayers(_ seed: UInt64) {
        guard let localPlayerID = gameState.localPlayer?.id, localPlayerID == .toto else { return }

        if let seedData = try? JSONEncoder().encode(randomSeed) {
            let action = GameAction(
                playerId: localPlayerID,
                type: .seed,
                payload: seedData,
                timestamp: Date().timeIntervalSince1970
            )
            sendAction(action)
        } else {
            logger.log("Error: Failed to encode the random seed")
        }
    }

    
    func sendDeckToPlayers() {
        logger.log("Sending deck to players")
        // Ensure localPlayer is defined
        guard let localPlayer = gameState.localPlayer else {
            logger.log("Error: Local player is not defined")
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
            logger.log("Error: Failed to encode the deck cards")
        }
    }

    
    func sendPlayCardtoPlayers(_ card: Card) {
        logger.log("Sending play card \(card) to players")
        guard let localPlayer = gameState.localPlayer else {
            logger.log("Error: Local player is not defined")
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
            logger.log("Error: Failed to encode the card")
        }
    }
    
    func sendBetToPlayers(_ bet: Int) {
        logger.log("Sending bet \(bet) to players")
        guard let localPlayer = gameState.localPlayer else {
            logger.log("Error: Local player is not defined")
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
            logger.log("Error: Failed to encode the bet")
        }
    }
    
    func sendTrumpToPlayers(_ trump: Card) {
        logger.log("Sending trump \(trump) to players")
        guard let localPlayer = gameState.localPlayer else {
            logger.log("Error: Local player is not defined")
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
            logger.log("Error: Failed to encode the trump card")
        }
    }
    
    func sendDiscardedCards(_ discardedCards: [Card]) {
        logger.log("Sending discarded cards \(discardedCards) to players")
        guard let localPlayer = gameState.localPlayer else {
            logger.log("Error: Local player is not defined")
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
            logger.log("Error: Failed to encode the trump card")
        }
    }
    
    func sendStateToPlayers() {
        guard let localPlayer = gameState.localPlayer else {
            logger.log("Error: Local player is not defined")
            return
        }
        let state = localPlayer.state
        logger.log("Sending new state \(state.message) to players")
        
        if let state = try? JSONEncoder().encode(state) {
            let action = GameAction(
                playerId: localPlayer.id,
                type: .sendState,
                payload: state,
                timestamp: Date().timeIntervalSince1970
            )
            sendAction(action)
        } else {
            logger.log("Error: Failed to encode player's state")
        }
    }
    
    func sendStartNewGameAction() {
        logger.log("Sending start new game action to players")
        guard let localPlayer = gameState.localPlayer else { return }

        let action = GameAction(
            playerId: localPlayer.id,
            type: .startNewGame,
            payload: Data(),
            timestamp: Date().timeIntervalSince1970
        )
        sendAction(action)
    }
    
    func sendCancelTrumpChoice() {
        logger.log("Sending cancel trump choice action to players")
        guard let localPlayer = gameState.localPlayer else {
            logger.log("Error: Local player is not defined")
            return
        }
        
        let action = GameAction(
            playerId: localPlayer.id,
            type: .cancelTrump,
            payload: Data(),
            timestamp: Date().timeIntervalSince1970
        )
        sendAction(action)
    }
    
    func sendAction(_ action: GameAction) {
        if let actionData = try? JSONEncoder().encode(action) {
            gameKitManager?.sendData(actionData)
            logger.log("Sent action \(action.type) to other players")
        } else {
            logger.log("Failed to encode action")
        }
    }

}
