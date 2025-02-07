//
//  PlayerView.swift
//  Whist
//
//  Created by Tony Buffard on 2025-01-13.
//

import SwiftUI

// MARK: PlayerView

struct PlayerView: View {
    @EnvironmentObject var gameManager: GameManager
    @ObservedObject var player: Player
    let dynamicSize: DynamicSize
    let isDealer: Bool
    
    @State private var selectedCardIDs: Set<String> = []
    @State private var displayedMessage: String = ""
    
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                if player.tablePosition != .local {
                    HStack(spacing: dynamicSize.playerViewHorizontalSpacing) {
                        if player.tablePosition == .left {
                            PlayerHand(dynamicSize: dynamicSize)
                        }
                        VStack {
                            StateDisplay()
                            PlayerInfo(dynamicSize: dynamicSize)
                            if gameManager.allPlayersBet() || gameManager.gameState.round < 4 {
                                TrickDisplay(dynamicSize: dynamicSize)
                                    .onTapGesture {
                                        gameManager.showLastTrick.toggle()
                                    }
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                        if player.tablePosition == .right {
                            PlayerHand(dynamicSize: dynamicSize)
                        }
                    }
                } else {
                    // Display player info and hand (horizontal layout for the local player)
                    VStack {
                        ZStack {
                            VStack {
                                StateDisplay()
                                TrickDisplay(dynamicSize: dynamicSize)
                                    .onTapGesture {
                                        gameManager.showLastTrick.toggle()
                                    }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            PlayerInfo(dynamicSize: dynamicSize)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: geometry.size.width * 0.5, maxHeight: .infinity)
                        PlayerHand(dynamicSize: dynamicSize)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding()
        }
    }
    
    // MARK: - Player Info
    @ViewBuilder
    private func PlayerInfo(dynamicSize: DynamicSize) -> some View {
        ZStack {
            PlayerImageView(player: player, dynamicSize: dynamicSize)
            
            // Dealer button overlay
            if isDealer {
                DealerButton(size: dynamicSize.dealerButtonSize)
                    .offset(player.tablePosition == .local ? dynamicSize.dealerButtonLocalOffset : CGSize(width: (player.tablePosition == .left ? dynamicSize.dealerButtonSideOffset.x : -dynamicSize.dealerButtonSideOffset.x), height: -dynamicSize.dealerButtonSideOffset.y))
                    .animation(.easeInOut, value: isDealer)
            }
        }
    }
    
    // MARK: - Trick Display
    @ViewBuilder
    private func TrickDisplay(dynamicSize: DynamicSize) -> some View {
        let roundIndex = gameManager.gameState.round - 1
        if player.announcedTricks.indices.contains(roundIndex) {
            if player.tablePosition != .local {
                VStack(spacing: dynamicSize.otherTrickSpacing) {
                    // Announced Tricks
                    ForEach(0..<player.announcedTricks[roundIndex], id: \.self) { index in
                        if index * 3 + 2 < player.trickCards.count {
                            ZStack {
                                ForEach(0..<3, id: \.self) { cardIndex in
                                    TransformableCardView(card: player.trickCards[index * 3 + cardIndex], scale: dynamicSize.trickScale, rotation: 90, dynamicSize: dynamicSize)
                                }
                            }
                        } else {
                            PlaceholderTrick(dynamicSize: dynamicSize)
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
                                        TransformableCardView(card: player.trickCards[extraIndex + cardIndex], scale: dynamicSize.trickScale, rotation: 90, dynamicSize: dynamicSize)
                                    }
                                }
                                .hueRotation(Angle(degrees: 90))
                            }
                        }
                    }
                }
            } else { // local player
                HStack(spacing: dynamicSize.localTrickSpacing) {
                    // Announced Tricks
                    ForEach(0..<player.announcedTricks[roundIndex], id: \.self) { index in
                        if index * 3 + 2 < player.trickCards.count {
                            ZStack {
                                ForEach(0..<3, id: \.self) { cardIndex in
                                    TransformableCardView(card: player.trickCards[index * 3 + cardIndex], scale: dynamicSize.trickScale, dynamicSize: dynamicSize)
                                }
                            }
                        } else {
                            PlaceholderTrick(dynamicSize: dynamicSize).rotationEffect(.degrees(90))
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
                                        TransformableCardView(card: player.trickCards[extraIndex + cardIndex], scale: dynamicSize.trickScale, dynamicSize: dynamicSize)
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
    
    // MARK: State Display
    
    struct HoverMoveUpButtonStyle: ButtonStyle {
        let isActive: Bool
        @State private var yOffset: CGFloat = 0 // State to track offset changes
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.95 : 1.0) // Add a slight scale effect when pressed
                .offset(y: configuration.isPressed ? -2 : (isActive ? yOffset : 0)) // Use state for hover effect
                .animation(.easeInOut(duration: 0.05), value: configuration.isPressed)
                .animation(.easeInOut(duration: 0.05), value: yOffset)
                .onHover { isHovering in
                    if isActive {
                        withAnimation {
                            yOffset = isHovering ? -3 : 0
                        }
                    }
                }
        }
    }
    
    @ViewBuilder
    private func StateDisplay() -> some View {
        if gameManager.gameState.currentPhase == .discard && player.tablePosition == .local {
            let numberOfCardsToDiscard = (gameManager.gameState.localPlayer?.hand.count ?? 0) - max(1, gameManager.gameState.round - 2)
            let selectedCount = selectedCardIDs.count
            
            VStack {
                Button(action: {
                    let cardsToDiscard = player.hand.filter { selectedCardIDs.contains($0.id) }
                    gameManager.discard(cardsToDiscard: cardsToDiscard) {
                        selectedCardIDs.removeAll()
                        gameManager.checkAndAdvanceStateIfNeeded()
                    }
                }) {
                    Text("Défausse \(numberOfCardsToDiscard) carte\(numberOfCardsToDiscard > 1 ? "s" : "")")
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(selectedCount == numberOfCardsToDiscard ? Color.green : Color.white.opacity(0.5)) // Active vs Inactive
                        .foregroundColor(selectedCount == numberOfCardsToDiscard ? Color.white : Color.black)
                        .cornerRadius(5)
                        .shadow(radius: 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(selectedCount == numberOfCardsToDiscard ? Color.green : Color.white, lineWidth: 2)
                        )
                }
                .buttonStyle(HoverMoveUpButtonStyle(isActive: selectedCount == numberOfCardsToDiscard))
                .disabled(selectedCount != numberOfCardsToDiscard)
                .animation(.easeInOut, value: selectedCount) // Smooth animation for state changes
            }
        } else if gameManager.gameState.currentPhase == .waitingToStart && player.tablePosition == .local {
            VStack {
                Button(action: {
                    gameManager.startNewGameAction()
                }) {
                    Text("Nouvelle partie")
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(5)
                        .shadow(radius: 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
                .buttonStyle(HoverMoveUpButtonStyle(isActive: true))
            }
        } else {
            // Define the message based on the player's state
            let newMessage: String = {
                if player.tablePosition != .local {
                    switch player.state {
                    case .idle: return ""
                    case .choosingTrump: return "Choisit l'atout"
                    case .bidding: return "Choisit sa mise"
                    case .discarding: return "Défausse sa carte"
                    case .playing: return "Joue une carte"
                    case .waiting: return "Attend les autres"
                    default: return ""
                    }
                } else {
                    switch player.state {
                    case .idle: return ""
                    case .choosingTrump: return "Choisis l'atout"
                    case .bidding: return "Choisis une mise"
                    case .discarding: return "Défausse tes cartes"
                    case .playing: return "Joue une carte"
                    case .waiting: return ""
                    default: return ""
                    }
                }
            }()
            
            // Update the message with animation when it changes
            VStack {
                if !displayedMessage.isEmpty {
                    Text(displayedMessage)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(Color.white.opacity(0.5))
                        .cornerRadius(5)
                        .shadow(radius: 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.3), value: displayedMessage)
                } else {
                    Text(displayedMessage)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(Color.white.opacity(0.5))
                        .cornerRadius(5)
                        .shadow(radius: 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.3), value: displayedMessage)
                        .opacity(0)
                }
            }
            .onAppear {
                displayedMessage = newMessage
            }
            .onChange(of: player.state) { _, _ in
                withAnimation {
                    displayedMessage = newMessage
                }
            }
        }
    }
    
    // MARK: - Player Hand
    @ViewBuilder
    private func PlayerHand(dynamicSize: DynamicSize) -> some View {
        //        let fanRadius: CGFloat = 300
        //        let minCardAngle: CGFloat = 5
        let handCount = player.hand.count
        
        if handCount == 0 {
            EmptyView()
        } else {
            let angleBetweenCards = min(dynamicSize.minCardAngle, 180 / CGFloat(handCount))
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
                var xOffset = dynamicSize.fanRadius * sin(angleInRadians)
                var yOffset = dynamicSize.fanRadius * (1 - cos(angleInRadians))
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
                let cardWidth = dynamicSize.cardWidth
                let cardHeight = dynamicSize.cardHeight
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
                        },
                        dynamicSize: dynamicSize
                    )
                }
            }
        }
    }
    
