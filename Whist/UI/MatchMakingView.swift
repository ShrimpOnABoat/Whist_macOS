//
//  MatchmakingView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Interface for matchmaking and connecting players.

import SwiftUI

#if !TEST_MODE
import GameKit
#endif

struct MatchMakingView: View {
    @State private var navigateToGame = false
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var connectionManager: ConnectionManager
    @State private var selectedPlayerID: PlayerId? = nil
    @State private var isWaitingForPlayers: Bool = false
    
    var body: some View {
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
                    print("Selected player: \(newID)")
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
        .onChange(of: gameManager.gameState.allPlayersConnected) { old, allConnected in
            if allConnected {
                print("All players are connected!")
                isWaitingForPlayers = false
                navigateToGame = true
            }
        }
    }
}

//struct MatchMakingView: View {
//    @State private var navigateToGame = false
//    @EnvironmentObject var gameManager: GameManager
//    @EnvironmentObject var connectionManager: ConnectionManager
//    @State private var isGameStarted: Bool = false
//    
//#if TEST_MODE
//    @State private var selectedPlayerID: PlayerId? = nil
//#else
//    @StateObject private var matchmakingVM = MatchmakingViewModel()
//#endif
//    
//    var body: some View {
//        NavigationStack {
//            VStack {
//#if TEST_MODE
//                Text("Select Your Player Identity")
//                    .font(.headline)
//                    .padding()
//                
//                Picker("Player", selection: $selectedPlayerID) {
//                    Text("Toto").tag(PlayerId.toto)
//                    Text("GG").tag(PlayerId.gg)
//                    Text("DD").tag(PlayerId.dd)
//                    // Add more players if needed
//                }
//                .pickerStyle(SegmentedPickerStyle())
//                .padding()
//                .onChange(of: selectedPlayerID) { oldID, newID in
//                    if let newID = newID {
//                        print("Selected player: \(newID)")
//                        connectionManager.setLocalPlayerID(newID)
//                        isGameStarted = true
//                    } else {
//                        print("No player ID selected")
//                    }
//                }
//                
//#else
//                if matchmakingVM.isMatchmaking {
//                    ProgressView("Looking for a match...")
//                        .padding()
//                } else {
//                    Button(action: {
//                        matchmakingVM.startMatchmaking()
//                    }) {
//                        Text("Find Match")
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(Color.blue)
//                            .foregroundColor(.white)
//                            .cornerRadius(8)
//                    }
//                    .padding()
//                }
//#endif
//            }
//            .navigationDestination(isPresented: $isGameStarted) {
//                // Navigate to GameView without passing GameManager explicitly
//                GameView()
//                    .environmentObject(connectionManager)
//            }
//        }
//#if !TEST_MODE
//        .onReceive(matchmakingVM.$match) { match in
//            if let match = match {
//                // Proceed to the game view by setting up the match and initializing players
//                connectionManager.setupMatch(match)
//                connectionManager.initializePlayers()
//                gameManager.initializeGame()
//                navigateToGame = true
//            }
//        }
//#endif
//        .sheet(isPresented: $navigateToGame) {
//            // Present GameView without passing GameManager explicitly
//            GameView()
//                .environmentObject(connectionManager)
//                .environmentObject(gameManager)
//        }
//    }
//}

struct MatchMakingView_Previews: PreviewProvider {
    static var previews: some View {
        MatchMakingView()
            .environmentObject(GameManager())
            .environmentObject(ConnectionManager())
    }
}
