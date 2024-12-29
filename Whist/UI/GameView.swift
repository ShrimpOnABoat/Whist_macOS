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
    @Namespace private var cardAnimationNamespace
    @State private var cardTransforms: [String: CardState] = [:]

    @State private var background: AnyView = AnyView(FeltBackgroundView(
        radialShadingStrength: 0.5,
        wearIntensity: 0.5,
        motifVisibility: 0.25,
        motifScale: 0.5,
        showScratches: true
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
//                    FeltBackgroundView()
                    background
                    
                    VStack {
                        HStack {
                            PlayerHandView(player: leftPlayer)
                            PlayerInfoView(player: leftPlayer, isDealer: dealer == leftPlayer.id, namespace: cardAnimationNamespace)
                            VStack {
                                HStack {
                                    TrumpView(namespace: cardAnimationNamespace)
                                    ScoreBoardView()
                                    DeckView(gameState: gameManager.gameState)
                                }
                                
                                ZStack {
                                    TableView(gameState: gameManager.gameState, namespace: cardAnimationNamespace)
                                        .frame(width: 250, height: 180)
                                    
                                    // Overlay TrumpView if showTrumps is true
                                    if gameManager.showTrumps {
                                        ZStack {
                                            ChooseTrumpView(namespace: cardAnimationNamespace)
                                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                        }
                                        .zIndex(1) // Ensure it's above everything else
                                        .transition(.scale) // Smooth scaling effect
                                        .animation(.easeInOut, value: gameManager.showTrumps)
                                    }
                                }
                            }
                            PlayerInfoView(player: rightPlayer, isDealer: dealer == rightPlayer.id, namespace: cardAnimationNamespace)
                            PlayerHandView(player: rightPlayer)
                        }
                        PlayerInfoView(player: localPlayer, isDealer: dealer == localPlayer.id, namespace: cardAnimationNamespace)
                        HStack {
                            Spacer()
                            PlayerHandView(player: localPlayer)
                                .frame(maxWidth: .infinity, alignment: .center) // Center horizontally within available space
                            Spacer()
                        }
                    }
                }
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
            // for cards initialization
            for (cardID, cardState) in transforms {
                // Update each card’s fromState
                gameManager.cardStates[cardID] = cardState
            }
            
            // If all deck cards are now measured,
            // let the GameManager know we’re ready to deal.
            if !didMeasureDeck && transforms.count == (gameManager.gameState.deck.count + gameManager.gameState.trumpCards.count) {
                print("The deck is measured!!!")
                didMeasureDeck = true
                gameManager.onDeckMeasured()
            } else {
                print("Deck is measured: \(didMeasureDeck) - \(transforms.count) transforms and \(gameManager.gameState.deck.count) cards in the deck")
            }
            
            // Iterate through moving cards to check if any placeholder positions are captured
            for movingCard in gameManager.movingCards {
                if let toState = transforms[movingCard.placeholderCard.id],
                   movingCard.toState == nil {
                    // Update the movingCard's toState
                    movingCard.toState = toState
                    print("toState captured for \(movingCard.card)")
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

// MARK: - MovingCardView

struct MovingCardView: View {
    @EnvironmentObject var gameManager: GameManager
    @ObservedObject var movingCard: MovingCard
    
    @State private var position: CGPoint = .zero
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var hasAnimated: Bool = false // To ensure animation occurs only once
    
    var body: some View {
        CardView(card: movingCard.card)
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
                withAnimation(.easeInOut(duration: animationDuration)) {
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
