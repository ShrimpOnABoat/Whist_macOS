//
//  LastTrickView.swift
//  Whist
//
//  Created by Tony Buffard on 2025-01-23.
//


import SwiftUI

struct LastTrickView: View {
    @ObservedObject var gameState: GameState

    var body: some View {
        VStack {
            if gameState.lastTrick.isEmpty {
                Text("Pas de dernier pli")
                    .font(.headline)
                    .foregroundColor(.gray)
            } else {
                GeometryReader { geometry in
                    ZStack {
                        ForEach(gameState.lastTrickCardStates.sorted(by: { $0.value.zIndex < $1.value.zIndex }), id: \.key) { playerId, cardState in
                            if let card = gameState.lastTrick[playerId] {
                                TransformableCardView(
                                    card: card,
                                    rotation: cardState.rotation,
                                    xOffset: cardState.position.x - geometry.size.width / 2,
                                    yOffset: cardState.position.y - geometry.size.height / 2
                                )
                                .zIndex(cardState.zIndex) // Apply the stored z-index
                            }
                        }
                    }
                }
                .coordinateSpace(name: "contentArea")
            }
        }
        .padding()
    }
}

// Preview
struct LastTrickView_Previews: PreviewProvider {
    static var previews: some View {
        let gameManager = GameManager()
        gameManager.setupPreviewGameState()
        
        return LastTrickView(gameState: gameManager.gameState)
            .frame(width: 400, height: 180)
    }
}
