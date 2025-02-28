//
//  MatchmakingView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Interface for matchmaking and connecting players.

import SwiftUI

#if !TEST_MODE
import AppKit
import GameKit
#endif

struct MatchMakingView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var gameKitManager: GameKitManager
    @EnvironmentObject var connectionManager: ConnectionManager
    
#if TEST_MODE
    @State private var navigateToGame = false
    @State private var selectedPlayerID: PlayerId? = nil
    @State private var isWaitingForPlayers: Bool = false
#endif
    
    var body: some View {
#if TEST_MODE
        NavigationStack {
            VStack {
                // Player Selection UI
                Text("Select Your Player Identity")
                    .font(.headline)
                    .padding()
                
                Picker("Player", selection: $selectedPlayerID) {
                    Text("Toto").tag(PlayerId.toto)
                    Text("GG").tag(PlayerId.gg)
                    Text("DD").tag(PlayerId.dd)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .onChange(of: selectedPlayerID) { _, newID in
                    guard let newID = newID else { return }
                    gameManager.logger.log("Selected player: \(newID)")
                    connectionManager.setLocalPlayerID(newID)
                    gameManager.setPersistencePlayerID(with: selectedPlayerID!)
                    isWaitingForPlayers = true
                }
                
                if isWaitingForPlayers {
                    ProgressView("Waiting for all players to connect...")
                        .padding()
                }
            }
            .navigationDestination(isPresented: $navigateToGame) {
                GameView()
                    .environmentObject(connectionManager)
                    .environmentObject(gameManager)
            }
        }
        .onChange(of: gameManager.gameState.allPlayersConnected) { _, allConnected in
            if allConnected {
                gameManager.logger.log("All players are connected!")
                gameManager.checkAndAdvanceStateIfNeeded() // Should start the game
                isWaitingForPlayers = false
                navigateToGame = true
            }
        }
        
#else  // === !TEST_MODE: Show Game Center info rather than pickers ===
        
        // In MatchMakingView.swift, replace the !TEST_MODE body: with this updated version

        NavigationStack {
            VStack {
                if GKLocalPlayer.local.isAuthenticated {
                    // Player's profile image
                    Image(nsImage: gameKitManager.localImage)
                        .resizable()
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                        .padding(.bottom, 8)
                    
                    // Player's display name
                    Text(gameKitManager.localUsername)
                        .font(.headline)
                        .padding(.bottom, 20)
                    
                    // Status text to show connection state
                    if gameManager.gameState.allPlayersConnected {
                        Text("All players connected! Starting game...")
                            .foregroundColor(.green)
                            .padding(.bottom, 10)
                    }
                    
                    // Invite Friends button
                    Button("Invite les losers") {
                        gameKitManager.inviteFriends()
                    }
                    .buttonStyle(.bordered)
                    
                } else {
                    // Fallback if the local player is not authenticated
                    Text("Please sign in to Game Center.")
                }
            }
            #if TEST_MODE
            .navigationDestination(isPresented: $navigateToGame) {
                GameView()
                    .environmentObject(connectionManager)
                    .environmentObject(gameManager)
            }
            #endif
        }
#endif
    }
}

struct MatchMakingView_Previews: PreviewProvider {
    static var previews: some View {
        MatchMakingView()
            .environmentObject(GameManager())
            .environmentObject(ConnectionManager())
            .environmentObject(GameKitManager())
    }
}
