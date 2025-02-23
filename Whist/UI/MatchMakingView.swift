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
    @StateObject private var viewModel = MatchmakingViewModel()
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

NavigationStack {
    VStack {
        if GKLocalPlayer.local.isAuthenticated {
            // Player’s profile image
            if let photo = localPlayerPhoto {
                Image(nsImage: photo)
                    .resizable()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .padding(.bottom, 8)
            }
            
            // Player’s display name
            Text(localPlayerDisplayName)
                .font(.headline)
                .padding(.bottom, 20)
            
            // Invite Friends button
            Button("Invite les losers") {
                viewModel.inviteFriends()
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
.onChange(of: gameManager.gameState.allPlayersConnected) { _, allConnected in
    if allConnected {
        gameManager.logWithTimestamp("All players are connected!")
        gameManager.checkAndAdvanceStateIfNeeded()
        navigateToGame = true
    }
}
.onAppear {
    // Configure your view model, load the local player’s name/photo
    viewModel.configure(
        gameKitManager: gameKitManager,
        connectionManager: connectionManager
    )
    viewModel.loadLocalPlayerInfo { name, image in
        self.localPlayerDisplayName = name
        self.localPlayerPhoto = image
    }
}

#endif
    }
}

struct MatchMakingView_Previews: PreviewProvider {
    static var previews: some View {
        MatchMakingView()
            .environmentObject(GameManager())
            .environmentObject(ConnectionManager())
    }
}
