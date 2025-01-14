//
//  GM+UI.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-30.
//

import Foundation
import SwiftUI

struct CardState: Equatable {
    var position: CGPoint
    var rotation: Double
    var scale: CGFloat
}

// MARK: - CardPlace

enum CardPlace {
    case localPlayer
    case leftPlayer
    case rightPlayer
    case localPlayerTricks
    case leftPlayerTricks
    case rightPlayerTricks
    case table
    case deck
    case trumpDeck
}

extension GameManager {
    
    func onDeckMeasured() {
        // If we’re in .renderingDeck, flip the flag and check the state
        guard currentPhase == .renderingDeck else { return }
        
        isDeckReady = true
        checkAndAdvanceStateIfNeeded()
    }

    func beginBatchMove(totalCards: Int, completion: @escaping () -> Void) {
        animationQueue.append((totalCards, completion))
        processAnimationQueue()
    }

    private func processAnimationQueue() {
        guard activeAnimations == 0, !animationQueue.isEmpty else {
            return
        }

        let (totalCards, completion) = animationQueue.removeFirst()
        activeAnimations = totalCards
        onBatchAnimationsCompleted.append( {
            completion()
            self.onBatchAnimationsCompleted.removeFirst()
            self.processAnimationQueue()
        } )
    }
    
    // MARK: moveCard
    
    // Function to initiate card movement
    func moveCard(_ card: Card, from source: CardPlace, to destination: CardPlace) {
//        print("Moving \(card) from \(source) to \(destination)")
        // Add a placeholder to the destination with a unique identifier
        let placeholderCard = Card(suit: card.suit, rank: card.rank, isPlaceholder: true)
        placeholderCard.rotation = card.rotation
        placeholderCard.offset = card.offset
        placeholderCard.randomOffset = card.randomOffset
        placeholderCard.randomAngle = card.randomAngle
        
        switch destination {
        case .localPlayer:
            gameState.localPlayer?.hand.append(placeholderCard)
        case .leftPlayer:
            gameState.leftPlayer?.hand.append(placeholderCard)
        case .rightPlayer:
            gameState.rightPlayer?.hand.append(placeholderCard)
        case .localPlayerTricks:
            gameState.localPlayer?.trickCards.append(placeholderCard)
        case .leftPlayerTricks:
            gameState.leftPlayer?.trickCards.append(placeholderCard)
        case .rightPlayerTricks:
            gameState.rightPlayer?.trickCards.append(placeholderCard)
        case .table:
            gameState.table.append(placeholderCard)
        case .deck:
            gameState.deck.append(placeholderCard)
        case .trumpDeck:
            gameState.trumpCards.append(placeholderCard)
        }
        
        // Remove the card from the source
        switch source {
        case .localPlayer:
            if let index = self.gameState.localPlayer?.hand.firstIndex(of: card) {
                self.gameState.localPlayer?.hand.remove(at: index)
            }
        case .leftPlayer:
            if let index = self.gameState.leftPlayer?.hand.firstIndex(of: card) {
                self.gameState.leftPlayer?.hand.remove(at: index)
            }
        case .rightPlayer:
            if let index = self.gameState.rightPlayer?.hand.firstIndex(of: card) {
                self.gameState.rightPlayer?.hand.remove(at: index)
            }
        case .localPlayerTricks:
            if let index = self.gameState.localPlayer?.trickCards.firstIndex(of: card) {
                self.gameState.localPlayer?.trickCards.remove(at: index)
            }
        case .leftPlayerTricks:
            if let index = self.gameState.leftPlayer?.trickCards.firstIndex(of: card) {
                self.gameState.leftPlayer?.trickCards.remove(at: index)
            }
        case .rightPlayerTricks:
            if let index = self.gameState.rightPlayer?.trickCards.firstIndex(of: card) {
                self.gameState.rightPlayer?.trickCards.remove(at: index)
            }
        case .table:
            if let index = self.gameState.table.firstIndex(of: card) {
                self.gameState.table.remove(at: index)
            }
        case .deck:
            if let index = self.gameState.deck.firstIndex(of: card) {
                self.gameState.deck.remove(at: index)
            }
        case .trumpDeck:
            if let index = self.gameState.trumpCards.firstIndex(of: card) {
                self.gameState.trumpCards.remove(at: index)
            }
        }
        
        // Create a MovingCard instance without toState yet
        guard let fromState = self.cardStates[card.id] else {
//            print("fromState wasn't captured")
            return
        }
        let movingCardInstance = MovingCard(
            card: card,
            to: destination,
            placeholderCard: placeholderCard,
            fromState: fromState
        )
//        print("Initiated moving \(movingCardInstance.card) from \(movingCardInstance.fromState) to \(movingCardInstance.to)")
        
        self.movingCards.append(movingCardInstance)
    }

