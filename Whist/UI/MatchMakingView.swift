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
        VStack(spacing: 20) { // Increased spacing
            Text("Salle d'attente") // Changed title to "Waiting Room" in French
                .font(.largeTitle)
                .padding(.top)
            
            // Player list
            ScrollView { // Added ScrollView in case of many players
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(gameManager.gameState.players, id: \.id) { player in
                        HStack {
                            // Player avatar or placeholder
                            if let img = player.image {
                                ZStack {
                                    (player.imageBackgroundColor ?? Color.gray)
                                    
                                    img
                                        .resizable()
                                        .scaledToFit()
                                }
                                .frame(width: 45, height: 45)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.secondary, lineWidth: 1))
                            } else {
                                    Image(systemName: "person.crop.circle.fill") // Using SF Symbol placeholder
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 45, height: 45)
                                        .foregroundColor(.gray.opacity(0.5))
                                }
                            
                            Text(player.username == preferences.playerId ? "\(player.username) (Vous)" : player.username) // Indicate "You"
                                .font(.headline)
                            
                            Spacer()
                            
                            // Connection indicator with icons
                            Image(systemName: player.isConnected ? "wifi" : "wifi.slash")
                                .foregroundColor(player.isConnected ? .green : .red)
                                .font(.title3) // Slightly larger icon
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 5) // Add some vertical padding per row
                        .background(Color.secondary.opacity(0.1)) // Subtle background per row
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal) // Padding for the inner VStack
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
