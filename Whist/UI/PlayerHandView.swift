//
//  PlayerHandView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-12-06.
//

import SwiftUI

struct PlayerHandView: View {
    @EnvironmentObject var gameManager: GameManager
    @ObservedObject var player: Player // Observes changes in the player's hand
    let namespace: Namespace.ID
    
    var body: some View {
        GeometryReader { geometry in
            let fanRadius: CGFloat = 300
            let minCardAngle: CGFloat = 5
            let cardSize = CGSize(width: 60, height: 90)
            
            let handCount = player.hand.count
            
            if handCount == 0 {
                EmptyView()
            } else {
                let angleBetweenCards = min(minCardAngle, 180 / CGFloat(handCount))
                let totalAngle = angleBetweenCards * CGFloat(handCount - 1)
                let startAngle = -totalAngle / 2
                
                // Track the min/max coordinates as we place each card
                var minX: CGFloat = .infinity
                var maxX: CGFloat = -.infinity
                var minY: CGFloat = .infinity
                var maxY: CGFloat = -.infinity
                
                // Pre-compute card positions to find bounding box
                let cardPositions = player.hand.enumerated().map { (cardIndex, card) -> (Card, CGFloat, CGFloat, CGFloat) in
                    let cardAngle = startAngle + CGFloat(cardIndex) * angleBetweenCards
                    let angleInRadians = cardAngle * .pi / 180
                    var xOffset = fanRadius * sin(angleInRadians)
                    var yOffset = fanRadius * (1 - cos(angleInRadians))
                    var rotation = cardAngle
                    
                    let isLeft = (player.tablePosition == .left)
                    let isRight = (player.tablePosition == .right)
                    // Adjust for left or right players
                    (xOffset, yOffset, rotation) = adjustedCardPositionAndRotation(
                        xOffset: xOffset,
                        yOffset: yOffset,
                        rotation: rotation,
                        isLeft: isLeft,
                        isRight: isRight
                    )
                    
                    // Compute bounding box of the rotated card
                    let cardWidth = cardSize.width
                    let cardHeight = cardSize.height
                    let rad = rotation * .pi / 180
                    
                    // Width and height of rotated bounding box
                    let rotatedWidth = abs(cardWidth * cos(rad)) + abs(cardHeight * sin(rad))
                    let rotatedHeight = abs(cardHeight * cos(rad)) + abs(cardWidth * sin(rad))
                    
                    // Update global min/max
                    let halfW = rotatedWidth / 2
                    let halfH = rotatedHeight / 2
                    
                    minX = min(minX, xOffset - halfW)
                    maxX = max(maxX, xOffset + halfW)
                    minY = min(minY, yOffset - halfH)
                    maxY = max(maxY, yOffset + halfH)
                    
                    return (card, xOffset, yOffset, rotation)
                }
                
                let computedWidth = maxX - minX
                let computedHeight = maxY - minY
                
                // Align the ZStack so that minX and minY map to zero origin
                ZStack {
                    ForEach(cardPositions, id: \.0.id) { (card, xOffset, yOffset, rotation) in
                        CardView(card: card)
                            .frame(width: cardSize.width, height: cardSize.height)
                            .rotationEffect(Angle(degrees: rotation))
                            .offset(
                                x: xOffset - minX - computedWidth/2,  // Shift so minX aligns with the left of the ZStack
                                y: yOffset - minY - computedHeight/2   // Shift so minY aligns with the top of the ZStack
                            )
                            .matchedGeometryEffect(id: card.id, in: namespace)
                            .transition(
                                .asymmetric(
                                    insertion: AnyTransition.modifier(
                                        active: CustomRotationModifier(
                                            rotation: 0,
                                            finalRotation: rotation,
                                            offset: CGSize(width: 0, height: geometry.size.height)
                                        ),
                                        identity: CustomRotationModifier(
                                            rotation: rotation,
                                            finalRotation: rotation,
                                            offset: .zero
                                        )
                                    ),
                                    removal: .scale.combined(with: .opacity)
                            ))
                    }
                }
                .animation(.smooth(duration: 0.3), value: player.hand)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)            }
        }
    }
    
    // Custom ViewModifier to handle rotation and offset
    struct CustomRotationModifier: ViewModifier {
        var rotation: CGFloat
        var finalRotation: CGFloat
        var offset: CGSize
        
        func body(content: Content) -> some View {
            content
                .rotationEffect(Angle(degrees: rotation))
                .offset(offset)
                .opacity(offset == .zero ? 1 : 0.5)
                .animation(.easeInOut(duration: 0.3)) { view in
                    view.rotationEffect(Angle(degrees: offset == .zero ? finalRotation : 0))
                }
        }
    }

    func adjustedCardPositionAndRotation(
        xOffset: CGFloat,
        yOffset: CGFloat,
        rotation: CGFloat,
        isLeft: Bool,
        isRight: Bool
    ) -> (xOffset: CGFloat, yOffset: CGFloat, rotation: CGFloat) {
        var newXOffset = xOffset
        var newYOffset = yOffset
        var newRotation = rotation
        
        if isLeft {
            let temp = newXOffset
            newXOffset = newYOffset
            newYOffset = -temp
            newRotation += 90
        } else if isRight {
            let temp = newXOffset
            newXOffset = -newYOffset
            newYOffset = temp
            newRotation -= 90
        }
        
        return (newXOffset, newYOffset, newRotation)
    }
}

// MARK: - Preview

struct PlayerHandView_Previews: PreviewProvider {
    static var previews: some View {
        @Namespace var cardAnimationNamespace
        let gameManager = GameManager()
        gameManager.setupPreviewGameState()
        
        // Extract players from the game state
        let localPlayer = gameManager.gameState.localPlayer!
        let leftPlayer = gameManager.gameState.leftPlayer!
        let rightPlayer = gameManager.gameState.rightPlayer!
        
        return Group {
            PlayerHandView(player: localPlayer, namespace: cardAnimationNamespace)
                .environmentObject(gameManager)
                .previewDisplayName("Local Player Hand View Preview")
            PlayerHandView(player: leftPlayer, namespace: cardAnimationNamespace)
                .environmentObject(gameManager)
                .previewDisplayName("Local Player Hand View Preview")
            PlayerHandView(player: rightPlayer, namespace: cardAnimationNamespace)
                .environmentObject(gameManager)
                .previewDisplayName("Local Player Hand View Preview")
            
        }
        .previewLayout(.sizeThatFits)
    }
}
