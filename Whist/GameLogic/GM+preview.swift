//
//  GameManager+communication.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-30.
//

import Foundation
import SwiftUI

extension GameManager {
    // MARK: - Preview Setup

    func setupPreviewGameState() {
        // Create players
        gameState.players = [
            Player(id: .dd, username: "dd", image: Image(systemName: "figure.pool.swim.circle.fill")),
            Player(id: .gg, username: "gg", image: Image(systemName: "safari.fill")),
            Player(id: .toto, username: "toto", image: Image(systemName: "figure.run.treadmill.circle.fill"))
        ]
        
        // Assign local and adjacent players
        guard gameState.players.count >= 3 else {
            fatalError("Not enough players in the preview game state.")
        }

        gameState.playOrder = [.dd, .gg, .toto]
        
        gameState.updatePlayerReferences(for: gameState.players[0].id)
        
        gameState.round = 7
        
        isGameSetup = true
        
        gameState.players[0].connected = false
        
        // Initialize positions based on standard preview dimensions
        initializeCards()
        
        // Assign hands to players
        assignHandsForPreview()
        
        // Set up trick cards
        setupTrickCardsForPreview()
        
        // Set up player tricks
        setupPlayerTricksForPreview()
        
        // Set trump card
        gameState.trumpSuit = gameState.deck[gameState.deck.count - 1].suit

        // Additional setup (scores, actions, etc.) if needed
        setupAdditionalPlayerInfoForPreview()
    }
    
    func assignHandsForPreview() {
        let cardsPerPlayer = 5
        gameState.deck.shuffle()

        for player in gameState.players {
            for _ in 0..<cardsPerPlayer {
                guard !gameState.deck.isEmpty else {
                    fatalError("Deck is empty while assigning hands.")
                }
                if let card = gameState.deck.last {
                    gameState.moveCardPreview(from: &gameState.deck, to: &player.hand, card: card)
                    if (player.id == .dd) { // localPlayer
                        card.isFaceDown = false
                    }
                }
            }
        }
        print("Hands assigned: Deck has \(gameState.deck.count) cards left.")
    }

    func setupTrickCardsForPreview() {
        for player in gameState.players {

            let card = player.hand.popLast()!
            gameState.table.append(card)
            card.isFaceDown = false
        }
        print("Trick cards set up: Table has \(gameState.table.count) entries.")
    }
    
    func setupPlayerTricksForPreview() {
        // one trick for dd
        if let card = gameState.deck.last {gameState.moveCardPreview(from: &gameState.deck, to: &gameState.players[0].trickCards, card: card)}
        if let card = gameState.deck.last {gameState.moveCardPreview(from: &gameState.deck, to: &gameState.players[0].trickCards, card: card)}
        if let card = gameState.deck.last {gameState.moveCardPreview(from: &gameState.deck, to: &gameState.players[0].trickCards, card: card)}
        if let card = gameState.deck.last {gameState.moveCardPreview(from: &gameState.deck, to: &gameState.players[0].trickCards, card: card)}
        if let card = gameState.deck.last {gameState.moveCardPreview(from: &gameState.deck, to: &gameState.players[0].trickCards, card: card)}
        if let card = gameState.deck.last {gameState.moveCardPreview(from: &gameState.deck, to: &gameState.players[0].trickCards, card: card)}
        // two tricks for gg
        if let card = gameState.deck.last {gameState.moveCardPreview(from: &gameState.deck, to: &gameState.players[1].trickCards, card: card)}
        if let card = gameState.deck.last {gameState.moveCardPreview(from: &gameState.deck, to: &gameState.players[1].trickCards, card: card)}
        if let card = gameState.deck.last {gameState.moveCardPreview(from: &gameState.deck, to: &gameState.players[1].trickCards, card: card)}
        if let card = gameState.deck.last {gameState.moveCardPreview(from: &gameState.deck, to: &gameState.players[1].trickCards, card: card)}
        if let card = gameState.deck.last {gameState.moveCardPreview(from: &gameState.deck, to: &gameState.players[1].trickCards, card: card)}
        if let card = gameState.deck.last {gameState.moveCardPreview(from: &gameState.deck, to: &gameState.players[1].trickCards, card: card)}
        
    }
    
    func setupAdditionalPlayerInfoForPreview() {
        // Set scores
        gameState.players[0].scores = [10, 25, 30, 50, 40, 30, 75]
        gameState.players[1].scores = [5, 20, 35, 60, 70, 100, 125]
        gameState.players[2].scores = [-10, -20, 25, 70, 45, 40, 80]

        // Announced and made tricks
        gameState.players[0].announcedTricks = [0, 0, 0, 1, 2, 1, 2]
        gameState.players[0].madeTricks = [0, 0, 1, 2, 3, 1, 2]
        gameState.players[1].announcedTricks = [1, 0, 1, 0, 0, 2, 1]
        gameState.players[1].madeTricks = [1, 0, 1, 0, 0, 2, 2]
        gameState.players[2].announcedTricks = [0, 1, 0, 1, 3, 2, 0]
        gameState.players[2].madeTricks = [0, 1, 0, 2, 3, 0, 0]

        // Connected status
        gameState.players[0].connected = true
        gameState.players[1].connected = true
        gameState.players[2].connected = true

        // Dealer
        gameState.dealer = .toto
        
        updatePlayersPositions()
    }

}
