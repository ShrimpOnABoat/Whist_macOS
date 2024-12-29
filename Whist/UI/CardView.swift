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
        .offset(y: hovered && card.isPlayable ? -30 : 0)   // Move card up on hover
        .contentShape(Rectangle())
        .onHover { hovering in
            guard card.isPlayable else { return }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                hovered = hovering
            }
        }
        .onTapGesture {
            if !card.isFaceDown && card.isPlayable {
                withAnimation(.easeInOut(duration: 0.2)) {
                    gameManager.playCard(card)
                }
            }
        }
        .animation(.smooth(duration: 0.3), value: card.isFaceDown)
        .animation(.smooth(duration: 0.3), value: card.isPlayable)
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
//    let namespace: Namespace.ID

    init(card: Card, scale: CGFloat = 1.0, rotation: Double = 0, xOffset: CGFloat = 0, yOffset: CGFloat = 0) {
        self.card = card
        self.scale = scale
        self.rotation = rotation
        self.xOffset = xOffset
        self.yOffset = yOffset
    }
    
    var body: some View {
        CardView(card: card)
            .frame(width: 60 * scale, height: 90 * scale)
            .scaleEffect(scale)
            .rotationEffect(Angle(degrees: rotation))
            .offset(x: xOffset, y: yOffset)
            .opacity(card.isPlaceholder ? 0.0 : 1.0)
            .overlay(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: CardTransformPreferenceKey.self, value: [
                            card.id: CardState(
                                position: CGPoint(
                                    x: geometry.frame(in: .global).midX + xOffset,
                                    y: geometry.frame(in: .global).midY + yOffset
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

        return CardView(card: sampleCard)
            .previewDisplayName("Card View Preview")
            .previewLayout(.sizeThatFits)
            .frame(width: 100, height: 150)
    }
}
