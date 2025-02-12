//
//  GameKitManager.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Handles Game Center authentication and matchmaking.

import Foundation

#if !TEST_MODE
import GameKit
import AppKit // Import AppKit for macOS
#endif

class GameKitManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var authenticationErrorMessage: String? = nil  // <-- Added property

    #if !TEST_MODE
    @Published var match: GKMatch?
    @Published var playersInMatch: [GKPlayer] = []
    // Map to store GKPlayer to PlayerId associations
    private var playerIdMapping: [GKPlayer: PlayerId] = [:]
    #endif
    
    weak var connectionManager: ConnectionManager?

    override init() {
        super.init()
    }

    func authenticateLocalPlayer() {
        #if !TEST_MODE
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.authenticationErrorMessage = error.localizedDescription  // Set error message
                    self?.logWithTimestamp("Authentication error: \(error.localizedDescription)")
                    return
                }

                if let vc = viewController {
                    self?.presentAuthenticationViewController(vc)
                } else if GKLocalPlayer.local.isAuthenticated {
                    self?.isAuthenticated = true
                    self?.authenticationErrorMessage = nil  // Clear any previous error
                    self?.logWithTimestamp("Game Center authentication successful.")
                    
                    // Assign a PlayerId based on the authenticated player's name
                    if let playerId = self?.determinePlayerId(for: GKLocalPlayer.local) {
                        self?.connectionManager?.setLocalPlayerID(playerId)
                    }
                } else {
                    self?.isAuthenticated = false
                    self?.authenticationErrorMessage = "Game Center authentication failed."
                    self?.logWithTimestamp("Game Center authentication failed.")
                }
            }
        }
        #else
        // In test mode, simulate successful authentication
        self.isAuthenticated = true
        self.authenticationErrorMessage = nil
        logWithTimestamp("Test mode: Authentication simulated as successful.")
        #endif
    }

    #if !TEST_MODE
    private func determinePlayerId(for player: GKPlayer) -> PlayerId? {
        // TODO: Implement correct mapping when I know more about our IDs
        let name = player.displayName.lowercased()
        if name.contains("dd") {
            return .dd
        } else if name.contains("gg") {
            return .gg
        } else if name.contains("toto") {
            return .toto
        }
        return nil
    }

    func mapPlayer(_ gkPlayer: GKPlayer, to playerId: PlayerId) {
        playerIdMapping[gkPlayer] = playerId
    }

    func getPlayerId(for gkPlayer: GKPlayer) -> PlayerId? {
        return playerIdMapping[gkPlayer]
    }
    
    private func presentAuthenticationViewController(_ viewController: NSViewController) {
        // Present the view controller in your app
        if let window = NSApplication.shared.windows.first {
            window.contentViewController?.presentAsModalWindow(viewController)
        } else {
            logWithTimestamp("No window available to present the authentication view controller.")
        }
    }
    #endif

    func logWithTimestamp(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        print("[\(timestamp)] \(message)")
    }
}
