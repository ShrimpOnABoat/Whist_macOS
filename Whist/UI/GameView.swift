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
    
    var body: some View {
        GeometryReader { geometry in
            // Extract players from the game state
            if let localPlayer = gameManager.gameState.localPlayer,
               let leftPlayer = gameManager.gameState.leftPlayer,
               let rightPlayer = gameManager.gameState.rightPlayer,
               let dealer = gameManager.gameState.dealer {
                // Proceed with your ZStack and layout
                ZStack {
                    // Background (optional, for clarity)
                    FeltBackgroundView()
                    
                    VStack {
                        HStack {
                            PlayerHandView(player: leftPlayer, namespace: cardAnimationNamespace)
                            PlayerInfoView(player: leftPlayer, isDealer: dealer == leftPlayer.id, namespace: cardAnimationNamespace)
                            VStack {
                                HStack {
                                    TrumpView(namespace: cardAnimationNamespace)
                                    ScoreBoardView()
                                    DeckView(gameState: gameManager.gameState, namespace: cardAnimationNamespace)
                                }
                                
                                TableView(gameState: gameManager.gameState, namespace: cardAnimationNamespace)
                                    .frame(width: 250, height: 180)
                            }
                            PlayerInfoView(player: rightPlayer, isDealer: dealer == rightPlayer.id, namespace: cardAnimationNamespace)
                            PlayerHandView(player: rightPlayer, namespace: cardAnimationNamespace)
                        }
                        PlayerInfoView(player: localPlayer, isDealer: dealer == localPlayer.id, namespace: cardAnimationNamespace)
                        HStack {
                            Spacer()
                            PlayerHandView(player: localPlayer, namespace: cardAnimationNamespace)
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
            
            // Overlay TrumpView if showTrumps is true
            if gameManager.showTrumps {
                ZStack {
                    ChooseTrumpView(namespace: cardAnimationNamespace)
                }
                .zIndex(1) // Ensure it's above everything else
                .transition(.scale) // Smooth scaling effect
                .animation(.easeInOut, value: gameManager.showTrumps)
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
        
        return GameView()
            .environmentObject(gameManager)
            .previewDisplayName("Game View Preview")
            .previewLayout(.fixed(width: 800, height: 600))
    }
}
