//
//  CardView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Visual representation of a card.

import SwiftUI

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
