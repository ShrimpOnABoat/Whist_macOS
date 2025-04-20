//
//  ContentView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Main view that decides which screen to display.

import SwiftUI

//TODO: redo for P2P

struct ContentView: View {
    @EnvironmentObject private var gameManager: GameManager
    @EnvironmentObject private var preferences: Preferences

    var body: some View {
        ZStack {
            // Show MatchMakingView when the game is waiting for players
            if gameManager.gameState.currentPhase == .waitingForPlayers {
                MatchMakingView()
                    .environmentObject(gameManager)
            } else {
                // Game is in progress
                GameView()
                    .environmentObject(gameManager)
                    .environmentObject(preferences)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
