//
//  TrumpCardsView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-12-06.
//

import SwiftUI

struct TrumpView: View {
    @EnvironmentObject var gameManager: GameManager
    var dynamicSize: DynamicSize

    var body: some View {
        ZStack {
            if gameManager.gameState.trumpCards.isEmpty {
                // Show marker for empty deck
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray, style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .frame(width: dynamicSize.cardWidth * dynamicSize.deckCardsScale, height: dynamicSize.cardHeight * dynamicSize.deckCardsScale)
                    .overlay(
                        Text("Atouts")
                            .font(.caption)
                            .foregroundColor(.gray)
                    )
            } else {
                ForEach(Array(gameManager.gameState.trumpCards.enumerated()), id: \.element.id) { index, card in
                    let offset = CGFloat(index) * GameConstants.deckOffset.y // Offset for visual separation
                    TransformableCardView(card: card, scale: dynamicSize.deckCardsScale, xOffset: offset, yOffset: -offset, dynamicSize: dynamicSize)
                        .hueRotation(Angle(degrees: -90 * (card.isFaceDown == true ? 1 : 0)))
                }
            }
        }
        .padding() // Add padding for layout spacing
    }
}

// MARK: - Preview

struct TrumpView_Previews: PreviewProvider {
    static var previews: some View {
        let gameManager = GameManager()
        gameManager.setupPreviewGameState()
        gameManager.gameState.trumpCards.last?.isFaceDown = false
        
        return GeometryReader { geometry in
            let dynamicSize: DynamicSize = DynamicSize(from: geometry)
            
            TrumpView(dynamicSize: dynamicSize)
                .environmentObject(gameManager)
                .previewDisplayName("Trump cards Preview")
                .previewLayout(.sizeThatFits)
        }
    }
}
