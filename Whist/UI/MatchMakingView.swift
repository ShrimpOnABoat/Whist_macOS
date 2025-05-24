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
    // TODO: add dynamicSize for the avatars
    
    // Helper to get a user-friendly string and color for the phase
    private func displayInfo(for phase: P2PConnectionPhase) -> (text: String, color: Color) {
        switch phase {
        case .idle:
            return ("Idle", .gray)
        case .initiating:
            return ("Initiating...", .yellow)
        case .offering:
            return ("Sending Offer...", .orange)
        case .waitingForOffer:
            return ("Waiting for Offer...", .yellow)
        case .answering:
            return ("Sending Answer...", .orange)
        case .waitingForAnswer:
            return ("Waiting for Answer...", .yellow)
        case .exchangingNetworkInfo:
            return ("Exchanging Network Info...", .blue)
        case .connecting:
            return ("Connecting...", .purple)
        case .connected:
            return ("Connected", .green)
        case .failed:
            return ("Failed", .red)
        case .disconnected:
            return ("Disconnected", .pink) // Or red
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Salle d'attente")
                .font(.largeTitle)
                .padding(.top)
            
            // Player list
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(gameManager.gameState.players, id: \.id) { player in
                        // Only show detailed P2P status for other players
                        if player.username != preferences.playerId { // Don't show P2P status for self
                            let avatarColor = player.imageBackgroundColor ?? Color.gray
                            let avatarImage = player.image ?? Image(systemName: "person.crop.circle")
                            let phaseInfo = displayInfo(for: player.connectionPhase)

                            HStack {
                                avatarImage
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .background(avatarColor)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                
                                VStack(alignment: .leading) {
                                    Text(player.username)
                                        .font(.headline)
                                    
                                    Text(phaseInfo.text)
                                        .font(.caption)
                                        .foregroundColor(phaseInfo.color)
                                        .padding(.horizontal, 6)
                                        .background(phaseInfo.color.opacity(0.15))
                                        .cornerRadius(4)
                                }
                                
                                Spacer()
                                
                                Image(systemName: player.isConnected ? "wifi" : "wifi.slash")
                                    .foregroundColor(player.isConnected ? .green : .red)
                                    .font(.title3)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 5)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer() // Pushes status text to the bottom
            
            // Connection status text
            let total = gameManager.gameState.players.count
            let connected = gameManager.gameState.players.filter { $0.isConnected }.count
            
            Group { // Group to apply modifiers together
                if !gameManager.gameState.allPlayersConnected {
                    Text("En attente d'autres joueurs (\(connected)/\(total))...")
                        .foregroundColor(.orange) // Use orange for waiting
                } else {
                    Text("Tous les joueurs sont connectés !")
                        .foregroundColor(.green)
                }
            }
            .font(.headline)
            .padding(.bottom)
            
        }
        .background( // Added a subtle gradient background
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
        .navigationTitle("Recherche de Partie") // Added a navigation title if embedded in NavigationView
    }
}

// InvitingButtonStyle remains the same - ensure localization if its label text is set outside this view
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
