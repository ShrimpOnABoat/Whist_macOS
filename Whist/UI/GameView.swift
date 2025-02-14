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
    @State private var cardTransforms: [String: CardState] = [:]
    @State private var showMatchmaking: Bool = true
    @State private var showAlert: Bool = false
    @State private var showConfirmation: Bool = false
    @State private var savedGameExists: Bool = false
    @State private var playerID: String = ""
    @State private var showRoundHistory: Bool = false

        @State private var background: AnyView = AnyView(FeltBackgroundView(
            radialShadingStrength: 0.5,
            wearIntensity: CGFloat.random(in: 0...1),
            motifVisibility: CGFloat.random(in: 0...0.5),
            motifScale: CGFloat.random(in: 0...1),
            showScratches: Bool.random()
        ))
    @State private var didMeasureDeck: Bool = false
    
    
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
            if gameManager.gameState.dealer == gameManager.gameState.localPlayer?.id{
                DealerButton(size: dynamicSize.dealerButtonSize)
                    .position(CGPoint(
                        x: gameManager.dealerPosition.x + dynamicSize.dealerButtonLocalOffset.width,
                        y: gameManager.dealerPosition.y + dynamicSize.dealerButtonLocalOffset.height))
                    .animation(.easeOut, value: gameManager.dealerPosition)
            } else {
                DealerButton(size: dynamicSize.dealerButtonSize)
                    .position(gameManager.dealerPosition)
                    .animation(.easeOut, value: gameManager.dealerPosition)
            }
            
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
                gameManager.logWithTimestamp("Setting didMeasureDeck to true")
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
        .alert("Reprendre ou Commencer une Nouvelle Partie ?", isPresented: $showAlert) {
            Button("Reprendre") {
                resumeGame()
            }
            Button("Effacer", role: .destructive) {
                showConfirmation = true
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Une partie sauvegardée a été trouvée. Voulez-vous la reprendre ou en commencer une nouvelle ?")
        }
        .alert("Attention", isPresented: $showConfirmation) {
            Button("Supprimer", role: .destructive) {
                eraseGameState()
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Êtes-vous sûr de vouloir supprimer la partie sauvegardée ? Cette action est irréversible.")
        }
//        .onAppear() {
//            checkSavedGame()
//        }
    }
    
    private func checkSavedGame() {
        savedGameExists = gameManager.persistence.loadGameState() != nil
        if savedGameExists {
            showAlert = true
            showMatchmaking = true
        } else {
            startNewGame()
        }
    }
    
    private func resumeGame() {
        gameManager.resumeGameState()
        showMatchmaking = false
        gameManager.logWithTimestamp("Game resumed for player: \(playerID)")
    }
    
    private func eraseGameState() {
        gameManager.persistence.clearSavedGameState()
        savedGameExists = false
        showMatchmaking = false
        startNewGame()
        gameManager.logWithTimestamp("Saved game erased for player: \(playerID)")
    }
    
    private func startNewGame() {
        showMatchmaking = false
        gameManager.logWithTimestamp("New game started for player: \(playerID)")
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

// MARK: - Preview

struct GameView_Previews: PreviewProvider {
    static var previews: some View {
        // Initialize GameManager and set up the preview game state
        let gameManager = GameManager()
        gameManager.setupPreviewGameState()
        gameManager.showTrumps = false
        gameManager.showLastTrick = false
        gameManager.gameState.currentPhase = .playingTricks
        gameManager.gameState.dealer = .gg
//        gameManager.gameState.localPlayer?.hand.removeAll()
//        gameManager.gameState.leftPlayer?.hand.removeAll()
//        gameManager.gameState.rightPlayer?.hand.removeAll()

        return GameView()
            .environmentObject(gameManager)
            .previewDisplayName("Game View Preview")
            .previewLayout(.fixed(width: 800, height: 600))
    }
}
