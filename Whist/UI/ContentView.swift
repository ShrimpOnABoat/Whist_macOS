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
    @EnvironmentObject private var preferences: Preferences

    var body: some View {
        ZStack {
            // ----- Authenticated -----
            if gameKitManager.isAuthenticated {
                 // Player ID must be selected (Handled by sheet in WhistApp)
                 // If ID is empty, the sheet forces selection.

                 // Show Matchmaking if waiting for players, otherwise show GameView
                 if gameManager.gameState.currentPhase == .waitingForPlayers {
                    MatchMakingView()
                        .environmentObject(gameManager)
                        .environmentObject(gameKitManager)
                 } else {
                    // Game is in progress (or just finished setting up post-match)
                    GameView()
                        .environmentObject(gameManager)
                        .environmentObject(gameKitManager)
                        .environmentObject(preferences)
                 }
            }
            // ----- Not Authenticated / Error -----
            else {
                VStack(spacing: 20) {
                    if let errorMessage = gameKitManager.authenticationErrorMessage {
                         Image(systemName: "exclamationmark.triangle.fill") // ...
                         Text("Erreur d'authentification Game Center :") // ...
                         Text(errorMessage) // ...
                    } else {
                        // Still authenticating
                        ProgressView().scaleEffect(1.5)
                        Text("Authentification Game Center...")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .padding(.top)
                    }
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

    }
}
