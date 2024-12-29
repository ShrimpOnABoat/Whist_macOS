//
//  DeckView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-12-05.
//

import SwiftUI

struct DeckView: View {
    @EnvironmentObject var gameManager: GameManager
    @ObservedObject var gameState: GameState
    
    init(gameState: GameState) {
        self.gameState = gameState
    }
    
    var body: some View {
        ZStack {
            if gameState.deck.isEmpty {
                // Show marker for empty deck
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray, style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .frame(width: 60, height: 90)
                    .overlay(
                        Text("Deck")
                            .font(.caption)
                            .foregroundColor(.gray)
                    )
            } else {
                ForEach(Array(gameState.deck.enumerated()), id: \.element.id) { index, card in
                    let offset = CGFloat(index) * 0.5 // Offset for visual separation
                    
                    TransformableCardView(
                        card: card,
                        xOffset: offset,
                        yOffset: -offset)
                    .zIndex(Double(index)) // Higher index on top
                }
            }
        }
        .animation(.smooth(duration: 0.3), value: gameState.deck)
        .padding() // Add padding for layout spacing
    }
}

// MARK: - Preview

struct DeckView_Previews: PreviewProvider {
    static var previews: some View {
        let gameManager = GameManager()
        gameManager.setupPreviewGameState()
        
        return DeckView(gameState: gameManager.gameState)
            .environmentObject(gameManager)
            .previewDisplayName("Deck View Preview")
            .previewLayout(.sizeThatFits)
    }
}