    // MARK: finalizeMove

    // Function to finalize card movement after animation
    func finalizeMove(_ movingCard: MovingCard) {
        guard let toState = movingCard.toState else {
            print("toState is still nil for \(movingCard.card)")
            return
        }
        
        // Add the card to the destination at the correct position
        switch movingCard.to {
        case .localPlayer:
            if let index = self.gameState.localPlayer?.hand.firstIndex(where: { $0.id == movingCard.placeholderCard.id }) {
                self.gameState.localPlayer?.hand[index] = movingCard.card
            }
        case .leftPlayer:
            if let index = self.gameState.leftPlayer?.hand.firstIndex(where: { $0.id == movingCard.placeholderCard.id }) {
                self.gameState.leftPlayer?.hand[index] = movingCard.card
            }
        case .rightPlayer:
            if let index = self.gameState.rightPlayer?.hand.firstIndex(where: { $0.id == movingCard.placeholderCard.id }) {
                self.gameState.rightPlayer?.hand[index] = movingCard.card
            }
        case .localPlayerTricks:
            if let index = self.gameState.localPlayer?.trickCards.firstIndex(where: { $0.id == movingCard.placeholderCard.id }) {
                self.gameState.localPlayer?.trickCards[index] = movingCard.card
            }
        case .leftPlayerTricks:
            if let index = self.gameState.leftPlayer?.trickCards.firstIndex(where: { $0.id == movingCard.placeholderCard.id }) {
                self.gameState.leftPlayer?.trickCards[index] = movingCard.card
            }
        case .rightPlayerTricks:
            if let index = self.gameState.rightPlayer?.trickCards.firstIndex(where: { $0.id == movingCard.placeholderCard.id }) {
                self.gameState.rightPlayer?.trickCards[index] = movingCard.card
            }
        case .table:
            if let index = self.gameState.table.firstIndex(where: { $0.id == movingCard.placeholderCard.id }) {
                self.gameState.table[index] = movingCard.card
            }
        case .deck:
            if let index = self.gameState.deck.firstIndex(where: { $0.id == movingCard.placeholderCard.id }) {
                self.gameState.deck[index] = movingCard.card
            }
        case .trumpDeck:
            if let index = self.gameState.trumpCards.firstIndex(where: { $0.id == movingCard.placeholderCard.id }) {
                self.gameState.trumpCards[index] = movingCard.card
            }
        }
        
        // Update the card's state to destination state
        cardStates[movingCard.card.id] = toState
        
        // Remove the moving card from movingCards
        if let index = movingCards.firstIndex(where: { $0.id == movingCard.id }) {
            movingCards.remove(at: index)
        }
        
        // Ensure the batch animation is completed before starting another one
        activeAnimations -= 1
//        print("!!! FinalizeMove: activeAnimations is \(activeAnimations) for card \(movingCard.card).")
        if activeAnimations == 0 {
            onBatchAnimationsCompleted[0]?()  // calls the closure we set in beginBatchMove
            
//            print("FinalizeMove: Batch animations completed")

            // Trigger the next queued animation batch
            processAnimationQueue()
        } else {
//            print("FinalizeMove: Batch animations still running with \(activeAnimations) animations left.")
        }
    }
}
