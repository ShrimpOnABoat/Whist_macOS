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
    @State private var navigateToGame = false
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var gameKitManager: GameKitManager
    @EnvironmentObject var connectionManager: ConnectionManager
    
#if TEST_MODE
    @State private var selectedPlayerID: PlayerId? = nil
    @State private var isWaitingForPlayers: Bool = false
#else
//    @StateObject private var viewModel = MatchmakingViewModel()
    @State private var localPlayerDisplayName = ""
    @State private var localPlayerPhoto: NSImage?
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
                    gameManager.logWithTimestamp("Selected player: \(newID)")
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
                gameManager.logWithTimestamp("All players are connected!")
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
                    if let photo = localPlayerPhoto {
                        Image(nsImage: photo)
                            .resizable()
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .padding(.bottom, 8)
                    }
                    
                    // Player's display name
                    Text(localPlayerDisplayName)
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
                    
                    // Add a direct navigation button for testing/backup
                    if gameManager.gameState.allPlayersConnected {
                        Button("DEBUG -- Start Game Now") {
                            gameManager.logWithTimestamp("Manual game start triggered")
                            gameKitManager.dismissInviteUI()
                            navigateToGame = true
                        }
                        .padding(.top, 20)
                    }
                } else {
                    // Fallback if the local player is not authenticated
                    Text("Please sign in to Game Center.")
                }
            }
            .navigationDestination(isPresented: $navigateToGame) {
                GameView()
                    .environmentObject(connectionManager)
                    .environmentObject(gameManager)
            }
        }
        .onAppear {
            gameKitManager.loadLocalPlayerInfo { name, image in
                self.localPlayerDisplayName = name
                self.localPlayerPhoto = image
                
                guard let localPlayerID = GCPlayerIdAssociation[name] else {
                    gameManager.logWithTimestamp("No matching PlayerId for \(name)")
                    return
                }
                gameManager.logWithTimestamp("Local player username: \(name)")
                gameManager.logWithTimestamp("Local player ID: \(localPlayerID)")
                connectionManager.setLocalPlayerID(localPlayerID)
                
                // Update the player info in the game state
                gameManager.updatePlayer(localPlayerID, isLocal: true, name: name, image: self.localPlayerPhoto)
                gameManager.setPersistencePlayerID(with: localPlayerID)
            }
        }
        .onChange(of: gameManager.gameState.currentPhase) { _, currentOhase in
            if ![.waitingForPlayers, .exchangingSeed, .setupGame].contains(currentOhase) {
                gameManager.logWithTimestamp("All players are connected! Initiating transition to game view...")

                // Ensure we dismiss the Game Center invite modal before navigating
                DispatchQueue.main.async {
                    gameKitManager.dismissInviteUI()
                }

                // Ensure navigation is updated on the main thread with a slight delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    gameManager.checkAndAdvanceStateIfNeeded()

                    DispatchQueue.main.async {
                        gameManager.logWithTimestamp("Setting navigateToGame = true")
                        navigateToGame = true
                    }
                }
            }
        }
//        .onChange(of: gameManager.gameState.allPlayersConnected) { _, allConnected in
//            if allConnected {
//                gameManager.logWithTimestamp("All players are connected! Initiating transition to game view...")
//
//                // Ensure we dismiss the Game Center invite modal before navigating
//                DispatchQueue.main.async {
//                    gameKitManager.dismissInviteUI()
//                }
//
//                // Ensure navigation is updated on the main thread with a slight delay
//                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                    gameManager.checkAndAdvanceStateIfNeeded()
//
//                    DispatchQueue.main.async {
//                        gameManager.logWithTimestamp("Setting navigateToGame = true")
//                        navigateToGame = true
//                    }
//                }
//            }
//        }
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
