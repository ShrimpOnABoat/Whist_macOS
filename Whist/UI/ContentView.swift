//
//  ContentView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Main view that decides which screen to display.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var gameKitManager: GameKitManager

    var body: some View {
        GeometryReader { geometry in
            ZStack {
#if TEST_MODE
                MatchMakingView()
#else
                if gameKitManager.isAuthenticated {
                    // Show the game or matchmaking view
                    MatchmakingView()
                } else {
                    // Show a loading or sign-in prompt
                    VStack {
                        Text("Authenticating with Game Center...")
                        if let errorMessage = gameManager.authenticationErrorMessage {
                            Text("Error: \(errorMessage)")
                                .foregroundColor(.red)
                        }
                    }
                }
#endif
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(GameManager())
            .environmentObject(GameKitManager())
            .environmentObject(ConnectionManager())
    }
}
