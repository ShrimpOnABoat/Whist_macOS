//
//  TableView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-12-06.
//

import SwiftUI

struct TableView: View {
    @EnvironmentObject var gameManager: GameManager
    @ObservedObject var gameState: GameState
    
    enum Mode {
        case tricks, trumps
    }
    
    let mode: Mode

    init(gameState: GameState, mode: Mode = .tricks) {
        self.gameState = gameState
        self.mode = mode
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                switch mode {
                case .tricks:
                    // Default: Display cards on the table
                    displayTrickCards(geometry: geometry)
                case .trumps:
                    // Display trump cards
                    displayTrumpCards(geometry: geometry)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Display Trick Cards
    private func displayTrickCards(geometry: GeometryProxy) -> some View {
        ZStack {
            let offset: CGFloat = 40

            if let localPlayer = gameState.localPlayer,
               let localIndex = gameState.playOrder.firstIndex(of: localPlayer.id),
               localIndex < gameState.table.count {
                let card = gameState.table[localIndex]
                TransformableCardView(card: card, rotation: card.rotation + card.randomAngle, xOffset: card.randomOffset.x, yOffset: card.offset + card.randomOffset.y)
                    .zIndex(Double(localIndex))
            }
            
            if let leftPlayer = gameState.leftPlayer,
               let leftIndex = gameState.playOrder.firstIndex(of: leftPlayer.id),
               leftIndex < gameState.table.count {
                let card = gameState.table[leftIndex]
                TransformableCardView(card: card, rotation: card.rotation + card.randomAngle + CGFloat(90), xOffset: -offset + card.offset + card.randomOffset.x, yOffset: -offset + card.randomOffset.y)
                    .zIndex(Double(leftIndex))
            }
            
            if let rightPlayer = gameState.rightPlayer,
               let rightIndex = gameState.playOrder.firstIndex(of: rightPlayer.id),
               rightIndex < gameState.table.count {
                let card = gameState.table[rightIndex]
                TransformableCardView(card: card, rotation: card.rotation + card.randomAngle + CGFloat(90), xOffset: offset + card.offset + card.randomOffset.x, yOffset: -offset + card.randomOffset.y)
                    .zIndex(Double(rightIndex))
            }
        }
    }
    
    // MARK: - Display Trump Cards
    private func displayTrumpCards(geometry: GeometryProxy) -> some View {
        let trumpCards = gameState.table
            .sorted { card1, card2 in
                // Sort by suit order: hearts, clubs, diamonds, spades
                let suitOrder: [Suit: Int] = [.hearts: 0, .clubs: 1, .diamonds: 2, .spades: 3]
                return suitOrder[card1.suit] ?? 0 < suitOrder[card2.suit] ?? 0
            }

        return HStack(spacing: 20) {
            ForEach(trumpCards) { card in
                TransformableCardView(
                    card: card,
                    rotation: 0, // No rotation for trump cards
                    xOffset: 0,
                    yOffset: 0
                )
            }
        }
        .frame(
            width: geometry.size.width,
            height: geometry.size.height,
            alignment: .center
        )
    }
}

// MARK: - Preview

struct TableView_Previews: PreviewProvider {
    static var previews: some View {
        let gameManager = GameManager()
        
        // Setup preview game state
        gameManager.setupPreviewGameState()

        // Define trump cards
        let trumpCards = [
            Card(suit: .hearts, rank: .two),
            Card(suit: .clubs, rank: .two),
            Card(suit: .diamonds, rank: .two),
            Card(suit: .spades, rank: .two)
        ]
        
        gameManager.gameState.trumpCards = trumpCards.map { card in
            let mutableCard = card
            mutableCard.isFaceDown = false // Flip the trump cards face up
            return mutableCard
        }
        
        return Group {
            // Trick Cards Preview
            TableView(gameState: gameManager.gameState, mode: .tricks)
                .environmentObject(gameManager)
                .previewDisplayName("Trick Cards")
                .previewLayout(.fixed(width: 600, height: 400))
            
            // Trump Cards Preview
            TableView(gameState: {
                let gameState = gameManager.gameState
                gameState.table = trumpCards // Use trump cards for this preview
                return gameState
            }(), mode: .trumps)
            .environmentObject(gameManager)
            .previewDisplayName("Trump Cards")
            .previewLayout(.fixed(width: 600, height: 200))
        }
    }
}
