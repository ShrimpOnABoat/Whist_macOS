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

    let playOrder: [PlayerId] = [.gg, .dd, .toto]
    
    var body: some View {
        let round = gameManager.gameState.round
        let roundString = round < 4 ? "\(round)/3" : "\(round - 2)"
        
        VStack(spacing: dynamicSize.vstackScoreSpacing) {
            // Round number
            Text("Tour \(roundString)")
                .font(.system(size: dynamicSize.roundSize))
                .fontWeight(.bold)

            // Header row: Player IDs
            HStack {
                ForEach(["GG", "DD", "Toto"], id: \.self) { name in
                    VStack {
                        Text(name)
                            .font(.system(size: dynamicSize.nameSize))
                            .bold(true)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            // Tricks and Scores row
            HStack {
                ForEach(playOrder, id: \.self) { id in
                    let player = gameManager.gameState.getPlayer(by: id)
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
                ForEach(playOrder, id: \.self) { id in
                    let player = gameManager.gameState.getPlayer(by: id)
                    HStack {
                        // Announced Tricks
                        if (round < 4 || gameManager.allPlayersBet()) && (player.announcedTricks.count >= round && round > 0) {
                            let announcedTricks = player.announcedTricks[round - 1]
                            
                            Text("\(announcedTricks)")
                                .font(.system(size: dynamicSize.announceSize))
                                .bold(true)
                                .foregroundColor(.primary)
                        } else {
                            Text(" ")
                                .font(.system(size: dynamicSize.announceSize))
                                .bold(true)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .background(betsColor(for: gameManager))
            .cornerRadius(5)
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
    
    func betsColor(for gameManager: GameManager) -> Color {
        let round = gameManager.gameState.round
        
        if round < 4 || !gameManager.allPlayersBet() {
            return Color.white.opacity(0)
        }
        
        let tricksSum = gameManager.gameState.players.reduce(0) { sum, player in
            sum + (player.announcedTricks.count >= round ? player.announcedTricks[round - 1] : 0)
        }
        let targetTricks = max(round - 2, 1)

        // Dynamic red or blue color based on the difference
        let difference = CGFloat(abs(tricksSum - targetTricks))

        if tricksSum > targetTricks {
            // Red for sum greater than target
            return Color.red.opacity(difference * 0.2)
        } else {
            // Blue for sum less than target
            return Color.blue.opacity(difference * 0.2)
        }
    }
}
