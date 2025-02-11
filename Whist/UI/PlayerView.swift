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
                    VStack {
                        if player.tablePosition == .left {
                            HStack {
                                PlayerInfo(dynamicSize: dynamicSize)
                                StateDisplay()
                                    .offset(y: -20)
                            }
                            .frame(width: dynamicSize.sidePlayerInfoWidth)
                            HStack {
                                PlayerHand(dynamicSize: dynamicSize)
                                    .frame(width: dynamicSize.sidePlayerHandWidth, height: dynamicSize.sidePlayerHandHeight)
                                ZStack {
                                    // Dealer button overlay
                                    VStack {
                                        if isDealer {
                                            DealerButton(size: dynamicSize.dealerButtonSize)
                                                .offset(dynamicSize.dealerButtonLeftOffset)
                                                .animation(.easeInOut, value: isDealer)
                                        }
                                    }
                                    .frame(maxHeight: .infinity, alignment: .top)
                                    if gameManager.allPlayersBet() || gameManager.gameState.round < 4 {
                                        TrickDisplay(dynamicSize: dynamicSize)
                                            .onTapGesture {
                                                gameManager.showLastTrick.toggle()
                                            }
                                    }
                                }
                                .frame(width: dynamicSize.sidePlayerWidth - dynamicSize.sidePlayerHandWidth, height: dynamicSize.sidePlayerHandHeight)
                            }
                            .frame(width: dynamicSize.sidePlayerWidth)
                        } else {
                            HStack {
                                StateDisplay()
                                    .offset(y: -20)
                                PlayerInfo(dynamicSize: dynamicSize)
                            }
                            .frame(width: dynamicSize.sidePlayerInfoWidth)
                            HStack {
                                ZStack {
                                    // Dealer button overlay
                                    VStack {
                                        if isDealer {
                                            DealerButton(size: dynamicSize.dealerButtonSize)
                                                .offset(dynamicSize.dealerButtonRightOffset)
                                                .animation(.easeInOut, value: isDealer)
                                        }
                                    }
                                    .frame(maxHeight: .infinity, alignment: .top)
                                    if gameManager.allPlayersBet() || gameManager.gameState.round < 4 {
                                        TrickDisplay(dynamicSize: dynamicSize)
                                            .onTapGesture {
                                                gameManager.showLastTrick.toggle()
                                            }
                                    }
                                }
                                .frame(width: dynamicSize.sidePlayerWidth - dynamicSize.sidePlayerHandWidth, height: dynamicSize.sidePlayerHandHeight)
                                PlayerHand(dynamicSize: dynamicSize)
                                    .frame(width: dynamicSize.sidePlayerHandWidth, height: dynamicSize.sidePlayerHandHeight)
                            }
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
                            if isDealer {
                                DealerButton(size: dynamicSize.dealerButtonSize)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .offset(dynamicSize.dealerButtonLocalOffset)
                                    .animation(.easeInOut, value: isDealer)
                            }
                        }
                        .frame(width: dynamicSize.localPlayerInfoWidth, height: dynamicSize.localPlayerInfoHeight)
                        Spacer()
                        PlayerHand(dynamicSize: dynamicSize)
                            .frame(width: dynamicSize.localPlayerHandWidth, height: dynamicSize.localPlayerHandHeight)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
    
    // MARK: - Player Info
    @ViewBuilder
    private func PlayerInfo(dynamicSize: DynamicSize) -> some View {
        ZStack {
            PlayerImageView(player: player, dynamicSize: dynamicSize)
        }
    }
    
    // MARK: - Trick Display
    @ViewBuilder
    private func TrickDisplay(dynamicSize: DynamicSize) -> some View {
        let roundIndex = gameManager.gameState.round - 1
        if player.announcedTricks.indices.contains(roundIndex) {
            Group {
                if player.tablePosition != .local {
                    VStack(spacing: dynamicSize.otherTrickSpacing) {
                        ForEach(0..<max(player.announcedTricks[roundIndex], player.madeTricks[roundIndex]), id: \.self) { index in
                            TrickStack(
                                index: index,
                                isExtra: index >= player.announcedTricks[roundIndex],
                                isVertical: true,
                                dynamicSize: dynamicSize
                            )
                        }
                    }
                } else {
                    HStack(spacing: dynamicSize.localTrickSpacing) {
                        ForEach(0..<max(player.announcedTricks[roundIndex], player.madeTricks[roundIndex]), id: \.self) { index in
                            TrickStack(
                                index: index,
                                isExtra: index >= player.announcedTricks[roundIndex],
                                isVertical: false,
                                dynamicSize: dynamicSize
                            )
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func TrickStack(index: Int, isExtra: Bool, isVertical: Bool, dynamicSize: DynamicSize) -> some View {
        let rotation: Double = isVertical ? 90 : 0
        
        ZStack {
            if index * 3 + 2 < player.trickCards.count {
                ForEach(0..<3, id: \.self) { cardIndex in
                    TransformableCardView(
                        card: player.trickCards[index * 3 + cardIndex],
                        scale: dynamicSize.trickScale,
                        rotation: rotation,
                        dynamicSize: dynamicSize
                    )
                }
                .hueRotation(isExtra ? .degrees(90) : .degrees(0))
            } else {
                PlaceholderTrick(dynamicSize: dynamicSize)
                    .rotationEffect(.degrees(90 - rotation))
            }
        }
        .frame(
            width: isVertical ? dynamicSize.cardHeight * dynamicSize.trickScale : dynamicSize.cardWidth * dynamicSize.trickScale,
            height: isVertical ? dynamicSize.cardWidth * dynamicSize.trickScale : dynamicSize.cardHeight * dynamicSize.trickScale
        )
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
                    Text(discardString(numberOfCardsToDiscard: numberOfCardsToDiscard))
                        .font(.system(size: dynamicSize.stateTextSize))
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
                        .font(.system(size: dynamicSize.stateTextSize))
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
                        .font(.system(size: dynamicSize.stateTextSize))
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
                        .font(.system(size: dynamicSize.stateTextSize))
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
        let handCount = player.hand.count
        
        if handCount == 0 {
            Spacer()
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
                let cardWidth = dynamicSize.cardWidth * dynamicSize.deckCardsScale
                let cardHeight = dynamicSize.cardHeight * dynamicSize.deckCardsScale
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
                        scale: player.tablePosition == .local ? dynamicSize.proportion : dynamicSize.sidePlayerCardScale,
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
    
    func discardString(numberOfCardsToDiscard: Int) -> String {
        var message: String = ""
        if gameManager.gameState.localPlayer?.place == 2 && gameManager.gameState.round == 12 {
            if Double(gameManager.gameState.lastPlayer?.scores[safe: gameManager.gameState.round - 2] ?? 0) <= 0.5 * Double(gameManager.gameState.localPlayer?.scores[safe: gameManager.gameState.round - 2] ?? 0) || gameManager.gameState.lastPlayer?.monthlyLosses ?? 0 > 0 {
                message = "Donne une carte à \(gameManager.gameState.lastPlayer?.username ?? "l'adversaire")"
            }
        } else {
            message = "Défausse \(numberOfCardsToDiscard) carte\(numberOfCardsToDiscard > 1 ? "s" : "")"
        }
        return message
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
        manager.gameState.localPlayer?.hand.removeAll()
        manager.gameState.leftPlayer?.hand.removeAll()
        manager.gameState.rightPlayer?.hand.removeAll()
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
