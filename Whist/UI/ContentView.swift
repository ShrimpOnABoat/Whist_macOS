//
//  ContentView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Main view that decides which screen to display.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var gameManager: GameManager
    @EnvironmentObject private var gameKitManager: GameKitManager
    @EnvironmentObject private var connectionManager: ConnectionManager
    @EnvironmentObject private var preferences: Preferences

    var body: some View {
        ZStack {
            if ![.waitingForPlayers, .exchangingSeed, .setupGame].contains(gameManager.gameState.currentPhase) {
                GameView()
                    .environmentObject(connectionManager)
                    .environmentObject(gameManager)
                    .environmentObject(preferences)
            } else if gameKitManager.isAuthenticated {
                MatchMakingView()
            } else {
                VStack(spacing: 20) {
                    Text("Authentification avec Game Center en cours…")
                        .font(.headline)
                    if let errorMessage = gameKitManager.authenticationErrorMessage {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                    } else {
                        EmptyView()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
        .environmentObject(GameManager())
        .environmentObject(GameKitManager())
        .environmentObject(ConnectionManager())
}
