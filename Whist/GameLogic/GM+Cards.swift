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
    
    func gatherCards() {
        for i in 0...2 {
            print("gatherAndShuffleCards - player \(gameState.players[i].id) has \(gameState.players[i].trickCards.count) trick cards")
            print("gatherAndShuffleCards - player \(gameState.players[i].id) has \(gameState.players[i].hand.count) cards in hand")
        }
        print("gatherAndShuffleCards - table has \(gameState.table.count) cards")
        print("gatherAndShuffleCards - deck has \(gameState.deck.count) cards")

        withAnimation(.linear(duration: 0.5)) {
            // Gather all cards (should all be in players' tricks)
            for player in self.gameState.players {
                self.gameState.deck += player.trickCards
                player.trickCards = []
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
    }
    
    func shuffleCards () {
        // Shufle the deck
        gameState.deck.shuffle()
    }
    
    func updateDeck(with data: Data) {
        // Make deck same as dealer's
        if let newDeck = try? JSONDecoder().decode([Card].self, from: data) {
            gameState.deck = newDeck
//            updateDeckOrder(with: newDeck)
            print("Deck updated with \(newDeck.count) cards.")
            isDeckReady = true
            checkAndAdvanceStateIfNeeded()
        } else {
            print("Failed to decode deck data.")
        }
    }
    
    func updateDeckOrder(with newDeck: [Card]) {
        // Sort the existing cards array to match the order in the newDeck
        gameState.deck.sort { card1, card2 in
            guard let index1 = newDeck.firstIndex(where: { $0.suit == card1.suit && $0.rank == card1.rank }),
                  let index2 = newDeck.firstIndex(where: { $0.suit == card2.suit && $0.rank == card2.rank }) else {
                return false
            }
            return index1 < index2
        }
    }
    
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
        
        // Distribute cards one by one in a clockwise manner with delay
        var currentIndex = 0
        
        func dealNextCard() {
            guard !gameState.deck.isEmpty else { return }
            
            // Get the current player
            let playerID = gameState.playOrder[currentIndex]
            guard let remainingCards = cardsPerPlayer[playerID], remainingCards > 0 else {
                currentIndex = (currentIndex + 1) % gameState.playOrder.count
                dealNextCard() // Skip to the next player
                return
            }
            
            // Move card to player's hand with animation
            withAnimation(.smooth(duration: 5)) {
                // Deal a card to the current player
                if let card = gameState.deck.popLast() {
                    card.isFaceDown = true
                    gameState.getPlayer(by: playerID).hand.append(card)
                    cardsPerPlayer[playerID] = remainingCards - 1
                    print("\(playerID.rawValue) receives \(card)")
                }
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
                completion()
                return
            }
            
            // Add a delay for the next card
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dealNextCard()
            }
        }
        
        dealNextCard()
    }
    
    func showCards() {
        // after the cards are dealt, show the ones that should be facing up
        if gameState.round < 4 {
            // Face down for local player, face up for others
            for card in gameState.leftPlayer?.hand ?? [] {
                card.isFaceDown = false
            }
            for card in gameState.rightPlayer?.hand ?? [] {
                card.isFaceDown = false
            }
        } else {
            // Face up for local player, face down for others
            for card in gameState.localPlayer?.hand ?? [] {
                card.isFaceDown = false
            }
        }
    }
    
