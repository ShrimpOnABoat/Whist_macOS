//
//  OptionView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-12-09.
//

import SwiftUI

struct OptionsView: View {
    @EnvironmentObject var gameManager: GameManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Choisis une mise :")
                .font(.title)
                .padding()

            // Display the options dynamically
            ForEach(0...max(gameManager.gameState.round-2, 1), id: \.self) { number in
                Button(action: {
                    gameManager.choseBet(bet: number)
                }) {
                    Text("\(number)")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: 300)
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 10)
    }
}

// MARK: - Preview

struct OptionsView_Previews: PreviewProvider {
    static var previews: some View {
        @Namespace var cardAnimationNamespace
        let gameManager = GameManager()
        gameManager.setupPreviewGameState()

        return OptionsView()
            .environmentObject(gameManager)
            .previewDisplayName("Options View Preview")
            .previewLayout(.sizeThatFits)
    }
}
