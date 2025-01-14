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

                                ZStack {
                                    if gameManager.currentPhase != .choosingTrump {
                                        TableView(gameState: gameManager.gameState)
                                    } else {
                                        TableView(gameState: gameManager.gameState, mode: .trumps)
                                    }
                                }
                                .frame(width: 400, height: 180)
                            }
                            PlayerView(player: rightPlayer, isDealer: dealer == rightPlayer.id)
                                .frame(width: 200, height: 350)
                        }
                        PlayerView(player: localPlayer, isDealer: dealer == localPlayer.id)
                            .frame(width: 600, height: 200)
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center) // Center the OptionsView
                }
                .zIndex(1) // Ensure it's above everything else
                .transition(.scale) // Smooth scaling effect
                .animation(.easeInOut, value: gameManager.showOptions)
            }
            
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
    }
}

// MARK: - MovingCard Class

class MovingCard: Identifiable, ObservableObject {
    let id: UUID = UUID()
    let card: Card
    let to: CardPlace
    let placeholderCard: Card
    let fromState: CardState
    @Published var toState: CardState? = nil
    
    // Initializer
    init(card: Card, to: CardPlace, placeholderCard: Card, fromState: CardState) {
        self.card = card
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

                let animationDuration: TimeInterval = 1 // Adjust as needed
                withAnimation(.interpolatingSpring(
                    stiffness: 210,
                    damping: 20
                )) {
                    self.rotation = toState.rotation
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
        gameManager.showTrumps = true
        
        return GameView()
            .environmentObject(gameManager)
            .previewDisplayName("Game View Preview")
            .previewLayout(.fixed(width: 800, height: 600))
    }
}
