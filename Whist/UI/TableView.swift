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
    let namespace: Namespace.ID
    
    init(gameState: GameState, namespace: Namespace.ID) {
        self.gameState = gameState
        self.namespace = namespace
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                let offset: CGFloat = 50
                let localOffset: CGPoint = CGPoint(x: CGFloat.random(in: -10...10), y: CGFloat.random(in: -10...10))
                let leftOffset: CGPoint = CGPoint(x: CGFloat.random(in: -10...10), y: CGFloat.random(in: -10...10))
                let rightOffset: CGPoint = CGPoint(x: CGFloat.random(in: -10...10), y: CGFloat.random(in: -10...10))
                let localAngle: CGFloat = CGFloat.random(in: -10...10)
                let leftAngle: CGFloat = CGFloat.random(in: -10...10)
                let rightAngle: CGFloat = CGFloat.random(in: -10...10)
                

                if let localPlayer = gameState.localPlayer,
                   let localIndex = gameState.playOrder.firstIndex(of: localPlayer.id),
                   localIndex < gameState.table.count {
                    let card = gameState.table[localIndex]
                    CardView(card: card)
                        .rotationEffect(Angle(degrees: card.rotation + localAngle))
                        .frame(width: 60, height: 90)
                        .offset(x: localOffset.x, y: card.offset + localOffset.y)
                        .matchedGeometryEffect(id: card.id, in: namespace)
                        .zIndex(Double(localIndex))
                }
                
                // Left Player's Card (Left)
                if let leftPlayer = gameState.leftPlayer,
                   let leftIndex = gameState.playOrder.firstIndex(of: leftPlayer.id),
                   leftIndex < gameState.table.count {
                    let card = gameState.table[leftIndex]
                    CardView(card: card)
                        .rotationEffect(Angle(degrees: card.rotation + leftAngle + CGFloat(90)))
                        .frame(width: 60, height: 90)
                        .offset(x: -offset + card.offset + leftOffset.x, y: -offset + leftOffset.y)
                        .matchedGeometryEffect(id: card.id, in: namespace)
                        .zIndex(Double(leftIndex))
                }
                
                // Right Player's Card (Right)
                if let rightPlayer = gameState.rightPlayer,
                   let rightIndex = gameState.playOrder.firstIndex(of: rightPlayer.id),
                   rightIndex < gameState.table.count {
                    let card = gameState.table[rightIndex]
                    CardView(card: card)
                        .rotationEffect(Angle(degrees: card.rotation + CGFloat(90)))
                        .frame(width: 60, height: 90)
                        .offset(x: offset + card.offset + rightOffset.x, y: -offset + rightOffset.y)
                        .matchedGeometryEffect(id: card.id, in: namespace)
                        .zIndex(Double(rightIndex))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cornerRadius(12)
        }
    }
}

// MARK: - Preview

struct TableView_Previews: PreviewProvider {
    static var previews: some View {
        @Namespace var cardAnimationNamespace
        let gameManager = GameManager()
        gameManager.setupPreviewGameState()
        
        return
        ZStack {
            FeltBackgroundView(wearIntensity: 0)
            TableView(gameState: gameManager.gameState, namespace: cardAnimationNamespace)
                .environmentObject(gameManager)
                .previewDisplayName("Table View Preview")
                .previewLayout(.fixed(width: 600, height: 400))
        }
    }
}
