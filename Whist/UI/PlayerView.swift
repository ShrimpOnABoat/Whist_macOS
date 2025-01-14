//
//  PlayerView.swift
//  Whist
//
//  Created by Tony Buffard on 2025-01-13.
//

import SwiftUI

struct PlayerView: View {
    @EnvironmentObject var gameManager: GameManager
    @ObservedObject var player: Player
    let isDealer: Bool
    
    @State private var selectedCardIDs: Set<String> = []

    var body: some View {
        GeometryReader { geometry in
            VStack {
                if player.tablePosition != .local {
                    HStack(spacing: 30) {
                        if player.tablePosition == .left {
                            PlayerHand()
                        }
                        VStack {
                            PlayerInfo()
                            if gameManager.allPlayersBet() {
                                TrickDisplay()
                            }
                        }
                        if player.tablePosition == .right {
                            PlayerHand()
                        }
                    }
                } else {
                    // Display player info and hand (horizontal layout for the local player)
                    VStack {
                        HStack {
                            PlayerInfo()
                            TrickDisplay()
                        }
                        PlayerHand()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding()
        }
    }
    
    // MARK: - Player Info
    @ViewBuilder
    private func PlayerInfo() -> some View {
        ZStack {
            PlayerImageView(player: player)
            
            // Dealer button overlay
            if isDealer {
                DealerButton(size: 30)
                    .offset(player.tablePosition == .local ? CGSize(width: -40, height: -30) : CGSize(width: (player.tablePosition == .left ? 50 : -50), height: -20))
                    .animation(.easeInOut, value: isDealer)
            }
        }
    }
    
    // MARK: - Trick Display
    @ViewBuilder
    private func TrickDisplay() -> some View {
        if gameManager.currentPhase == .discard && player.tablePosition == .local {
            let numberOfCardsToDiscard = (gameManager.gameState.localPlayer?.hand.count ?? 0) - max(1, gameManager.gameState.round - 2)
            let selectedCount = selectedCardIDs.count
            
            VStack {
                Button(action: {
                    let cardsToDiscard = player.hand.filter { selectedCardIDs.contains($0.id) }
                    gameManager.discard(cardsToDiscard: cardsToDiscard) {
                        selectedCardIDs.removeAll()
                    }
                })
                {
                    Text("Défausse \(numberOfCardsToDiscard) carte\(numberOfCardsToDiscard > 1 ? "s" :"")")
                        .padding()
                        .background(selectedCount == numberOfCardsToDiscard ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(selectedCount != numberOfCardsToDiscard)
            }
        } else {
            let roundIndex = gameManager.gameState.round - 1
            if player.announcedTricks.indices.contains(roundIndex) {
                if player.tablePosition != .local {
                    VStack(spacing: 0) {
                        // Announced Tricks
                        ForEach(0..<player.announcedTricks[roundIndex], id: \.self) { index in
                            if index * 3 + 2 < player.trickCards.count {
                                ZStack {
                                    ForEach(0..<3, id: \.self) { cardIndex in
                                        TransformableCardView(card: player.trickCards[index * 3 + cardIndex], scale: 1 / 3, rotation: 90)
                                    }
                                }
                            } else {
                                PlaceholderTrick()
                            }
                        }
                        
                        // Extra Tricks
                        let extraTricks = player.madeTricks[roundIndex] - player.announcedTricks[roundIndex]
                        if extraTricks > 0 {
                            ForEach(0..<extraTricks, id: \.self) { index in
                                let extraIndex = (index + player.announcedTricks[roundIndex]) * 3
                                if extraIndex + 2 < player.trickCards.count {
                                    ZStack {
                                        ForEach(0..<3, id: \.self) { cardIndex in
                                            TransformableCardView(card: player.trickCards[extraIndex + cardIndex], scale: 1 / 3, rotation: 90)
                                        }
                                    }
                                    .hueRotation(Angle(degrees: 90))
                                }
                            }
                        }
                    }
                } else { // local player
                    HStack(spacing: 5) {
                        // Announced Tricks
                        ForEach(0..<player.announcedTricks[roundIndex], id: \.self) { index in
                            if index * 3 + 2 < player.trickCards.count {
                                ZStack {
                                    ForEach(0..<3, id: \.self) { cardIndex in
                                        TransformableCardView(card: player.trickCards[index * 3 + cardIndex], scale: 1 / 3)
                                    }
                                }
                            } else {
                                PlaceholderTrick().rotationEffect(.degrees(90))
                            }
                        }
                        
                        // Extra Tricks
                        let extraTricks = player.madeTricks[roundIndex] - player.announcedTricks[roundIndex]
                        if extraTricks > 0 {
                            ForEach(0..<extraTricks, id: \.self) { index in
                                let extraIndex = (index + player.announcedTricks[roundIndex]) * 3
                                if extraIndex + 2 < player.trickCards.count {
                                    ZStack {
                                        ForEach(0..<3, id: \.self) { cardIndex in
                                            TransformableCardView(card: player.trickCards[extraIndex + cardIndex], scale: 1 / 3)
                                        }
                                    }
                                    .hueRotation(Angle(degrees: 90))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Player Hand
    @ViewBuilder
    private func PlayerHand() -> some View {
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
            
            // Compute card positions
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
            
            let numberOfCardsToDiscard = (gameManager.gameState.localPlayer?.hand.count ?? 0) - max(1, gameManager.gameState.round - 2)
            let selectedCount = selectedCardIDs.count
            let canSelectMore = selectedCount < numberOfCardsToDiscard
            
            // Draw cards
            ZStack {
                ForEach(cardPositions, id: \.0.id) { (card, xOffset, yOffset, rotation) in
                    TransformableCardView(
                        card: card,
                        rotation: rotation,
                        xOffset: xOffset,
                        yOffset: yOffset,
                        isSelected: selectedCardIDs.contains(card.id),
                        canSelect: canSelectMore,
                        onTap: {
                            // Toggle card selection
                            if selectedCardIDs.contains(card.id) {
                                selectedCardIDs.remove(card.id)
                            } else {
                                selectedCardIDs.insert(card.id)
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Placeholder Trick
    @ViewBuilder
    private func PlaceholderTrick() -> some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(Color.gray, style: StrokeStyle(lineWidth: 2))
            .opacity(0.8)
            .blendMode(.multiply)
            .frame(width: 30, height: 20)
            .background(Color.white.opacity(0.2))
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
        
        if isRight {
            let temp = newXOffset
            newXOffset = newYOffset
            newYOffset = -temp
            newRotation += 90
        } else if isLeft {
            let temp = newXOffset
            newXOffset = -newYOffset
            newYOffset = temp
            newRotation -= 90
        }
        
        return (newXOffset, newYOffset, newRotation)
    }

}

// MARK: PlayerImageVIew

struct PlayerImageView: View {
    @EnvironmentObject var gameManager: GameManager
    let player: Player
    
    var body: some View {
        VStack {
            // Player Picture
            if player.connected {
                (player.image ?? Image(systemName: "person.crop.circle"))
                    .resizable()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            } else {
                Image(systemName: "person.crop.circle.badge.xmark")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.red)
                    .clipShape(Circle())
            }
            
            // Player Username
            Text(player.username)
                .font(.headline)
                .foregroundColor(.white)
        }
    }
}

// MARK: Preview

struct PlayerView_Previews: PreviewProvider {
    static var previews: some View {
        let gameManager = GameManager()
        gameManager.setupPreviewGameState()
        gameManager.currentPhase = .discard

        // Extract players from the game state
        let localPlayer = gameManager.gameState.localPlayer!
        let leftPlayer = gameManager.gameState.leftPlayer!
        let rightPlayer = gameManager.gameState.rightPlayer!

        return Group {
            PlayerView(player: localPlayer, isDealer: true)
                .environmentObject(gameManager)
                .previewDisplayName("Local Player View Preview")
            PlayerView(player: leftPlayer, isDealer: true)
                .environmentObject(gameManager)
                .previewDisplayName("Left Player View Preview")
            PlayerView(player: rightPlayer, isDealer: true)
                .environmentObject(gameManager)
                .previewDisplayName("Right Player View Preview")
        }
        .previewLayout(.sizeThatFits)
        .padding()
        .background(Color.gray.opacity(0.2))
    }
}
