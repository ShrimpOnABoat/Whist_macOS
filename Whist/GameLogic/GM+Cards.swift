//
//  GM+Cards.swift
//  Whist
//
//  Created by Tony Buffard on 2024-12-01.
//

import Foundation
import SwiftUI

extension GameManager {
    // functions dealing with the cards
    
    // MARK: initializeCards
    
    func initializeCards() {
        // Create the deck cards, the trump ones are already defined
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                let card = Card(suit: suit, rank: rank)
                if rank != .two {
                    gameState.deck.append(card)
                }
            }
        }
        if gameState.deck.count != 32 || gameState.trumpCards.count != 4 {
            fatalError("Something went wrong creating the deck")
        }
    }
    
    // MARK: gatherCards
    
    func gatherCards(completion: @escaping () -> Void) {
        let totalCardsToMove = gameState.players.reduce(0) { $0 + $1.trickCards.count }
        print("gatherCards: beginBatchMove(\(totalCardsToMove)), activeAnimations: \(activeAnimations)")
        if totalCardsToMove > 0 {
            beginBatchMove(totalCards: totalCardsToMove) {
                completion()
            }
            
            for player in gameState.players {
                let source: CardPlace = player.tablePosition == .local ? .localPlayerTricks : (player.tablePosition == .left) ? .leftPlayerTricks : .rightPlayerTricks
                for card in player.trickCards {
                    moveCard(card, from: source, to: .deck)
                }
            }
            
            // make sure they're all face down
            for index in gameState.deck.indices {
                gameState.deck[index].isFaceDown = true
                gameState.deck[index].isPlayable = false
            }
            for index in gameState.trumpCards.indices {
                gameState.trumpCards[index].isFaceDown = true
                gameState.trumpCards[index].isPlayable = false
            }
            
            // Make sure everything is alright
            let deckCardCount: Int = gameState.deck.count
            let trumpCardCount: Int = gameState.trumpCards.count
            
            if (deckCardCount != 32) || (trumpCardCount != 4) {
                fatalError("Some cards are missing or wrong count")
            }
        } else {
            completion()
        }
    }
    
    // MARK: shuffleCards
    
    func shuffleCards () {
        // Shufle the deck
        gameState.deck.shuffle()
    }
    
    // MARK: updateDeck
    
    func updateDeck(with data: Data) {
        // Make deck same as dealer's
        if let newDeck = try? JSONDecoder().decode([Card].self, from: data) {
            gameState.deck = newDeck
            print("Deck updated with \(newDeck.count) cards.")
            isDeckReady = true
            checkAndAdvanceStateIfNeeded()
        } else {
            print("Failed to decode deck data.")
        }
    }
    
    // MARK: dealCards
    
    func dealCards(completion: @escaping () -> Void) {
        var cardsToDeal: Int
        
        // Sort players by the last score
        gameState.players.sort { (a, b) -> Bool in
            let lastScoreA = a.scores.last ?? 0
            let lastScoreB = b.scores.last ?? 0
            return lastScoreA < lastScoreB
        }
        
        // Establish the base number of cards to deal for each round
        if gameState.round <= 3 {
            cardsToDeal = 1
        } else if gameState.round <= 12 {
            cardsToDeal = gameState.round - 2
        } else {
            return // No cards to deal beyond round 12
        }
        
        // Calculate the number of cards to deal to each player
        var cardsPerPlayer = [PlayerId: Int]() // PlayerId -> Cards to deal
        for player in gameState.players {
            var extraCards = 0
            
            if gameState.round > 3 {
                if player.place == 2 {
                    if player.monthlyLosses > 1 && gameState.round < 12 {
                        extraCards = 2
                    } else {
                        extraCards = 1
                    }
                } else if player.place == 3 {
                    extraCards = 1
                    let playerScore = player.scores[safe: gameState.round - 2] ?? 0
                    let secondPlayerScore = gameState.players[1].scores[safe: gameState.round - 2] ?? 0
                    
                    if player.monthlyLosses > 0 || Double(playerScore) <= 0.5 * Double(secondPlayerScore) {
                        extraCards = 2
                    }
                }
            }
            
            // Cap extra cards to the number of cards left in the deck for the last round
            if gameState.round == 12 && extraCards == 2,
               let secondPlayer = gameState.players[safe: 1],
               let thirdPlayer = gameState.players[safe: 2],
               secondPlayer.scores[safe: gameState.round - 2] != thirdPlayer.scores[safe: gameState.round - 2] {
                extraCards = 1
            }
            
            cardsPerPlayer[player.id] = cardsToDeal + extraCards
        }
        
        // Set the batch animation
        let totalCardsToMove = cardsPerPlayer.reduce(0) { $0 + $1.value }
        print("dealCards: beginBatchMove(\(totalCardsToMove)), activeAnimations: \(activeAnimations)")
        beginBatchMove(totalCards: totalCardsToMove) {
            completion()
        }
        
        // Distribute cards one by one in a clockwise manner with delay
        var currentIndex = 0
        
        func dealNextCard() {
            guard !gameState.deck.isEmpty else {
                completion()
                return
            }
            
            // Get the current player
            let playerID = gameState.playOrder[currentIndex]
            guard let remainingCards = cardsPerPlayer[playerID], remainingCards > 0 else {
                currentIndex = (currentIndex + 1) % gameState.playOrder.count
                dealNextCard() // Skip to the next player
                return
            }
            
            // Move card to player's hand with animation
            if let card = gameState.deck.last
            {
                card.isFaceDown = true
                var destination: CardPlace = .localPlayer
                switch (gameState.getPlayer(by: playerID).tablePosition ) {
                case .local:
                    destination = .localPlayer
                    card.isFaceDown = gameState.round < 4 ? true : false
                case .left:
                    destination = .leftPlayer
                    card.isFaceDown = gameState.round < 4 ? false : true
                case .right:
                    destination = .rightPlayer
                    card.isFaceDown = gameState.round < 4 ? false : true
                }
                moveCard(card, from: .deck, to: destination)

                cardsPerPlayer[playerID]! -= 1
            }
            
            // Move to the next player
            currentIndex = (currentIndex + 1) % gameState.playOrder.count
            
            // Stop if all cards are dealt
            if cardsPerPlayer.values.allSatisfy({ $0 == 0 }) {
                // Determine the trump card if applicable
                if gameState.round <= 3 || allScoresEqual() {
                    if let trumpCard = gameState.deck.last {
                        gameState.trumpSuit = trumpCard.suit
                        withAnimation(.smooth(duration: 0.5)) {
                            trumpCard.isFaceDown = false
                        }
                        print("The trump card is \(trumpCard)")
                    }
                }
                sortLocalPlayerHand()
//                completion()
                return
            } else {
                // Add a delay for the next card
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dealNextCard()
                }
            }
        }

        dealNextCard()
    }
    
    // MARK: sortLocalPlayerHand
    
    func sortLocalPlayerHand() {
        guard let localPlayerId = gameState.localPlayer?.id else {
            fatalError("Error: Local player is not defined.")
        }

        let player = gameState.getPlayer(by: localPlayerId)

        // Define the suit order
        let suitOrder: [Suit] = [.hearts, .clubs, .diamonds, .spades]

        // Sort the hand based on suit order and rank
        player.hand.sort { card1, card2 in
            if card1.suit == card2.suit {
                // If suits are the same, compare ranks
                return card1.rank.precedence < card2.rank.precedence
            } else {
                // Otherwise, sort by suit order
                return suitOrder.firstIndex(of: card1.suit)! < suitOrder.firstIndex(of: card2.suit)!
            }
        }

        print("Local player's hand has been sorted.")
    }
    
    // MARK: playCard
    
    func playCard(_ card: Card, completion: @escaping () -> Void) {
        // Ensure the local player is defined
        guard let localPlayer = gameState.localPlayer else {
            fatalError("Error: Local player is not defined.")
        }

        // Ensure the local player has the card in their hand
        guard localPlayer.hand.firstIndex(where: { $0 == card }) != nil else {
            fatalError("Error: The card is not in the local player's hand.")
        }

        // Play the card
        print("playCard: beginBatchMove(1), activeAnimations: \(activeAnimations)")
        beginBatchMove(totalCards: 1) {
            completion()
        }
        moveCard(card, from: .localPlayer, to: .table)

        // Notify other players about the action
        sendPlayCardtoPlayers(card)

        print("Card \(card) played by \(localPlayer.username). Updated gameState.table: \(gameState.table)")
        
    }
    
    // MARK: Received played card
    
    func updateGameStateWithPlayedCard(from playerId: PlayerId, with card: Card, completion: @escaping () -> Void) {
        // Move the card from the player's hand to the table
        let player = gameState.getPlayer(by: playerId)
        
        print("Received played card from \(playerId.rawValue) with card \(card).")
        print("\(player)'s current hand: \(player.hand)")
        
        // Check if the player already played
        guard let playerIndex = gameState.playOrder.firstIndex(of: playerId) else {
            fatalError("Player ID not found in play order.")
        }
        
        if gameState.table.indices.contains(playerIndex) {
            print("Error: Player \(playerId.rawValue) has already played a card this round.")
            return
        }
        
        
        if player.hand.firstIndex(where: { $0 == card }) != nil {
            let source: CardPlace = player.tablePosition == .left ? .leftPlayer : .rightPlayer
            card.isFaceDown = false
            print("updateGameStateWithPlayedCard: beginBatchMove(1), activeAnimations: \(activeAnimations)")
            beginBatchMove(totalCards: 1) { completion() }
            moveCard(card, from: source, to: .table)
        } else {
            print("Error: Card not found in player's hand.")
            return
        }
        print("Card \(card) played by \(playerId.rawValue). Updated gameState.table: \(gameState.table)")
    }
    
    // MARK: setPlayableCards
    
    func setPlayableCards() {
        // Ensure the local player is defined
        guard let localPlayer = gameState.localPlayer else {
            fatalError("Error: Local player is not defined.")
        }

        // Determine the leading suit if available
        let leadingSuit = gameState.table.first?.suit

        // Check if the player has cards matching the leading suit
        let hasLeadingSuit = localPlayer.hand.contains { $0.suit == leadingSuit }

        // Determine playable cards
        localPlayer.hand.forEach { card in
            if let leadingSuit = leadingSuit, hasLeadingSuit {
                // If there's a leading suit and the player has cards of that suit,
                // only those cards are playable
                card.isPlayable = card.suit == leadingSuit
            } else {
                // Otherwise, all cards are playable
                card.isPlayable = true
            }
        }
    }
    
    // MARK: assignTricks
    
    func assignTrick(completion: @escaping () -> Void) {
        // Ensure there are exactly 3 cards on the table
        guard gameState.table.count == 3 else {
            fatalError("Table must contain exactly 3 cards.")
        }
        
        // Ensure there's a trump suit defined
        guard let trumpSuit = gameState.trumpSuit else {
            fatalError("Trump suit is not defined.")
        }
        
        // Determine the leading suit (suit of the first card played)
        guard let leadingSuit = gameState.table.first?.suit else {
            fatalError("No leading suit found.")
        }
        
        // Find the winning card
        guard let winningCard = gameState.table.max(by: { card1, card2 in
            // Check if either card is a trump card
            if card1.suit == trumpSuit && card2.suit != trumpSuit {
                return false // card1 wins
            } else if card2.suit == trumpSuit && card1.suit != trumpSuit {
                return true // card2 wins
            }
            
            // If neither card is a trump card, compare by leading suit
            if card1.suit == leadingSuit && card2.suit != leadingSuit {
                return false // card1 wins
            } else if card2.suit == leadingSuit && card1.suit != leadingSuit {
                return true // card2 wins
            }
            
            // If both cards are of the same suit, compare ranks
            return card1.rank.precedence < card2.rank.precedence
        }) else {
            fatalError("Failed to determine the winning card.")
        }
        
        // Find the winner (player who played the winning card)
        guard let winningCardIndex = gameState.table.firstIndex(of: winningCard),
              let winningPlayerID = gameState.playOrder[safe: winningCardIndex] else {
            fatalError("Could not determine the winner.")
        }
        
        let winner = gameState.getPlayer(by: winningPlayerID)
        print("Player \(winner.id.rawValue) won the trick with \(winningCard).")
        
        // Update the last trick with all played cards and their players
        gameState.lastTrick = [:] // Clear the previous last trick
        for (index, card) in gameState.table.enumerated() {
            guard let playerId = gameState.playOrder[safe: index] else {
                fatalError("Player ID not found for card \(card).")
            }
            gameState.lastTrick[playerId] = card
        }
        
        // make sure all cards moved before doing anything else
        print("assignTricks: beginBatchMove(3), activeAnimations: \(activeAnimations)")
        beginBatchMove(totalCards: 3) {
            print("Assign trick should be completed now!")
            completion()
        }
        
        // Introduce a delay before clearing the table and assigning the trick
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // Set isFaceDown to true for the cards on the table
            self.gameState.table.forEach { card in
                card.isFaceDown = true
                switch winner.tablePosition {
                case .local:
                    self.moveCard(card, from: .table, to: .localPlayerTricks)
                case .left:
                    self.moveCard(card, from: .table, to: .leftPlayerTricks)
                case .right:
                    self.moveCard(card, from: .table, to: .rightPlayerTricks)
                }
            }
            
            winner.madeTricks[self.gameState.round - 1] += 1
            print("Winner \(winner.id.rawValue) has \(winner.trickCards.count) trick cards and announced \(winner.announcedTricks[self.gameState.round - 1]) trick.")
            
            // Add a delay after the animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.updatePlayerPlayOrder(startingWith: .winner(winningPlayerID))
            }
        }
    }
    
    // MARK: ChooseTrump
    
    func chooseTrump(completion: @escaping () -> Void) {
        print("chooseTrump: beginBatchMove(4), activeAnimations: \(activeAnimations)")
        beginBatchMove(totalCards: 4) { completion() }
        // Move the trump cards to the table face up
        for card in gameState.trumpCards {
            card.isFaceDown = false
            card.isPlayable = true
            moveCard(card, from: .trumpDeck, to: .table)
        }
    }
    
    func selectTrumpSuit(_ trumpCard: Card, completion: @escaping () -> Void) {
        // Set the trump suit
        gameState.trumpSuit = trumpCard.suit
        
        // Move the cards back in the deck, the selected one last
        print("selectTrump: beginBatchMove(4), activeAnimations: \(activeAnimations)")
        beginBatchMove(totalCards: 4) { completion() }
        for card in gameState.table {
            if card != trumpCard {
                card.isFaceDown = true
                moveCard(card, from: .table, to: .trumpDeck)
            }
        }
        moveCard(trumpCard, from: .table, to: .trumpDeck)
        
        // Send other players the chosen trump suit
        sendTrumpToPlayers(trumpCard)
        
//        checkAndAdvanceStateIfNeeded()
    }
}
