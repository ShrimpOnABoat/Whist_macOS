//
//  MatchmakingView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Interface for matchmaking and connecting players.

import SwiftUI

struct MatchMakingView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var preferences: Preferences // Added environment object

    var body: some View {
        VStack(spacing: 16) {
            Text("Matchmaking for \(preferences.playerId)")
                .font(.largeTitle)

            // List all players with their connection status
            ForEach(gameManager.gameState.players, id: \.id) { player in
                HStack {
                    // Player avatar or placeholder
                    if let img = player.image {
                        img
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 40)
                    }

                    Text(player.username)
                        .font(.headline)
                    Spacer()
                    // Connection indicator
                    Circle()
                        .fill(player.isConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                }
                .padding(.horizontal)
            }

            Spacer()

            // Host button / waiting status / ready status
            let total = gameManager.gameState.players.count
            let connected = gameManager.gameState.players.filter { $0.isConnected }.count

            if !gameManager.gameState.allPlayersConnected {
                Text("Waiting for others to connect (\(connected)/\(total))...")
                    .foregroundColor(.gray)
            } else {
                Text("All players connected!")
                    .foregroundColor(.green)
            }

            Spacer()
        }
        .onAppear {
            // Ensure networking listeners are set up (ContentView also does this, safe redundancy)
//            gameManager.startNetworkingIfNeeded()      
            
            // If we know who we are, start trying to connect to others
//            if !preferences.playerId.isEmpty {
//                logger.log("MatchMakingView appeared, calling startHosting()")
//                gameManager.startHosting()
//            } else {
//                logger.log("MatchMakingView appeared, but playerId is empty. Waiting for selection.")
//            }
        }
//        .onChange(of: gameManager.gameState.players.count) { count in
//            if count > 1 {
//                gameManager.startHosting()
//                gameManager.startNetworkingIfNeeded()
//            }
//        }
        .padding()
    }
}

struct InvitingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(configuration.isPressed ? Color.blue.opacity(0.7) : Color.blue)
            .cornerRadius(12)
            .shadow(radius: 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
