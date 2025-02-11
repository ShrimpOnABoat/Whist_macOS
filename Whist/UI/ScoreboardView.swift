//
//  ScoreBoardView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Shows current scores with tricks and player positions.

import SwiftUI

struct ScoreBoardView: View {
    @EnvironmentObject var gameManager: GameManager
    var dynamicSize: DynamicSize

    var body: some View {
        let players = gameManager.gameState.players.sorted { player1, player2 in
            let order: [PlayerId] = [.gg, .dd, .toto]
            return order.firstIndex(of: player1.id) ?? Int.max < order.firstIndex(of: player2.id) ?? Int.max
        }
        let round = gameManager.gameState.round
        let roundString = round < 4 ? "\(round)/3" : "\(round - 2)"
        
        VStack(spacing: dynamicSize.vstackScoreSpacing) {
            // Round number
            Text("Tour \(roundString)")
                .font(.system(size: dynamicSize.roundSize))
                .fontWeight(.bold)

            // Header row: Player usernames
            HStack {
                ForEach(players) { player in
                    VStack {
                        Text(player.username)
                            .font(.system(size: dynamicSize.nameSize))
                            .bold(true)
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
                            .font(.system(size: dynamicSize.scoreSize))

                        // Scores
                        if round > 1 {
                            let score = player.scores.last ?? 0
                            Text("\(score)")
                                .font(.system(size: dynamicSize.scoreSize))
                                .fontWeight(.bold)
                        } else {
                            Text("0")
                                .font(.system(size: dynamicSize.scoreSize))
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Announced tricks for the round
            HStack {
                ForEach(players) { player in
                    HStack {
                        // Announced Tricks
                        if (round < 4 || gameManager.allPlayersBet()) && (player.announcedTricks.count >= round && round > 0) {
                            let announcedTricks = player.announcedTricks[round - 1]
                            let tricksSum = gameManager.gameState.players.reduce(0) { $0 + ($1.announcedTricks.count >= round ? $1.announcedTricks[round - 1] : 0) }
                            let targetTricks = max(round - 2, 1)
                            
                            Text("\(announcedTricks)")
                                .font(.system(size: dynamicSize.announceSize))
                                .bold(true)
                                .foregroundColor(
                                    tricksSum == targetTricks ? .black :
                                    tricksSum < targetTricks ? .blue : .red
                                )
                        } else {
                            Text(" ")
                                .font(.system(size: dynamicSize.announceSize))
                                .bold(true)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.5))
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
        
        return GeometryReader { geometry in
            let dynamicSize: DynamicSize = DynamicSize(from: geometry)
            ScoreBoardView(dynamicSize: dynamicSize)
                .environmentObject(gameManager)
                .previewDisplayName("Scoreboard Preview")
                .previewLayout(.fixed(width: 400, height: 300))
                .padding()
        }
    }
}
