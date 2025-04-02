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
    
    @State private var dealerFrame: CGRect = .zero
    @State private var selectedCardIDs: Set<String> = []
//    @State private var displayedMessage: String = ""
    @State private var scoreChange: Int? = nil
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main view content
                VStack {
                    if player.tablePosition != .local {
                        NonLocalPlayerView
                    } else {
                        LocalPlayerView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            // Listen for score updates at the top level of PlayerView.
            .onChange(of: gameManager.playersScoresUpdated) { _ in
                logger.log("Scores are updated")
                let currentScore = player.scores.last ?? 0
                let previousScore = player.scores.dropLast().last ?? 0
                let change = currentScore - previousScore
                if change != 0 {
                    scoreChange = change
                    // Clear the score change after the animation completes.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        scoreChange = nil
                    }
                }
            }
            // Overlay the score change animation.
            .overlay(
                Group {
                    if let change = scoreChange {
                        ScoreChangeView(scoreChange: change, delay: 0)
                    }
                }
            )
        }
    }
    
    private var LocalPlayerView: some View {
            // Local player layout
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
                        HStack {
                            Spacer()
                            Circle()
                                .frame(width: dynamicSize.dealerButtonSize, height: dynamicSize.dealerButtonSize)
                                .opacity(0)
                                .overlay(
                                    GeometryReader { proxy in
                                        Color.clear
                                            .onAppear {
                                                let frame = proxy.frame(in: .named("contentArea"))
                                                logger.log("Captured frame: \(frame)")
                                                gameManager.updateDealerFrame(playerId: player.id, frame: frame)
                                            }
                                    }
                                )
                        }
                    }
                }
                .frame(width: dynamicSize.localPlayerInfoWidth, height: dynamicSize.localPlayerInfoHeight)
                Spacer()
                ZStack {
                    PlayerHand(dynamicSize: dynamicSize)
                        .frame(width: dynamicSize.localPlayerHandWidth, height: dynamicSize.localPlayerHandHeight)
                        if [.playingTricks, .grabTrick].contains(gameManager.gameState.currentPhase) {
                            HStack {
                                Spacer()
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        gameManager.autoPilot.toggle()
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Text("Autoplay")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.white)

                                        Circle()
                                            .fill(gameManager.autoPilot ? Color.green : Color.red)
                                            .frame(width: 10, height: 10)
                                            .shadow(color: (gameManager.autoPilot ? Color.green : Color.red).opacity(0.8), radius: (gameManager.autoPilot ? 6 : 0))
                                            .animation(.easeInOut(duration: 0.1), value: gameManager.autoPilot)
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(Color(nsColor: .darkGray))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibility(label: Text(gameManager.autoPilot ? "Disable Autopilot" : "Enable Autopilot"))
                                .help(gameManager.autoPilot ? "Disable autopilot mode" : "Enable autopilot mode")
                                .padding(.trailing, 16)
                                .padding(.bottom, 16)
                            }
                        }
                }
            }
    }
    
    private var NonLocalPlayerView: some View {
            // Non-local player layout
            VStack {
                if player.tablePosition == .left {
                    HStack {
                        PlayerInfo(dynamicSize: dynamicSize)
                        StateDisplay()
                            .offset(y: dynamicSize.sidePlayerStateYOffset)
                    }
                    .frame(width: dynamicSize.sidePlayerInfoWidth)
                    HStack {
                        PlayerHand(dynamicSize: dynamicSize)
                            .frame(width: dynamicSize.sidePlayerHandWidth, height: dynamicSize.sidePlayerHandHeight)
                        ZStack {
                            // Dealer button overlay
                            VStack {
                                if isDealer {
                                    Circle()
                                        .frame(width: dynamicSize.dealerButtonSize, height: dynamicSize.dealerButtonSize)
                                        .opacity(0)
                                        .background(GeometryReader { proxy in
                                            Color.clear
                                                .onAppear {
                                                    let frame = proxy.frame(in: .named("contentArea"))
                                                    gameManager.updateDealerFrame(playerId: player.id, frame: frame)
                                                }
                                        })
                                }
                            }
                            .frame(maxHeight: .infinity, alignment: .top)
                            if gameManager.allPlayersBet() || gameManager.gameState.round < 4 {
                                Button(action: {
                                    gameManager.showLastTrick.toggle()
                                }) {
                                    TrickDisplay(dynamicSize: dynamicSize)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .keyboardShortcut(.space, modifiers: [])
                            }
                        }
                        .frame(width: dynamicSize.sidePlayerWidth - dynamicSize.sidePlayerHandWidth, height: dynamicSize.sidePlayerHandHeight)
                    }
                    .frame(width: dynamicSize.sidePlayerWidth)
                } else {
                    HStack {
                        StateDisplay()
                            .offset(y: dynamicSize.sidePlayerStateYOffset)
                        PlayerInfo(dynamicSize: dynamicSize)
                    }
                    .frame(width: dynamicSize.sidePlayerInfoWidth)
                    HStack {
                        ZStack {
                            // Dealer button overlay
                            VStack {
                                if isDealer {
                                    Circle()
                                        .frame(width: dynamicSize.dealerButtonSize, height: dynamicSize.dealerButtonSize)
                                        .opacity(0)
                                        .background(GeometryReader { proxy in
                                            Color.clear
                                                .onAppear {
                                                    let frame = proxy.frame(in: .named("contentArea"))
                                                    gameManager.updateDealerFrame(playerId: player.id, frame: frame)
                                                }
                                        })
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
                    ZStack {
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
                    }
                } else {
                    ZStack {
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
                .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                .offset(y: configuration.isPressed ? -2 : (isActive ? yOffset : 0))
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
                        .background(selectedCount == numberOfCardsToDiscard ? Color.green : Color.white.opacity(0.5))
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
                .animation(.easeInOut, value: selectedCount)
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
            let stateMessage: String = {
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
            
            VStack {
                if !stateMessage.isEmpty {
                    Text(stateMessage)
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
                        .animation(.easeInOut(duration: 0.3), value: player.state)
                } else {
                    Text("")
                        .font(.system(size: dynamicSize.stateTextSize))
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .opacity(0)
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

// MARK: PlayerImageView

struct PlayerImageView: View {
    @EnvironmentObject var gameManager: GameManager
    let player: Player
    var dynamicSize: DynamicSize
    
    var body: some View {
        VStack {
            // Player Picture
            if player.isConnected {
                (player.image ?? Image(systemName: "person.crop.circle"))
                    .resizable()
                    .frame(width: dynamicSize.playerImageWidth, height: dynamicSize.playerImageHeight)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            } else {
                Image(systemName: "person.crop.circle.badge.xmark")
                    .resizable()
                    .frame(width: dynamicSize.playerImageWidth, height: dynamicSize.playerImageHeight)
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

// MARK: ScoreChangeView

struct ScoreChangeView: View {
    let scoreChange: Int
    let delay: Double
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var scale: CGFloat = 1.5
    
    var body: some View {
        Text(scoreChange > 0 ? "+\(scoreChange)" : "\(scoreChange)")
            .font(.system(size: 30, weight: .bold))
            .foregroundColor(scoreChange > 0 ? .green : .red)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(y: offset)
            .onAppear {
                withAnimation(.easeOut(duration: 2.5).delay(delay)) {
                    offset = -100
                    opacity = 0
                    scale = 1.0
                }
            }
    }
}
