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
    @State private var showMatchmaking = true
    @State private var showAlert = false
    @State private var showConfirmation = false
    @State private var savedGameExists = false
    @State private var playerID: String = ""
    
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
                    
                    VStack {
                        HStack {
                            PlayerView(player: leftPlayer, isDealer: dealer == leftPlayer.id)
                                .frame(width: 200, height: 350)
                            
                            VStack {
                                HStack {
                                    TrumpView()
                                    ScoreBoardView()
                                    DeckView(gameState: gameManager.gameState)
                                }
                                .frame(width: 400, height: 150)
                                
                                if gameManager.showLastTrick && gameManager.gameState.currentPhase == .playingTricks {
                                    ZStack {
//                                        LastTrickView(gameState: gameManager.gameState)
                                        VStack {
                                            if gameManager.gameState.lastTrick.isEmpty {
                                                Text("Pas de dernier pli")
                                                    .font(.headline)
                                                    .foregroundColor(.gray)
                                            } else {
                                                GeometryReader { geometry in
                                                    ZStack {
                                                        ForEach(gameManager.gameState.lastTrickCardStates.sorted(by: { $0.value.zIndex < $1.value.zIndex }), id: \.key) { playerId, cardState in
                                                            if let card = gameManager.gameState.lastTrick[playerId] {
                                                                TransformableCardView(
                                                                    card: card,
                                                                    rotation: cardState.rotation,
                                                                    xOffset: cardState.position.x,
                                                                    yOffset: cardState.position.y
                                                                )
                                                                .zIndex(cardState.zIndex) // Apply the stored z-index
                                                            }
                                                        }
                                                    }
                                                }
//                                                .coordinateSpace(name: "contentArea")
                                            }
                                        }
                                    }
                                    .background(Color.yellow.opacity(1))
                                    .frame(width: 400, height: 180)
                                    .transition(.scale)
                                    .animation(.easeInOut, value: gameManager.showLastTrick)
                                } else {
                                    ZStack {
                                        if gameManager.gameState.currentPhase != .choosingTrump {
                                            TableView(gameState: gameManager.gameState)
                                        } else {
                                            TableView(gameState: gameManager.gameState, mode: .trumps)
                                        }
                                    }
                                    .frame(width: 400, height: 180)
                                }
                            }
                            PlayerView(player: rightPlayer, isDealer: dealer == rightPlayer.id)
                                .frame(width: 200, height: 350)
                        }
                        PlayerView(player: localPlayer, isDealer: dealer == localPlayer.id)
                            .frame(width: 400, height: 200)
                    }
                }
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
                    OptionsView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .zIndex(1) // Ensure it's above everything else
                .transition(.scale) // Smooth scaling effect
                .animation(.easeInOut, value: gameManager.showOptions)
            }
            
//            if gameManager.showLastTrick && gameManager.gameState.currentPhase == .playingTricks {
//                ZStack {
//                    LastTrickView(gameState: gameManager.gameState)
//                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center) 
//                }
//                .zIndex(1) 
//                .transition(.scale) 
//                .animation(.easeInOut, value: gameManager.showLastTrick)
//            }
            
            // Overlay Moving Cards
            ForEach(gameManager.movingCards) { movingCard in
                MovingCardView(movingCard: movingCard)
                    .environmentObject(gameManager)
            }
        }
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
        logWithTimestamp("Game resumed for player: \(playerID)")
    }
    
    private func eraseGameState() {
        gameManager.persistence.clearSavedGameState()
        savedGameExists = false
        showMatchmaking = false
        startNewGame()
        logWithTimestamp("Saved game erased for player: \(playerID)")
    }
    
    private func startNewGame() {
        showMatchmaking = false
        logWithTimestamp("New game started for player: \(playerID)")
    }
}

// MARK: - MovingCard Class

class MovingCard: Identifiable, ObservableObject {
    let id: UUID = UUID()
    let card: Card
    let from: CardPlace
    let to: CardPlace
    let placeholderCard: Card
    let fromState: CardState
    @Published var toState: CardState? = nil
    
    // Initializer
    init(card: Card,from: CardPlace, to: CardPlace, placeholderCard: Card, fromState: CardState) {
        self.card = card
        self.from = from
        self.to = to
        self.placeholderCard = placeholderCard
        self.fromState = fromState
    }
}
extension MovingCard: CustomStringConvertible {
    var description: String {
        return "\(card)"
    }
}
// MARK: - MovingCardView

struct MovingCardView: View {
    @EnvironmentObject var gameManager: GameManager
    @ObservedObject var movingCard: MovingCard
    
    @State private var position: CGPoint = .zero
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var hasAnimated: Bool = false // To ensure animation occurs only once
    
    var body: some View {
        CardView(card: movingCard.card, isSelected: false, canSelect: false, onTap: {})
            .frame(width: 60, height: 90)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .position(position)
            .onAppear {
                // Initialize with source transformations
                self.position = movingCard.fromState.position
                self.rotation = movingCard.fromState.rotation
                self.scale = movingCard.fromState.scale
            }
            .onChange(of: movingCard.toState) { oldToState, newToState in
                guard let toState = newToState, !hasAnimated else { return }
                
                hasAnimated = true
                let animationDuration: TimeInterval = 0.4
                
                // Generate a random direction for a full spin (360° clockwise or counterclockwise)
                let randomSpin: Double
                if [.localPlayer, .leftPlayer, .rightPlayer].contains(movingCard.from) {
                    randomSpin = Double([-360, 0, 360].randomElement() ?? 0)
                } else {
                    randomSpin = 0 // No spin for cards originating from non-hand areas
                }
                
                gameManager.playSound(named: "play card")
                
                withAnimation(.easeOut(duration: animationDuration)) {
                    self.rotation = toState.rotation + randomSpin
                    self.scale = toState.scale
                    self.position = toState.position
                }
                
                // Finalize move after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                    gameManager.finalizeMove(movingCard)
                }
            }
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
        gameManager.showLastTrick = true
        gameManager.gameState.currentPhase = .playingTricks
        
        return GameView()
            .environmentObject(gameManager)
            .previewDisplayName("Game View Preview")
            .previewLayout(.fixed(width: 800, height: 600))
    }
}