//    func dealCards() {
//        var cardsToDeal: Int
//        
//        // Sort players by the last score
//        gameState.players.sort { (a, b) -> Bool in
//            let lastScoreA = a.scores.last ?? 0
//            let lastScoreB = b.scores.last ?? 0
//            return lastScoreA < lastScoreB
//        }
//        
//        // Establish the base number of cards to deal for each round
//        if gameState.round <= 3 {
//            cardsToDeal = 1
//        } else if gameState.round <= 12 {
//            cardsToDeal = gameState.round - 2
//        } else {
//            return // No cards to deal beyond round 12
//        }
//        
//        // Calculate the number of cards to deal to each player
//        var cardsPerPlayer = [PlayerId: Int]() // PlayerId -> Cards to deal
//        for player in gameState.players {
//            var extraCards = 0
//            
//            if gameState.round > 3 {
//                if player.place == 2 {
//                    if player.monthlyLosses > 1 && gameState.round < 12 {
//                        extraCards = 2
//                    } else {
//                        extraCards = 1
//                    }
//                } else if player.place == 3 {
//                    extraCards = 1
//                    let playerScore = player.scores[safe: gameState.round - 2] ?? 0
//                    let secondPlayerScore = gameState.players[1].scores[safe: gameState.round - 2] ?? 0
//                    
//                    if player.monthlyLosses > 0 || Double(playerScore) <= 0.5 * Double(secondPlayerScore) {
//                        extraCards = 2
//                    }
//                }
//            }
//            
//            // Cap extra cards to the number of cards left in the deck for the last round
//            if gameState.round == 12 && extraCards == 2,
//               let secondPlayer = gameState.players[safe: 1],
//               let thirdPlayer = gameState.players[safe: 2],
//               secondPlayer.scores[safe: gameState.round - 2] != thirdPlayer.scores[safe: gameState.round - 2] {
//                extraCards = 1
//            }
//            
//            cardsPerPlayer[player.id] = cardsToDeal + extraCards
//        }
//        
//        // Distribute cards one by one in a clockwise manner
//        var currentIndex = 0
//        
//        while !gameState.deck.isEmpty {
//            // Get the current player
//            let playerID = gameState.playOrder[currentIndex]
//            guard let remainingCards = cardsPerPlayer[playerID], remainingCards > 0 else {
//                currentIndex = (currentIndex + 1) % gameState.playOrder.count
//                continue
//            }
//            
//            // Deal a card to the current player
//            if let card = gameState.deck.popLast() {
//                // check if the card should still be face down
//                if let localPlayerID = gameState.localPlayer?.id {
//                    if gameState.round < 4 {
//                        // Face down for local player, face up for others
//                        card.isFaceDown = (playerID == localPlayerID)
//                    } else {
//                        // Face up for local player, face down for others
//                        card.isFaceDown = (playerID != localPlayerID)
//                    }
//                } else {
//                    // Handle the case where localPlayer is nil, if needed
//                    fatalError("Local player is not set.")
//                }
//                // move card to player's hand
//                withAnimation(.linear(duration: 0.5)) {
//                    gameState.getPlayer(by: playerID).hand.append(card)
//                }
//                
//                cardsPerPlayer[playerID] = remainingCards - 1
//                print("\(playerID.rawValue) receives \(card)")
//            }
//            
//            // Move to the next player
//            currentIndex = (currentIndex + 1) % gameState.playOrder.count
//            
//            // Stop if all cards are dealt
//            if cardsPerPlayer.values.allSatisfy({ $0 == 0 }) {
//                break
//            }
//        }
//        
//        // Sort and arrange all players hands
//        //        sortAndArrangePlayerHand()
//        
//        // Determine the trump card if applicable
//        if gameState.round <= 3 || allScoresEqual() {
//            if let trumpCard = gameState.deck.last {
//                gameState.trumpSuit = trumpCard.suit
//                trumpCard.isFaceDown = false
//                print("The trump card is \(trumpCard)")
//            }
//        }
//        for i in 0...(gameState.players.count-1) {
//            print("\(gameState.players[i].id.rawValue) hand: \(gameState.players[i].hand)")
//        }
//    }

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
                return card1.rank.rawValue < card2.rank.rawValue
            } else {
                // Otherwise, sort by suit order
                return suitOrder.firstIndex(of: card1.suit)! < suitOrder.firstIndex(of: card2.suit)!
            }
        }

        print("Local player's hand has been sorted.")
    }
    
    func playCard(_ card: Card) {
        // Ensure the local player is defined
        guard let localPlayer = gameState.localPlayer else {
            fatalError("Error: Local player is not defined.")
        }

        // Ensure the local player has the card in their hand
        guard let cardIndex = localPlayer.hand.firstIndex(where: { $0 == card }) else {
            fatalError("Error: The card is not in the local player's hand.")
        }

        // Remove the card from the local player's hand
        localPlayer.hand.remove(at: cardIndex)

        // Add the card to the gameState.table
        self.gameState.table.append(card)
        print("Table content: \(gameState.table)")

        // Notify other players about the action
        sendPlayCardtoPlayers(card)

        print("Card \(card) played by \(localPlayer.username). Updated gameState.table: \(gameState.table)")
        
        checkAndAdvanceStateIfNeeded()
    }
    
    func updateGameStateWithPlayedCard(from playerId: PlayerId, with card: Card) {
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
        
        if let cardIndex = player.hand.firstIndex(where: { $0 == card }) {
            player.hand.remove(at: cardIndex)
        } else {
            print("Error: Card not found in player's hand.")
            return
        }
        
        card.isFaceDown = false
        self.gameState.table.append(card)
        
        print("Card \(card) played by \(playerId.rawValue). Updated gameState.table: \(gameState.table)")
    }
    
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

        // Introduce a delay before clearing the table and assigning the trick
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(.linear(duration: 0.5)) {
                // Set isFaceDown to true for the cards on the table
                self.gameState.table.forEach { card in
                    card.isFaceDown = true
                }
                // Assign the trick to the winning player
                winner.trickCards.append(contentsOf: self.gameState.table)
                winner.madeTricks[self.gameState.round - 1] += 1
                self.gameState.table.removeAll() // Clear the table
                print("Winner \(winner.id.rawValue) has \(winner.trickCards.count) trick cards and announced \(winner.announcedTricks[self.gameState.round - 1]) trick.")
            }
            
            // Add a delay after the animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.updatePlayerPlayOrder(startingWith: .winner(winningPlayerID))
                completion()
            }
        }
    }
}
