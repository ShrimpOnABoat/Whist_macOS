//
//  ScoreBoardView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Shows current scores with tricks and player positions.

import SwiftUI

struct ScoreBoardView: View {
    @EnvironmentObject var gameManager: GameManager

    var body: some View {
        let players = gameManager.gameState.players
        let round = gameManager.gameState.round

        VStack(spacing: 10) {
            // Header row: Player usernames and positions
            HStack {
                ForEach(players) { player in
                    VStack {
                        HStack {
                            Text(player.username)
                                .font(.headline)
//                                .foregroundColor(player.place == 1 ? .yellow : player.place == 3 ? .red : .white)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            // Tricks and Scores row
            HStack {
                ForEach(players) { player in
                    HStack {
                        // Tricks
                        let tricks = player.announcedTricks.reduce(0, +)
                            Text("\(tricks)")
                                .font(.subheadline)
                                .foregroundColor(.cyan)

                        // Scores
                        if round > 1 {
                            let score = player.scores.last ?? 0
                            Text("\(score)")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        } else {
                            Text("0")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .frame(width: 250) // Adjusted width to fit content
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.7)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .shadow(radius: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 2)
        )
    }
}

// MARK: - Preview
struct ScoreBoardView_Previews: PreviewProvider {
    static var previews: some View {
        // Initialize GameManager and set up the preview game state
        let gameManager = GameManager()
        gameManager.setupPreviewGameState()

        return ScoreBoardView()
            .environmentObject(gameManager)
            .previewDisplayName("Scoreboard Preview")
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
