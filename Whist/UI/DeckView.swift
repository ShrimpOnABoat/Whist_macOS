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
                    
                    TransformableCardView(
                        card: card,
//                        scale: 1.0,
//                        rotation: 0,
                        xOffset: offset,
                        yOffset: -offset)

//                    CardView(card: card)
//                        .offset(x: offset, y: -offset)
//                        .opacity(card.isPlaceholder ? 0.0 : 1.0)
//                        .overlay(
//                            GeometryReader { geometry in
//                                Color.clear
//                                    .preference(key: CardTransformPreferenceKey.self, value: [
//                                        card.id: CardState(
//                                            position: CGPoint(x: geometry.frame(in: .global).midX + offset, y: geometry.frame(in: .global).midY - offset),
//                                            rotation: 0,
//                                            scale: 1.0
//                                            
//                                        )
//                                    ])
//                            }
//                        )
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
        @Namespace var cardAnimationNamespace
        let gameManager = GameManager()
        gameManager.setupPreviewGameState()

        return DeckView(gameState: gameManager.gameState, namespace: cardAnimationNamespace)
            .environmentObject(gameManager)
            .previewDisplayName("Deck View Preview")
            .previewLayout(.sizeThatFits)
    }
}
