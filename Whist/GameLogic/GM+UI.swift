////
////  GM+UI.swift
////  Whist
////
////  Created by Tony Buffard on 2024-11-30.
////
//
//import Foundation
//import SwiftUI
//
//extension GameManager {
//    func initializePositions(windowSize: CGSize) {
//        guard isGameSetup else {
//            print("initializePositions: Game not setup.")
//            return
//        }
//        
//        guard let localPlayer = gameState.localPlayer,
//              let leftPlayer = gameState.leftPlayer,
//              let rightPlayer = gameState.rightPlayer else {
//            fatalError("Players are not fully initialized before setting positions.")
//        }
//
//        let screenWidth = windowSize.width
//        let screenHeight = windowSize.height
//        
//        print("Initializing positions with screen size: \(screenWidth) x \(screenHeight).")
//        
//        // Set deck and table positions
//        uiState.deckPosition = CGPoint(x: screenWidth / 2 + 100, y: 100)
//        uiState.trumpPosition = CGPoint(x: screenWidth / 2 - 100, y: 100)
//        uiState.tablePosition = CGPoint(x: screenWidth / 2, y: screenHeight / 2)
//        uiState.scoreBoardPosition = CGPoint(x: screenWidth / 2, y: 100)
//        
//        // Set player hand positions
//        uiState.playerHandPositions = [
//            localPlayer.id: CGPoint(x: screenWidth / 2, y: screenHeight - 120),
//            leftPlayer.id: CGPoint(x: 100, y: screenHeight / 2),
//            rightPlayer.id: CGPoint(x: screenWidth - 100, y: screenHeight / 2)
//        ]
//        
//        // Set player picture positions
//        uiState.playerInfoPositions = [
//            localPlayer.id: CGPoint(x: screenWidth / 2, y: screenHeight - 200),
//            leftPlayer.id: CGPoint(x: 180, y: screenHeight / 2),
//            rightPlayer.id: CGPoint(x: screenWidth - 180, y: screenHeight / 2)
//        ]
//        
//        // Set player dealer positions
//        uiState.playerDealerPositions = [
//            localPlayer.id: uiState.playerInfoPositions[localPlayer.id]! + CGPoint(x: 30, y: -30),
//            leftPlayer.id: uiState.playerInfoPositions[leftPlayer.id]! + CGPoint(x: 30, y: -30),
//            rightPlayer.id: uiState.playerInfoPositions[rightPlayer.id]! + CGPoint(x: 30, y: -30)
//        ]
//    }
//    
//    func positionDeckCards() {
//        for (index, card) in gameState.cards.enumerated() where card.location == .deck {
//            let offset = CGFloat(index) * 1
//            let newPosition = CGPoint(x: uiState.deckPosition.x + offset, y: uiState.deckPosition.y - offset)
//            gameState.cards[index].position = newPosition
//            gameState.cards[index].size = CGSize(width: 60, height: 90)
//            gameState.cards[index].isFaceDown = true
//        }
//        // Trigger SwiftUI refresh
//        gameState.cards = gameState.cards
//    }
//    
//    func positionTrickCards() {
//        let tablePosition = uiState.tablePosition
//        let horizontalOffset: CGFloat = 50 // Adjust as needed for spacing
//        let verticalOffset: CGFloat = 30 // Adjust for vertical spacing
//        
//        // Iterate over all cards on the table
//        for (index, card) in gameState.cards.enumerated() where card.location == .table {
//            // Base position
//            var position = tablePosition
//            var rotation: CGFloat = 0
//            
//            // Adjust position and rotation based on owner
//            switch card.ownerId {
//            case gameState.localPlayer?.id:
//                // Local player's card (bottom)
//                position = CGPoint(
//                    x: tablePosition.x + CGFloat.random(in: -10...10), // Add randomness
//                    y: tablePosition.y + verticalOffset + CGFloat.random(in: -5...5)
//                )
//                rotation = CGFloat.random(in: -10...10) // Slight random tilt
//                
//            case gameState.leftPlayer?.id:
//                // Left player's card (left)
//                position = CGPoint(
//                    x: tablePosition.x - horizontalOffset + CGFloat.random(in: -5...5),
//                    y: tablePosition.y - verticalOffset + CGFloat.random(in: -10...10)
//                )
//                rotation = CGFloat.random(in: -10...10) + 90
//                
//            case gameState.rightPlayer?.id:
//                // Right player's card (right)
//                position = CGPoint(
//                    x: tablePosition.x + horizontalOffset + CGFloat.random(in: -5...5),
//                    y: tablePosition.y - verticalOffset + CGFloat.random(in: -10...10)
//                )
//                rotation = CGFloat.random(in: -10...10) - 90
//                
//            default:
//                // Fallback for unknown owner
//                position = CGPoint(
//                    x: tablePosition.x + CGFloat.random(in: -20...20),
//                    y: tablePosition.y + CGFloat.random(in: -20...20)
//                )
//                rotation = CGFloat.random(in: -10...10)
//            }
//            
//            // Update card properties
//            card.position = position
//            card.rotation = Angle(degrees: Double(rotation))
//            card.size = CGSize(width: 60, height: 90) // Standard card size
//            card.isFaceDown = false // Trick cards are face-up on the table
//            
//            // Update the card in the game state
//            gameState.cards[index] = card
//        }
//    }
//
//    func sortAndArrangePlayerHand() {
//        // Sort the local player's hand
//        sortLocalPlayerHand()
//        
//        let fanRadius: CGFloat = 300 // Radius for the fan-like arrangement
//        let cardSize = CGSize(width: 60, height: 90) // Standard card size
//        
//        // Iterate over each card in the game state
//        for (index, card) in gameState.cards.enumerated() where card.location == .hand {
//            
//            // Determine the player's position based on the card's ownerId
//            guard let ownerId = card.ownerId else {
//                fatalError("Error: no owner id for card \(card)")
//            }
//            guard let playerPosition = uiState.playerHandPositions[ownerId] else {
//                fatalError("Error: No hand position found for player \(ownerId).")
//            }
//            
//            // Get all cards belonging to the same player
//            let playerHandCards = sortedHand(for: ownerId)
//            let handCount = playerHandCards.count
//            
//            // Calculate angles for the fan arrangement
//            let angleBetweenCards = min(10, 180 / CGFloat(handCount))
//            let totalAngle = angleBetweenCards * CGFloat(handCount - 1)
//            let startAngle = -totalAngle / 2
//            
//            // Determine card's position and rotation based on its index
//            if let cardIndex = playerHandCards.firstIndex(where: { $0.id == card.id }) {
//                let cardAngle = startAngle + CGFloat(cardIndex) * angleBetweenCards
//                let angleInRadians = cardAngle * .pi / 180
//                var xOffset = fanRadius * sin(angleInRadians)
//                var yOffset = fanRadius * (1 - cos(angleInRadians))
//                var rotation = cardAngle
//                
//                // Adjust offsets and rotation based on the player's position
//                if card.ownerId == gameState.localPlayer?.id {
//                    // Local player: cards displayed horizontally
//                    card.isFaceDown = false
//                    card.zIndex = Double(cardIndex) // Higher index cards appear on top
//                } else if card.ownerId == gameState.leftPlayer?.id {
//                    // Left player: cards displayed vertically, facing right
//                    let temp = xOffset
//                    xOffset = -yOffset
//                    yOffset = temp
//                    rotation -= 90
//                    card.zIndex = Double(-cardIndex) // Adjust zIndex as needed
//                } else if card.ownerId == gameState.rightPlayer?.id {
//                    // Right player: cards displayed vertically, facing left
//                    let temp = xOffset
//                    xOffset = yOffset
//                    yOffset = -temp
//                    rotation += 90
//                    card.zIndex = Double(-cardIndex)
//                }
//                
//                // Update card properties
//                card.position = CGPoint(
//                    x: playerPosition.x + xOffset,
//                    y: playerPosition.y + yOffset
//                )
//                card.rotation = Angle(degrees: Double(rotation))
//                card.size = cardSize
//                
//                // Update the card in the game state
//                gameState.cards[index] = card
//            }
//        }
//    }
//    
////    func sortAndArrangePlayerHand() {
////        // Sort the local player's hand
////        sortLocalPlayerHand()
////        
////        let fanRadius: CGFloat = 300 // Radius for the fan-like arrangement
////        let cardSize = CGSize(width: 60, height: 90) // Standard card size
////        
////        // Iterate over each card in the game state
////        for (index, card) in gameState.cards.enumerated() where card.location == .hand {
////            
////            // Determine the player's position based on the card's ownerId
////            guard let ownerId = card.ownerId else {
////                fatalError("Error: no owner id for card \(card)")
////            }
////            guard let playerPosition = uiState.playerHandPositions[ownerId] else {
////                fatalError("Error: No hand position found for player \(ownerId). Current hand positions: \(uiState.playerHandPositions), deck position: \(uiState.deckPosition)")
////            }
////            
////            // Get all cards belonging to the same player
////            let playerHandCards = gameState.cards.filter { $0.location == .hand && $0.ownerId == card.ownerId }
////            let handCount = playerHandCards.count
////            
////            // Calculate angles for the fan arrangement
////            let angleBetweenCards = min(10, 180 / CGFloat(handCount))
////            let totalAngle = angleBetweenCards * CGFloat(handCount - 1)
////            let startAngle = -totalAngle / 2 // = -78.5
////            
////            // Determine card's position and rotation based on its index
////            if let cardIndex = playerHandCards.firstIndex(where: { $0.id == card.id }) {
////                let cardAngle = startAngle + CGFloat(cardIndex) * angleBetweenCards
////                let angleInRadians = cardAngle * .pi / 180
////                var xOffset = fanRadius * sin(angleInRadians) // -294
////                var yOffset = fanRadius * (1 - cos(angleInRadians)) // 241
////                var rotation = cardAngle
////                
////                // Adjust offsets and rotation based on the player's position
////                if card.ownerId == gameState.localPlayer?.id {
////                    // Local player: cards displayed horizontally
////                    card.isFaceDown = false
////                } else if card.ownerId == gameState.leftPlayer?.id {
////                    // Left player: cards displayed vertically, facing right
////                    let temp = xOffset
////                    xOffset = -yOffset
////                    yOffset = temp
////                    rotation -= 90
////                } else if card.ownerId == gameState.rightPlayer?.id {
////                    // Right player: cards displayed vertically, facing left
////                    let temp = xOffset
////                    xOffset = yOffset
////                    yOffset = -temp
////                    rotation += 90
////                }
////                
////                // Update card properties
////                card.position = CGPoint(
////                    x: playerPosition.x + xOffset,
////                    y: playerPosition.y + yOffset
////                )
////                card.rotation = Angle(degrees: Double(rotation))
////                card.size = cardSize
////                
////                // Update the card in the game state
////                gameState.cards[index] = card
////            }
////        }
////    }
//    
//    func positionTrumpCards() {
//        for (index, card) in gameState.cards.enumerated() where card.location == .trump {
//            let offset = CGFloat(index) * 1
//            let newPosition = CGPoint(x: uiState.trumpPosition.x + offset, y: uiState.trumpPosition.y - offset)
//            gameState.cards[index].position = newPosition
//            gameState.cards[index].size = CGSize(width: 60, height: 90)
//            gameState.cards[index].isFaceDown = true
//        }
//        // Trigger SwiftUI refresh
//        gameState.cards = gameState.cards
//    }
//    
//    func positionTricks() {
//        for (index, player) in gameState.players.enumerated() {
//            // Display their picture and names
//            
//            // Display the tricks
//            
//        }
//    }
//
//    func sortedHand(for playerId: PlayerId) -> [Card] {
//        let handCards = gameState.cards.filter { $0.ownerId == playerId && $0.location == .hand }
//        let suitOrder: [Suit] = [.hearts, .clubs, .diamonds, .spades]
//        return handCards.sorted { card1, card2 in
//            if card1.suit == card2.suit {
//                return card1.rank.rawValue < card2.rank.rawValue
//            } else {
//                return suitOrder.firstIndex(of: card1.suit)! < suitOrder.firstIndex(of: card2.suit)!
//            }
//        }
//    }
//}
//
//// Ensure CGPoint addition works
//extension CGPoint {
//    static func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
//        return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
//    }
//}
