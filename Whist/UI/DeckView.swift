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
    let namespace: Namespace.ID
    
    init(gameState: GameState, namespace: Namespace.ID) {
        self.gameState = gameState
        self.namespace = namespace
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

                    CardView(card: card)
                        .offset(x: offset, y: -offset) // Apply small offset for perspective
                        .frame(width: 60, height: 90) // Standard card size
                        .zIndex(Double(index)) // Ensure proper stacking order
                        .matchedGeometryEffect(id: card.id, in: namespace)
                        .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .scale.combined(with: .opacity)))
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
        @Namespace var cardAnimationNamespace
        let gameManager = GameManager()
        gameManager.setupPreviewGameState()

        return DeckView(gameState: gameManager.gameState, namespace: cardAnimationNamespace)
            .environmentObject(gameManager)
            .previewDisplayName("Deck View Preview")
            .previewLayout(.sizeThatFits)
    }
}