    // MARK: - Placeholder Trick
    @ViewBuilder
    private func PlaceholderTrick(dynamicSize: DynamicSize) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(Color.gray, style: StrokeStyle(lineWidth: 2))
            .opacity(0.8)
            .blendMode(.multiply)
            .frame(width: dynamicSize.cardHeight * dynamicSize.trickScale,
                   height: dynamicSize.cardWidth * dynamicSize.trickScale)
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
    var dynamicSize: DynamicSize
    
    var body: some View {
        VStack {
            // Player Picture
            if player.connected {
                (player.image ?? Image(systemName: "person.crop.circle"))
                    .resizable()
                    .frame(width: dynamicSize.playerImageWidth, height: dynamicSize.playerImageHeight)
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
    // Set up a shared game manager for previews
    static var gameManager: GameManager = {
        let manager = GameManager()
        manager.setupPreviewGameState()
        return manager
    }()
    
    static var previews: some View {
        Group {
            // Local Player Preview
            GeometryReader { geometry in
                let dynamicSize = DynamicSize(from: geometry)
                PlayerView(player: gameManager.gameState.localPlayer!, dynamicSize: dynamicSize, isDealer: true)
                    .environmentObject(gameManager)
            }
            .previewDisplayName("Local Player View")
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.gray.opacity(0.2))
            .frame(width: 800, height: 600)
            
            // Left Player Preview
            GeometryReader { geometry in
                let dynamicSize = DynamicSize(from: geometry)
                PlayerView(player: gameManager.gameState.leftPlayer!, dynamicSize: dynamicSize, isDealer: true)
                    .environmentObject(gameManager)
            }
            .previewDisplayName("Left Player View")
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.gray.opacity(0.2))
            .frame(width: 800, height: 600)
            
            // Right Player Preview
            GeometryReader { geometry in
                let dynamicSize = DynamicSize(from: geometry)
                PlayerView(player: gameManager.gameState.rightPlayer!, dynamicSize: dynamicSize, isDealer: true)
                    .environmentObject(gameManager)
            }
            .previewDisplayName("Right Player View")
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color.gray.opacity(0.2))
            .frame(width: 800, height: 600)
        }
    }
}
