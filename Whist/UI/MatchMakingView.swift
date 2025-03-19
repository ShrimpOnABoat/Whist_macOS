//
//  MatchmakingView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Interface for matchmaking and connecting players.

import SwiftUI

import AppKit
import GameKit

struct MatchMakingView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var gameKitManager: GameKitManager
    @EnvironmentObject var connectionManager: ConnectionManager
    
    var body: some View {
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
                    Button("Invite les autres") {
                        gameKitManager.inviteFriends()
                    }
                    .buttonStyle(InvitingButtonStyle())
                    .padding()
                    
                } else {
                    // Fallback if the local player is not authenticated
                    Text("Connecte toi à Game Center.")
                }
            }
        }
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

struct MatchMakingView_Previews: PreviewProvider {
    static var previews: some View {
        MatchMakingView()
            .environmentObject(GameManager())
            .environmentObject(ConnectionManager())
            .environmentObject(GameKitManager())
    }
}
