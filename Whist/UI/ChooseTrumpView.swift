//
//  ChooseTrumpView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-12-10.
//

import SwiftUI

struct ChooseTrumpView: View {
    @EnvironmentObject var gameManager: GameManager
    let namespace: Namespace.ID
    
    @State private var selectedCard: Card? = nil
    
    var body: some View {
        ZStack {
            // Table where cards are displayed for choosing
            VStack(spacing: 20) {
                Text("Choisis un atout :")
                    .font(.title)
                    .padding()
                
                HStack(spacing: 20) {
                    ForEach(gameManager.gameState.trumpCards) { card in
                        // isPlayable and isFaceDown are updated in gameManager
                        CardView(card: card)
                            .frame(width: 60, height: 90)
                            .onTapGesture {
                                withAnimation {
                                    selectedCard = card
                                    gameManager.choseTrump(trump: card)
                                }
                            }
                            .matchedGeometryEffect(id: card.id, in: namespace)
                    }
                }
            }
        }
    }
}

struct ChooseTrumpView_Previews: PreviewProvider {
    static var previews: some View {
        let mockGameManager = GameManager()
        mockGameManager.gameState.trumpCards = [
            Card(suit: .hearts, rank: .two),
            Card(suit: .spades, rank: .two),
            Card(suit: .diamonds, rank: .two),
            Card(suit: .clubs, rank: .two)
        ]
        
        for i in mockGameManager.gameState.trumpCards {
            i.isFaceDown = false
        }
        
        return ChooseTrumpView(namespace: Namespace().wrappedValue)
            .environmentObject(mockGameManager)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
