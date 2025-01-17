//
//  DeckView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-12-05.
//

import SwiftUI

struct DeckView: View {
    @EnvironmentObject var gameManager: GameManager
    @ObservedObject var gameState: GameState
    
    // Cache random transforms for each card (to ensure consistent shuffle during the animation)
    @State private var randomOffsets: [String: CGSize] = [:]
    @State private var randomRotations: [String: Double] = [:]
    
    init(gameState: GameState) {
        self.gameState = gameState
    }
    
    var body: some View {
        ZStack {
            if gameState.deck.isEmpty {
                // Empty deck placeholder
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray, style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .frame(width: 60, height: 90)
                    .overlay(
                        Text("Deck")
                            .font(.caption)
                            .foregroundColor(.gray)
                    )
            } else {
                ForEach(Array(gameState.deck.enumerated()), id: \.offset) { index, card in
                    let baseOffset = CGSize(width: CGFloat(index) * 0.5,
                                            height: CGFloat(index) * -0.5)
                    
                    // Use random offset/rotation if shuffling
                    let shuffleOffset = randomOffsets[card.id] ?? .zero
                    let shuffleRotation = randomRotations[card.id] ?? 0
                    
                    TransformableCardView(card: card,
                                          xOffset: gameManager.isShuffling ? shuffleOffset.width : baseOffset.width,
                                          yOffset: gameManager.isShuffling ? shuffleOffset.height : baseOffset.height)
                    .rotationEffect(.degrees(gameManager.isShuffling ? shuffleRotation : 0))
                    .zIndex(Double(index)) // Higher index on top
                }
            }
        }
        .padding()
        .onAppear {
            // Pass the simulateShuffle function to the GameManager
            gameManager.shuffleCallback = { newDeck, completion in
                self.simulateShuffle(newDeck: newDeck, completion: completion)
            }
        }
        // Animate deck changes (e.g., when a card is drawn or discarded)
        .animation(.default, value: gameState.deck)
    }
    
    func simulateShuffle(newDeck: [Card], completion: @escaping () -> Void) {
        // Play a shuffle sound
        gameManager.playSound(named: "card shuffle")
        
        // Generate random transforms for each card
        randomOffsets = gameState.deck.reduce(into: [:]) { dict, card in
            dict[card.id] = CGSize(
                width: CGFloat.random(in: -50...50),
                height: CGFloat.random(in: -50...50)
            )
        }
        randomRotations = gameState.deck.reduce(into: [:]) { dict, card in
            dict[card.id] = Double.random(in: -15...15) // random angle
        }
        
        // Start shuffling animation
        withAnimation(.easeInOut(duration: 0.3)) {
            gameManager.isShuffling = true
        }
        
        // Shake it up a bit during the animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.3)) {
                gameState.deck = newDeck // Update the logical order of the deck

                randomOffsets = gameState.deck.reduce(into: [:]) { dict, card in
                    dict[card.id] = CGSize(
                        width: CGFloat.random(in: -50...50),
                        height: CGFloat.random(in: -50...50)
                    )
                }
                randomRotations = gameState.deck.reduce(into: [:]) { dict, card in
                    dict[card.id] = Double.random(in: -15...15)
                }
            }
        }
        
        // Finalize shuffle and update the deck state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 0.3)) {
                gameManager.isShuffling = false
            }
            completion()
        }
    }
}

// MARK: - Preview

struct DeckView_Previews: PreviewProvider {
    static var previews: some View {
        let gameManager = GameManager()
        gameManager.setupPreviewGameState()
        
        return DeckView(gameState: gameManager.gameState)
            .environmentObject(gameManager)
            .previewDisplayName("Deck View Preview")
            .previewLayout(.sizeThatFits)
    }
}
