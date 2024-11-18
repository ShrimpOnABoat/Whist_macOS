//
//  WhistApp.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Entry point of the application.

import SwiftUI

@main
struct WhistApp: App {
    @StateObject private var gameManager = GameManager()
    @StateObject private var gameKitManager = GameKitManager()
    @StateObject private var connectionManager = ConnectionManager()

    var body: some Scene {
        Window("Whist", id: "mainWindow") {
            ContentView()
                .environmentObject(gameManager)
                .environmentObject(gameKitManager)
                .environmentObject(connectionManager)
                .onAppear {
                    // Establish the delegation relationship
                    gameManager.connectionManager = connectionManager
                    connectionManager.gameManager = gameManager
                    gameKitManager.authenticateLocalPlayer()
                }
        }
        .defaultSize(width: 800, height: 600)
    }
}
