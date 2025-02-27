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

    var body: some View {
        ZStack {
            #if TEST_MODE
            MatchMakingView()
            #else
            if ![.waitingForPlayers, .exchangingSeed, .setupGame].contains(gameManager.gameState.currentPhase) {
                GameView()
                    .environmentObject(connectionManager)
                    .environmentObject(gameManager)
            } else if gameKitManager.isAuthenticated {
                MatchMakingView()
            } else {
                VStack(spacing: 20) {
                    Text("Authenticating with Game Center...")
                        .font(.headline)
                    if let errorMessage = gameKitManager.authenticationErrorMessage {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                    } else {
                        EmptyView()
                    }
                }
            }
            #endif
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
