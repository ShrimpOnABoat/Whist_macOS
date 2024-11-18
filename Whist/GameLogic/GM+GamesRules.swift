//
//  GM+GameRules.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Contains the game logic and rules.

//import Foundation
//
//extension GameManager {
//    func isMoveLegal(playerId: PlayerId, card: Card) -> Bool {
//        // Check if the player exists
//        let player = gameState.getPlayer(by: playerId)
//        
//        // Check if the card is in the player's hand
//        guard player.hand.contains(card) else {
//            print("Illegal move: Card \(card) is not in the player's hand.")
//            return false
//        }
//        
//        // Check if it's the player's turn
//        guard let currentTurn = gameState.playOrder.first(where: { gameState.table[$0] == nil }) else {
//            print("Illegal move: No empty spot in the play order, the turn sequence is invalid.")
//            return false
//        }
//        
//        if currentTurn != playerId {
//            print("Illegal move: It's not player \(playerId.rawValue)'s turn.")
//            return false
//        }
//        
//        // If the table is empty, the move is always legal
//        if gameState.table.isEmpty {
//            return true
//        }
//        
//        // If there is a leading card on the table, check suit-following rules
//        if let leadingCard = gameState.playOrder
//            .drop(while: { gameState.table[$0] == nil }) // Skip players who haven't played
//            .compactMap({ gameState.table[$0] })         // Extract non-nil cards
//            .first {
//            let leadingSuit = leadingCard.suit
//            if card.suit != leadingSuit {
//                // The player must follow the leading suit if possible
//                let hasMatchingSuit = player.hand.contains { $0.suit == leadingSuit }
//                if hasMatchingSuit {
//                    print("Illegal move: Player \(playerId.rawValue) must follow suit \(leadingSuit).")
//                    return false
//                }
//            }
//        }
//        
//        // All conditions satisfied; the move is legal
//        return true
//    }
//}
