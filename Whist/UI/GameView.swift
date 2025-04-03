//
//  GameView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  The primary game interface.

import SwiftUI

// MARK: - PreferenceKey

struct CardTransformPreferenceKey: PreferenceKey {
    typealias Value = [String: CardState]
    
    static var defaultValue: [String: CardState] = [:]
    
    static func reduce(value: inout [String: CardState], nextValue: () -> [String: CardState]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - GameView

struct GameView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var preferences: Preferences
    @State private var cardTransforms: [String: CardState] = [:]
    @State private var showMatchmaking: Bool = true
    @State private var showAlert: Bool = false
    @State private var showConfirmation: Bool = false
    @State private var savedGameExists: Bool = false
    @State private var playerID: String = ""
    @State private var showRoundHistory: Bool = false
    @State private var didMeasureDeck: Bool = false
    @State private var background: AnyView = AnyView(EmptyView())
    
    func refreshBackground() {
        logger.log("Refreshing backgroung")
            // Compute enabled indices off the main thread
            let enabledIndices = self.preferences.enabledRandomColors.enumerated().compactMap { (index, isEnabled) in
                isEnabled ? index : nil
            }
            // Pick a random index from enabled indices
            let randomIndex = enabledIndices.randomElement()
            // Determine the selected color based on the random index
            let selectedColor: Color = {
                if let randomIndex = randomIndex {
                    return GameConstants.feltColors[randomIndex]
                } else {
                    return .gray
                }
            }()
            // Determine wear intensity
            let wear: CGFloat = self.preferences.wearIntensity ? CGFloat.random(in: 0...1) : 0
        DispatchQueue.global(qos: .userInitiated).async {
            // Create the background view
            logger.log("Executing background refresh")
            let newBackground = AnyView(FeltBackgroundView(
                baseColor: selectedColor,
                radialShadingStrength: 0.5,
                wearIntensity: wear,
                motifVisibility: CGFloat.random(in: 0...0.5),
                motifScale: CGFloat.random(in: 0...1),
                showScratches: Bool.random()
            ))
            // Update UI on the main thread
            DispatchQueue.main.async {
                if let randomIndex = randomIndex {
                    self.preferences.selectedFeltIndex = randomIndex
                }
                self.background = newBackground
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let dynamicSize = DynamicSize(from: geometry)
            // Extract players from the game state
            if let localPlayer = gameManager.gameState.localPlayer,
               let leftPlayer = gameManager.gameState.leftPlayer,
               let rightPlayer = gameManager.gameState.rightPlayer,
               let dealer = gameManager.gameState.dealer {
                // Proceed with your ZStack and layout
                ZStack {
                    // Background
                    background
                    //                    GridOverlay(spacing: 50)
                    
                    // Effects layer (always under the cards but above the background)
                    ZStack {
                        if gameManager.showImpactEffect {
                            ProceduralImpactView()
                                .frame(width: 300, height: 300)
                                .position(gameManager.effectPosition)
                                .onAppear {
                                    gameManager.soundManager.playSound(named: "impact")
                                }
                            ProceduralCracksView()
                                .blur(radius: 1)
                                .blendMode(.multiply)
                                .frame(width: 250, height: 250)
                                .position(gameManager.effectPosition)
                        }
                        if gameManager.showSubtleFailureEffect {
                            SubtleFailureView()
                                .frame(width: 200, height: 200)
                                .position(gameManager.effectPosition)
                                .onAppear {
                                    gameManager.soundManager.playSound(named: "fail")
                                }
                        }
                    }
                }
                .zIndex(0)
                
                ZStack {
                    VStack(spacing: 0) {
                        HStack(alignment: .center, spacing: 0) {
                            PlayerView(player: leftPlayer, dynamicSize: dynamicSize, isDealer: dealer == leftPlayer.id)
                                .frame(width: dynamicSize.sidePlayerWidth, height: dynamicSize.sidePlayerHeight)
                            VStack(spacing: 0) {
                                Group {
                                    HStack {
                                        TrumpView(dynamicSize: dynamicSize)
                                        
                                        Button(action: {
                                            if gameManager.gameState.round > 1 {
                                                showRoundHistory.toggle()
                                            }
                                        }) {
                                            ScoreBoardView(dynamicSize: dynamicSize)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .keyboardShortcut(KeyEquivalent("s"), modifiers: [])
                                        
                                        DeckView(gameState: gameManager.gameState, dynamicSize: dynamicSize)
                                    }
                                }
                                .frame(width: dynamicSize.scoreboardWidth, height: dynamicSize.scoreboardHeight)
                                
                                ZStack {
                                    if !(gameManager.showLastTrick && gameManager.gameState.currentPhase == .playingTricks) {
                                        if gameManager.gameState.currentPhase != .choosingTrump {
                                            TableView(gameState: gameManager.gameState, dynamicSize: dynamicSize)
                                        } else {
                                            TableView(gameState: gameManager.gameState, dynamicSize: dynamicSize, mode: .trumps)
                                        }
                                    } else {
                                        // Display a background for the last trick
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.5)) // Background with opacity
                                                .overlay(
                                                    VStack {
                                                        Text(gameManager.gameState.lastTrick.isEmpty ? "Pas de dernier pli" : "Dernier pli")
                                                            .font(.headline)
                                                            .foregroundColor(.black)
                                                            .padding(.bottom, 8) // Ensure padding at the bottom
                                                        Spacer()
                                                    }
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.white, lineWidth: 2) // Add a white border
                                                )
                                        }
                                        
                                    }
                                }
                                .frame(width: dynamicSize.tableWidth, height: dynamicSize.tableHeight)
                            }
                            PlayerView(player: rightPlayer, dynamicSize: dynamicSize, isDealer: dealer == rightPlayer.id)
                                .frame(width: dynamicSize.sidePlayerWidth, height: dynamicSize.sidePlayerHeight)
                        }
                        PlayerView(player: localPlayer, dynamicSize: dynamicSize, isDealer: dealer == localPlayer.id)
                            .frame(width: dynamicSize.localPlayerWidth, height: dynamicSize.localPlayerHeight)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity) //, alignment: .bottom)
                    
                    ConfettiCannon(trigger: $gameManager.showConfetti, num: 100)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .coordinateSpace(name: "contentArea")
                .cameraShake(offset: $gameManager.cameraShakeOffset)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Debug: Players not set up yet.")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text("localPlayer: \(String(describing: gameManager.gameState.localPlayer))")
                    Text("leftPlayer: \(String(describing: gameManager.gameState.leftPlayer))")
                    Text("rightPlayer: \(String(describing: gameManager.gameState.rightPlayer))")
                    Text("Setting up game...")
                        .italic()
                }
                .padding()
                .background(Color.yellow.opacity(0.2)) // Light background for emphasis
                .cornerRadius(8) // Rounded corners
            }
            
            // MARK: Show Options
            // Overlay OptionsView if showOptions is true
            if gameManager.showOptions {
                ZStack {
                    OptionsView(dynamicSize: dynamicSize)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .zIndex(1) // Ensure it's above everything else
                .transition(.scale) // Smooth scaling effect
                .animation(.easeInOut, value: gameManager.showOptions)
            }
            
            // MARK: Dealer button
            DealerButton(size: dynamicSize.dealerButtonSize)
                .position(gameManager.dealerPosition)
                .animation(.easeOut, value: gameManager.dealerPosition)
            
            // MARK: Show last trick
            if gameManager.showLastTrick && gameManager.gameState.currentPhase == .playingTricks {
                ZStack {
                    if !gameManager.gameState.lastTrick.isEmpty {
                        GeometryReader { geometry in
                            ZStack {
                                ForEach(gameManager.gameState.lastTrickCardStates.sorted(by: { $0.value.zIndex < $1.value.zIndex }), id: \.key) { playerId, cardState in
                                    if let card = gameManager.gameState.lastTrick[playerId] {
                                        TransformableCardView(
                                            card: card,
                                            rotation: cardState.rotation,
                                            xOffset: cardState.position.x,
                                            yOffset: cardState.position.y,
                                            dynamicSize: dynamicSize
                                        )
                                        .zIndex(cardState.zIndex) // Apply the stored z-index
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(width: dynamicSize.tableWidth, height: dynamicSize.tableHeight)
                .animation(.easeInOut, value: gameManager.showLastTrick)
            }
            
            // Overlay Moving Cards
            ForEach(gameManager.movingCards) { movingCard in
                MovingCardView(movingCard: movingCard, dynamicSize: dynamicSize)
                    .environmentObject(gameManager)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onPreferenceChange(CardTransformPreferenceKey.self) { transforms in
            self.cardTransforms = transforms
            
            // For cards initialization
            for (cardID, cardState) in transforms {
                // Update each card’s fromState
                gameManager.cardStates[cardID] = cardState
            }
            
            // If all deck cards are now measured,
            // let the GameManager know we’re ready to deal.
            if !didMeasureDeck && transforms.count == (gameManager.gameState.deck.count + gameManager.gameState.trumpCards.count) {
                logger.log("Setting didMeasureDeck to true")
                didMeasureDeck = true
                gameManager.onDeckMeasured()
            }
            
            // Iterate through moving cards to check if any placeholder positions are captured
            for movingCard in gameManager.movingCards {
                if let toState = transforms[movingCard.placeholderCard.id] {
                    if movingCard.toState == nil {
                        // Update the movingCard's toState
                        movingCard.toState = toState
                    }
                }
            }
        }
        .overlay(
            Group {
                if showRoundHistory {
                    ZStack {
                        // Tappable background to dismiss the modal
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                showRoundHistory = false
                            }
                        
                        // The modal view
                        RoundHistoryView(isPresented: $showRoundHistory)
                            .environmentObject(gameManager)
                    }
                    .transition(.opacity)
                }
            }
        )
        .onAppear() {
            logger.log("onAppear: Refreshing background")
            refreshBackground()
        }
//        .onChange(of: preferences.selectedFeltIndex) { _ in
//            logger.log("onChange: Refreshing background")
//            refreshBackground()
//        }
    }
}

// MARK: Grid Overlay

struct GridOverlay: View {
    let spacing: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                
                for x in stride(from: 0, to: width, by: spacing) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
                
                for y in stride(from: 0, to: height, by: spacing) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(Color.gray.opacity(0.3), lineWidth: 1) // Thin lines for every 50px
            
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                
                for x in stride(from: 0, to: width, by: spacing * 2) { // Every 100px
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
                
                for y in stride(from: 0, to: height, by: spacing * 2) { // Every 100px
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(Color.gray.opacity(0.5), lineWidth: 2) // Thicker lines for every 100px
            
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                
                for x in stride(from: 0, to: width, by: spacing * 10) { // Every 500px
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
                
                for y in stride(from: 0, to: height, by: spacing * 10) { // Every 500px
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(Color.gray.opacity(0.8), lineWidth: 3) // Boldest lines for every 500px
        }
    }
}
