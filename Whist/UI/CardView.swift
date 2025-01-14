//
//  CardView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Visual representation of a card.

import SwiftUI

// MARK: CardView

struct CardView: View {
    @EnvironmentObject var gameManager: GameManager
    @ObservedObject var card: Card // Observe changes in the card
    @State private var hovered = false
    
    // These come from the parent:
    let isSelected: Bool      // Is this card currently selected?
    let canSelect: Bool       // Can we select more cards, or have we hit the limit?
    let onTap: () -> Void     // Callback to parent for toggling selection
    
    var body: some View {
        ZStack {
            if card.isFaceDown {
                Image("Card_back")
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(4)
            } else {
                Image("\(card.suit.rawValue)_\(card.rank.rawValue)")
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(4)
            }
        }
        .frame(width: 60, height: 90)
        .shadow(radius: 2) // Keep shadow but limit its impact
        .offset(y: (hovered || isSelected) && (card.isPlayable || gameManager.currentPhase == .discard) ? -30 : 0)   // Move card up on hover
        .opacity(card.isPlaceholder ? 0.0 : 1.0)
        .contentShape(Rectangle())
        .onHover { hovering in
            guard gameManager.currentPhase == .discard
                  ? canSelect || isSelected // allow hover if we can still select OR we’re already selected
                  : card.isPlayable
            else {
                return
            }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                hovered = hovering
            }
        }
        .onTapGesture {
            handleCardTap()
        }
    }
    
    private func handleCardTap() {
        // 1. If we’re in “discard” phase, handle discarding:
        if gameManager.currentPhase == .discard {
            // Let the parent do the toggling logic
            if canSelect || isSelected {
                onTap()
            }
            return
        }
        
        // 2. If we’re in some other phase, e.g. playing a trick:
        //    (Re-use your old logic here)
        if !card.isFaceDown && card.isPlayable {
            card.isPlayable = false
            if card.rank != .two {
                gameManager.playCard(card) {
                    gameManager.checkAndAdvanceStateIfNeeded()
                }
            } else {
                gameManager.selectTrumpSuit(card) {
                    gameManager.checkAndAdvanceStateIfNeeded()
                }
            }
        }
    }
}

// MARK: TransformableCardView

struct TransformableCardView: View {
    @EnvironmentObject var gameManager: GameManager

    @ObservedObject var card: Card // Observe changes
    let scale: CGFloat
    let rotation: Double
    let xOffset: CGFloat
    let yOffset: CGFloat

    // These come from the parent:
    let isSelected: Bool      // Is this card currently selected?
    let canSelect: Bool       // Can we select more cards, or have we hit the limit?
    let onTap: () -> Void     // Callback to parent for toggling selection
    
    init(card: Card, scale: CGFloat = 1.0, rotation: Double = 0, xOffset: CGFloat = 0, yOffset: CGFloat = 0, isSelected: Bool = false, canSelect: Bool = false, onTap: @escaping () -> Void = {} ) {
        self.card = card
        self.scale = scale
        self.rotation = rotation
        self.xOffset = xOffset
        self.yOffset = yOffset
        self.isSelected = isSelected
        self.canSelect = canSelect
        self.onTap = onTap
    }
    
    var body: some View {
        CardView(card: card, isSelected: isSelected, canSelect: canSelect, onTap: onTap)
            .frame(width: 60 * scale, height: 90 * scale)
            .scaleEffect(scale)
            .rotationEffect(Angle(degrees: rotation))
            .offset(x: xOffset, y: yOffset)
            .overlay(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: CardTransformPreferenceKey.self, value: [
                            card.id: CardState(
                                position: CGPoint(
                                    x: geometry.frame(in: .named("contentArea")).midX + xOffset,
                                    y: geometry.frame(in: .named("contentArea")).midY + yOffset
                                ),
                                rotation: rotation,
                                scale: scale
                            )
                        ])
                }
            )
    }
}

	
// MARK: - Preview

struct CardView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample card
        let sampleCard = Card(suit: .hearts, rank: .ace)
        sampleCard.isFaceDown = false
        sampleCard.isPlayable = true
        
        let scale = CGFloat.random(in: 0.8...1.2)
        let rotation = Double.random(in: -35...35)

        return TransformableCardView(card: sampleCard, scale: scale, rotation: rotation, xOffset: 0, yOffset: 0)
            .previewDisplayName("Card View Preview")
            .previewLayout(.sizeThatFits)
            .frame(width: 100, height: 150)
    }
}
