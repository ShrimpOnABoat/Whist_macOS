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
        let roundString = round < 4 ? "\(round)/3" : "\(round - 2)"
        
        VStack(spacing: 10) {
            // Round number
            Text("Round \(roundString)")
                .font(.title)
                .fontWeight(.bold)

            // Header row: Player usernames
            HStack {
                ForEach(players) { player in
                    VStack {
                        Text(player.username)
                            .font(.headline)
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

                        // Scores
                        if round > 1 {
                            let score = player.scores.last ?? 0
                            Text("\(score)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                        } else {
                            Text("0")
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .frame(width: 250)
        .background(
            ZStack {
                Color.white
                    .opacity(0.5)
            }
        )
        .cornerRadius(12)
        .shadow(radius: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 2)
        )
    }
}

struct ScoreBoardView_Previews: PreviewProvider {
    static var previews: some View {
        let gameManager = GameManager()
        gameManager.setupPreviewGameState()

        return ScoreBoardView()
            .environmentObject(gameManager)
            .previewDisplayName("Scoreboard Preview")
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
