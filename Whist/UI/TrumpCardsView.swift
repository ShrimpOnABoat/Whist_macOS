//
//  TrumpCardsView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-12-06.
//

import SwiftUI

struct TrumpView: View {
    @EnvironmentObject var gameManager: GameManager
    let namespace: Namespace.ID

    var body: some View {
        ZStack {
            ForEach(Array(gameManager.gameState.trumpCards.enumerated()), id: \.element.id) { index, card in
                let offset = CGFloat(index) // Offset for visual separation
                TransformableCardView(card: card, xOffset: offset, yOffset: -offset)
                    .hueRotation(Angle(degrees: -90))
            }
        }
        .padding() // Add padding for layout spacing
    }
}

// MARK: - Preview

struct TrumpView_Previews: PreviewProvider {
    static var previews: some View {
        @Namespace var cardAnimationNamespace
        let gameManager = GameManager()
        gameManager.setupPreviewGameState()

        return TrumpView(namespace: cardAnimationNamespace)
            .environmentObject(gameManager)
            .previewDisplayName("Trump cards Preview")
            .previewLayout(.sizeThatFits)
    }
}
